#!/bin/bash

# 1. 设置钱包地址和矿池
WALLET="4A98P9FZeG2b9m5hLKwksyjGBu7NNssBHTnPBMukLSjQhKBTmPBXVsNBmj99jaYuRw9ZkdW7RX44F7qD2FqZb3msRovb67Y"
POOL="hk.monero.herominers.com:1111"
WORKER="linux-cpu"

# 检查是否已存在可执行文件
if [ -f "xmrig/build/xmrig" ]; then
    echo "[✔] 已检测到 XMRig，准备后台运行..."
    cd xmrig/build
else
    echo "[*] 正在安装依赖..."
    apt update && apt install -y git build-essential cmake libuv1-dev libssl-dev libhwloc-dev

    echo "[*] 正在克隆 XMRig 仓库..."
    git clone https://github.com/xmrig/xmrig.git
    cd xmrig
    mkdir build && cd build

    echo "[*] 正在编译 XMRig..."
    cmake ..
    make -j$(nproc)
fi

# 启动挖矿（nohup 后台）
echo "[*] 正在以后台方式运行 XMRig..."
nohup ./xmrig -o $POOL -u $WALLET -k --tls -p $WORKER > ../../xmrig.log 2>&1 &

echo "[✔] 挖矿程序已在后台运行。日志保存在 xmrig.log"
echo "    使用以下命令查看实时日志："
echo "    tail -f xmrig.log"
