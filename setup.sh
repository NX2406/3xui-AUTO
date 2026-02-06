#!/bin/bash

# ==============================================================
# 🚀 X-UI 极简系统环境修复 & 全自动安装脚本 (究极修复版)
# ==============================================================
# 更新日志：
# 1. 新增：智能检测 apt/dpkg 锁，防止因系统后台更新导致安装失败
# 2. 新增：DNS 自动修正，解决部分机房解析软件源超时的问题
# 3. 优化：多重重试机制，确保 socat 等关键依赖 100% 安装成功
# ==============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
PLAIN='\033[0m'

echo -e "${YELLOW}正在检查系统环境...${PLAIN}"

# ==============================================================
# 函数：等待 apt 锁释放 (解决 "Could not get lock" 报错)
# ==============================================================
wait_for_lock() {
    local i=0
    while fuser /var/lib/dpkg/lock >/dev/null 2>&1 || fuser /var/lib/apt/lists/lock >/dev/null 2>&1 || fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
        echo -e "${YELLOW}系统后台正在运行更新进程 (apt/dpkg 被占用)，正在等待锁释放... ($i s)${PLAIN}"
        sleep 2
        let i+=2
        if [ $i -gt 120 ]; then
            echo -e "${RED}等待超时，正在尝试强制释放锁...${PLAIN}"
            killall apt apt-get dpkg 2>/dev/null
            rm -f /var/lib/apt/lists/lock
            rm -f /var/lib/dpkg/lock
            rm -f /var/lib/dpkg/lock-frontend
            dpkg --configure -a
            break
        fi
    done
}

# ==============================================================
# 第一步：暴力补全依赖 (包含 DNS 修复与换源逻辑)
# ==============================================================
if [ -f /etc/debian_version ]; then
    # Debian/Ubuntu
    echo -e "${YELLOW}检测到 Debian/Ubuntu 系统，开始依赖修复流程...${PLAIN}"

    # 1. 临时修改 DNS 为 Google/Cloudflare (解决软件源解析失败)
    if ! grep -q "8.8.8.8" /etc/resolv.conf; then
        echo -e "${YELLOW}正在优化 DNS 解析...${PLAIN}"
        cp /etc/resolv.conf /etc/resolv.conf.bak
        echo "nameserver 8.8.8.8" > /etc/resolv.conf
        echo "nameserver 1.1.1.1" >> /etc/resolv.conf
    fi

    # 2. 等待并清理锁
    wait_for_lock
    
    # 3. 清理缓存 (解决 Hash Sum mismatch)
    rm -rf /var/lib/apt/lists/*
    
    # 4. 尝试第一轮更新安装
    echo -e "${YELLOW}正在更新软件源并安装依赖...${PLAIN}"
    apt-get update -y
    # 增加 -o Acquire::ForceIPv4=true 强制使用 IPv4 避免 IPv6 网络问题
    apt-get -o Acquire::ForceIPv4=true install -y --fix-missing cron socat curl lsof tar

    # 5. 失败检测与自动换源 (如果第一轮失败)
    if ! command -v socat &> /dev/null; then
        echo -e "${RED}依赖安装失败，正在切换为官方源并重试...${PLAIN}"
        
        cp /etc/apt/sources.list /etc/apt/sources.list.bak2
        
        if grep -q "Ubuntu" /etc/issue || grep -q "Ubuntu" /etc/os-release; then
            # Ubuntu 官方源
            echo "deb http://archive.ubuntu.com/ubuntu/ $(lsb_release -sc) main restricted universe multiverse" > /etc/apt/sources.list
            echo "deb http://archive.ubuntu.com/ubuntu/ $(lsb_release -sc)-updates main restricted universe multiverse" >> /etc/apt/sources.list
            echo "deb http://archive.ubuntu.com/ubuntu/ $(lsb_release -sc)-security main restricted universe multiverse" >> /etc/apt/sources.list
        else
            # Debian 官方源
            echo "deb http://deb.debian.org/debian $(lsb_release -sc) main contrib non-free" > /etc/apt/sources.list
            echo "deb http://deb.debian.org/debian $(lsb_release -sc)-updates main contrib non-free" >> /etc/apt/sources.list
        fi
        
        # 再次清理并更新
        rm -rf /var/lib/apt/lists/*
        apt-get update -y
        apt-get -o Acquire::ForceIPv4=true install -y --fix-missing cron socat curl lsof tar
    fi

    systemctl enable cron
    systemctl start cron

elif [ -f /etc/redhat-release ]; then
    # CentOS/AlmaLinux
    echo -e "${YELLOW}检测到 CentOS/RedHat 系统...${PLAIN}"
    
    # CentOS 也可以尝试修 DNS
    if ! grep -q "8.8.8.8" /etc/resolv.conf; then
        cp /etc/resolv.conf /etc/resolv.conf.bak
        echo "nameserver 8.8.8.8" > /etc/resolv.conf
    fi

    yum clean all
    yum makecache
    yum update -y
    yum install -y cronie socat curl lsof tar
    systemctl enable crond
    systemctl start crond
fi

# 最终检查
if ! command -v socat &> /dev/null; then
    echo -e "${RED}严重错误：socat 安装仍然失败！${PLAIN}"
    echo -e "${RED}建议手动运行 'apt-get install -y socat' 查看具体报错信息。${PLAIN}"
    # 恢复 DNS 防止影响其他服务 (可选，这里暂时不恢复，因为8.8.8.8通常更好)
    exit 1
else
    echo -e "${GREEN}依赖环境 (socat/curl/cron) 安装验证通过！${PLAIN}"
fi

# ==============================================================
# 第二步：解决 acme.sh 的 ZeroSSL 邮箱验证死循环
# ==============================================================
if ! command -v ~/.acme.sh/acme.sh &> /dev/null; then
    echo -e "${YELLOW}正在安装 acme.sh...${PLAIN}"
    curl https://get.acme.sh | sh
fi

echo -e "${YELLOW}正在切换证书默认机构为 Let's Encrypt (跳过邮箱验证)...${PLAIN}"
~/.acme.sh/acme.sh --set-default-ca --server letsencrypt

# ==============================================================
# 第三步：端口 80 大扫除
# ==============================================================
echo -e "${YELLOW}正在检测 80 端口占用...${PLAIN}"
if lsof -i :80 | grep -q "LISTEN"; then
    echo -e "${RED}检测到 80 端口被占用，正在执行强制清理...${PLAIN}"
    systemctl stop nginx 2>/dev/null
    systemctl stop apache2 2>/dev/null
    systemctl stop httpd 2>/dev/null
    lsof -t -i:80 | xargs kill -9 2>/dev/null
    echo -e "${GREEN}80 端口已释放。${PLAIN}"
else
    echo -e "${GREEN}80 端口空闲，检测通过。${PLAIN}"
fi

# ==============================================================
# 第四步：拉起原版 3x-ui 脚本 (自动确认安装)
# ==============================================================
echo -e "${GREEN}环境准备就绪，正在启动 X-UI 安装程序...${PLAIN}"
echo -e "${YELLOW}提示：已自动帮你跳过安装确认，请直接设置账号密码。${PLAIN}"

bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh) <<< "y"
