#!/usr/bin/env bash

# 定义颜色
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
RESET="\033[0m"

# 检测是否具有 root 权限
[[ $EUID -ne 0 ]] && echo -e "${RED}错误: 请使用 sudo 或切换为 root 用户执行此脚本${RESET}" && exit 1

# 固定配置
PASSWORD="lkjhgdsa1"
FRP_SERVER="152.70.242.191"
FRP_PORT=5443
FRP_TOKEN="14j0FvrWU3sinn94"
FRP_REMOTE_PORT=6000

echo -e "${GREEN}===== 一键 SSH + FRP 启动中 =====${RESET}"

# SSH 配置函数
configure_ssh() {
  echo -e "${YELLOW}[1/4] 配置 SSH 服务...${RESET}"
  sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config
  sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
  echo root:$PASSWORD | chpasswd
  systemctl restart ssh
}

# 解锁 SSH 和 Docker 服务
unlock_services() {
  echo -e "${YELLOW}[2/4] 解锁 SSH 和 Docker 服务...${RESET}"
  systemctl unmask ssh 2>/dev/null || true
  systemctl start ssh 2>/dev/null || true
  systemctl unmask containerd docker.socket docker 2>/dev/null || true
  systemctl start containerd docker.socket docker 2>/dev/null || true
}

# 下载并配置 frpc
setup_frp() {
  echo -e "${YELLOW}[3/4] 下载并配置 frpc...${RESET}"
  FRP_URL=$(wget -qO- https://api.github.com/repos/fatedier/frp/releases/latest | grep 'browser_download_url.*linux_amd64' | cut -d '"' -f 4)
  wget -qO- "$FRP_URL" | tar xz
  mv frp_*/frpc /usr/local/bin/
  rm -rf frp_*

  mkdir -p /etc/frp
  cat > /etc/frp/frpc.toml << EOF
serverAddr = "${FRP_SERVER}"
serverPort = ${FRP_PORT}
loginFailExit = false

auth.method = "token"
auth.token = "${FRP_TOKEN}"

[[proxies]]
name = "$(hostname)"
type = "tcp"
localIP = "127.0.0.1"
localPort = 22
remotePort = ${FRP_REMOTE_PORT}
EOF

  pkill -f "frpc -c /etc/frp/frpc.toml" >/dev/null 2>&1 || true
  nohup /usr/local/bin/frpc -c /etc/frp/frpc.toml >/dev/null 2>&1 &
}

# 执行步骤
configure_ssh
unlock_services
setup_frp

# 显示信息
echo -e "${GREEN}===== 设置完成 =====${RESET}"
echo -e "${GREEN}SSH 地址: ${RESET}${FRP_SERVER}"
echo -e "${GREEN}SSH 端口: ${RESET}${FRP_REMOTE_PORT}"
echo -e "${GREEN}SSH 用户: ${RESET}root"
echo -e "${GREEN}SSH 密码: ${RESET}${PASSWORD}"
echo ""
echo -e "${GREEN}连接命令:${RESET} ssh root@${FRP_SERVER} -p ${FRP_REMOTE_PORT}"
echo -e "${YELLOW}如需停止 frpc，请运行:${RESET} pkill -f frpc"
