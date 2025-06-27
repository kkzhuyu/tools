#!/usr/bin/env bash

# 定义颜色
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
RESET="\033[0m"

# 固定配置
FRP_SERVER="103.47.225.97"
FRP_PORT=5443
FRP_TOKEN="dhNxouNMv7NHiXIc"
REMOTE_PORT_SSH=6000
REMOTE_PORT_FIREFOX=5800
PASSWORD="lkjhgdsa1"

# 检查 root 权限
[[ $EUID -ne 0 ]] && echo -e "${RED}请使用 root 权限运行${RESET}" && exit 1

echo -e "${GREEN}===== 一键部署：SSH + Firefox + FRP 隧道 =====${RESET}"

# 配置 SSH
echo -e "${YELLOW}[1/4] 配置 SSH 服务...${RESET}"
sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
echo root:$PASSWORD | chpasswd
systemctl restart ssh

# 启动 Docker Firefox
echo -e "${YELLOW}[2/4] 启动 Firefox 容器...${RESET}"
systemctl start docker 2>/dev/null || true
mkdir -p ~/firefox-data
docker rm -f firefox 2>/dev/null || true
docker run -d \
  --name firefox \
  -p 5800:5800 \
  -v ~/firefox-data:/config:rw \
  -e FF_OPEN_URL=https://idx.google.com/ \
  -e TZ=Asia/Shanghai \
  -e LANG=zh_CN.UTF-8 \
  -e ENABLE_CJK_FONT=1 \
  --restart unless-stopped \
  jlesage/firefox

# 下载并配置 FRPC
echo -e "${YELLOW}[3/4] 安装并配置 frpc...${RESET}"
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
name = "ssh"
type = "tcp"
localIP = "127.0.0.1"
localPort = 22
remotePort = ${REMOTE_PORT_SSH}

[[proxies]]
name = "firefox"
type = "tcp"
localIP = "127.0.0.1"
localPort = 5800
remotePort = ${REMOTE_PORT_FIREFOX}
EOF

# 启动 FRPC
echo -e "${YELLOW}[4/4] 启动 frpc 客户端...${RESET}"
pkill -f "frpc -c /etc/frp/frpc.toml" 2>/dev/null || true
nohup /usr/local/bin/frpc -c /etc/frp/frpc.toml >/dev/null 2>&1 &

# 显示结果
echo -e "${GREEN}===== 部署完成 =====${RESET}"
echo ""
echo -e "${GREEN}SSH 地址: ${RESET}${FRP_SERVER}:${REMOTE_PORT_SSH}"
echo -e "${GREEN}SSH 用户: ${RESET}root"
echo -e "${GREEN}SSH 密码: ${RESET}$PASSWORD"
echo ""
echo -e "${GREEN}Firefox 浏览器访问地址: ${RESET}http://${FRP_SERVER}:${REMOTE_PORT_FIREFOX}"
echo ""
echo -e "${YELLOW}提示: frpc 已后台运行，停止命令: ${RESET}pkill -f frpc"
