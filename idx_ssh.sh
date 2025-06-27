#!/usr/bin/env bash

# 定义颜色
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
RESET="\033[0m"

# 检测是否具有 root 权限
[[ $EUID -ne 0 ]] && echo -e "${RED}错误: 请先运行 sudo -i 获取 root 权限后再执行此脚本${RESET}" && exit 1

# 解锁服务函数
unlock_services() {
  echo -e "${YELLOW}[3/5] 正在解除 SSH 和 Docker 服务的锁定，启用密码访问...${RESET}"
  if [ "$(systemctl is-active ssh)" != "active" ]; then
    systemctl unmask ssh 2>/dev/null || true
    systemctl start ssh 2>/dev/null || true
  fi

  if [[ "$(systemctl is-active docker)" != "active" || "$(systemctl is-active docker.socket)" != "active" ]]; then
    systemctl unmask containerd docker.socket docker 2>/dev/null || true
    pkill dockerd 2>/dev/null || true
    pkill containerd 2>/dev/null || true
    systemctl start containerd docker.socket docker 2>/dev/null || true
    sleep 2
  fi
}

# SSH 配置函数
configure_ssh() {
  echo -e "${YELLOW}[1/5] 正在终止现有的 SSH 进程...${RESET}"
  lsof -i:22 | awk '/IPv4/{print $2}' | xargs kill -9 2>/dev/null || true

  echo -e "${YELLOW}[2/5] 正在配置 SSH 服务，允许 root 登录和密码认证...${RESET}"
  ! grep -q "^PermitRootLogin yes" /etc/ssh/sshd_config && echo -e '\nPermitRootLogin yes' >> /etc/ssh/sshd_config
  ! grep -q "^PasswordAuthentication yes" /etc/ssh/sshd_config && echo -e '\nPasswordAuthentication yes' >> /etc/ssh/sshd_config
  echo root:$PASSWORD | chpasswd
}

echo -e "${GREEN}===== 一键 FRP 配置启动中 =====${RESET}"

# 获取 root 密码
while true; do
  read -p "请输入 root 密码 (至少10位): " PASSWORD
  if [[ -z "$PASSWORD" ]]; then
    echo -e "${RED}错误: 密码不能为空，请重新输入${RESET}"
  elif [[ ${#PASSWORD} -lt 10 ]]; then
    echo -e "${RED}错误: 密码长度不足10位，请重新输入${RESET}"
  else
    break
  fi
done

# 固定配置
FRP_SERVER="152.70.242.191"
FRP_PORT=5443
FRP_TOKEN="14j0FvrWU3sinn94"
FRP_REMOTE_PORT=6000

configure_ssh
unlock_services

echo -e "${YELLOW}[4/5] 正在下载和配置 Frp 客户端...${RESET}"
FRP=$(wget -qO- https://api.github.com/repos/fatedier/frp/releases/latest | grep 'browser_download_url.*linux_amd64' | cut -d '"' -f 4)
wget -qO- $FRP | tar xz
mv frp_*/frpc /usr/local/bin/
rm -rf frp_*

mkdir -p /etc/frp
cat > /etc/frp/frpc.toml << EOF
serverAddr = "${FRP_SERVER}"
serverPort = ${FRP_PORT}
loginFailExit = false

auth.method = "token"
auth.token = "${FRP_TOKEN}"

transport.heartbeatInterval = 10
transport.heartbeatTimeout = 30
transport.dialServerKeepalive = 10
transport.dialServerTimeout = 30
transport.tcpMuxKeepaliveInterval = 10
transport.poolCount = 5

[[proxies]]
name = "$(hostname)"
type = "tcp"
localIP = "127.0.0.1"
localPort = 22
remotePort = ${FRP_REMOTE_PORT}
EOF

# 清理旧进程
pkill -f "frpc -c /etc/frp/frpc.toml" >/dev/null 2>&1 || true

# 启动 frpc
nohup /usr/local/bin/frpc -c /etc/frp/frpc.toml >/dev/null 2>&1 &

echo -e "${GREEN}===== 设置完成 =====${RESET}"
echo ""
echo -e "${GREEN}SSH 地址: ${RESET}${FRP_SERVER}"
echo -e "${GREEN}SSH 端口: ${RESET}${FRP_REMOTE_PORT}"
echo -e "${GREEN}SSH 用户: ${RESET}root"
echo -e "${GREEN}SSH 密码: ${RESET}$PASSWORD"
echo ""
echo -e "${GREEN}使用以下命令连接到您的服务器:${RESET}"
echo -e "${GREEN}ssh root@${FRP_SERVER} -p ${FRP_REMOTE_PORT}${RESET}"
echo ""
echo -e "${YELLOW}注意: frpc 进程在后台运行，如需停止请使用 'pkill -f frpc' 命令${RESET}"
echo ""
