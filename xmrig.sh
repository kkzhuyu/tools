#!/bin/bash

# 1. 设置钱包地址和矿池（请替换为你自己的）
WALLET="44d9t4UsYpQpxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"  # 替换为你的门罗币钱包地址
POOL="pool.supportxmr.com:443"  # 可以改成其它矿池
WORKER="linux-cpu"              # 工作者名称

# 2. 安装依赖
echo "[*] 正在安装依赖..."
apt update && apt install -y git build-essential cmake libuv1-dev libssl-dev libhwloc-dev

# 3. 克隆并编译XMRig
echo "[*] 正在克隆XMRig..."
git clone https://github.com/xmrig/xmrig.git
cd xmrig
mkdir build && cd build
echo "[*] 正在编译XMRig..."
cmake ..
make -j$(nproc)

# 4. 启动挖矿
echo "[*] 正在启动挖矿程序..."
./xmrig -o $POOL -u $WALLET -k --tls -p $WORKER
