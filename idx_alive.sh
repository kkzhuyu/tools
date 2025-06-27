#!/usr/bin/env bash

# 定义颜色
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
RESET="\033[0m"

# 检测 root 权限
[[ $EUID -ne 0 ]] && echo -e "${RED}错误: 请使用 sudo 或切换为 root 用户执行此脚本${RESET}" && exit 1

echo -e "${GREEN}===== 开始设置 FRP 隧道和 Docker Firefox =====${RESET}"
echo -e "${RED}重要提示: ${BLUE}此保活方法可配合 FRP 长期运行，请自行维护远程服务端${RESET}"
echo ""

# 设置参数
FRP_SERVER="103.47.225.97"
FRP_PORT=5443
FRP_TOKEN="dhNxouNMv7NHiXIc"
FRP_REMOTE_PORT=5800

echo -e "${YELLOW}[1/4] 检查并启动 Docker 服务...${RESET}"
systemctl unmask containerd docker.socket docker 2>/dev/null || true
systemctl start containerd docker.socket docker 2>/dev/null || true

echo -e "${YELLOW}[2/4] 启动 Firefox Docker 容器...${RESET}"
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

if ! docker ps | grep -q firefox; then
  echo -e "${RED}错误: Firefox 容器启动失败，请检查 Docker 是否正常运行${RESET}"
  exit 1
fi

echo -e "${YELLOW}[3/4] 下载并配置 FRP 客户端...${RESET}"
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
name = "firefox-web"
type = "tcp"
localIP = "127.0.0.1"
localPort = 5800
remotePort = ${FRP_REMOTE_PORT}
EOF

pkill -f "frpc -c /etc/frp/frpc.toml" >/dev/null 2>&1 || true
nohup /usr/local/bin/frpc -c /etc/frp/frpc.toml >/dev/null 2>&1 &

echo -e "${YELLOW}[4/4] 等待 FRP 隧道连接建立...${RESET}"
sleep 5

echo -e "${GREEN}===== 设置完成 =====${RESET}"
echo ""
echo -e "${GREEN}Firefox 本地访问地址: ${RESET}http://localhost:5800"
echo -e "${GREEN}Firefox FRP 外部访问地址: ${RESET}http://${FRP_SERVER}:${FRP_REMOTE_PORT}"
echo ""
echo -e "${YELLOW}注意: Docker 容器设置为自动重启，除非手动停止${RESET}"
echo -e "${YELLOW}注意: frpc 进程已在后台运行，如需停止请使用: ${RESET}pkill -f frpc"
echo ""
