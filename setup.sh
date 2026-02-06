#!/bin/bash

# ==============================================================
# 🚀 X-UI 极简系统环境修复 & 全自动安装脚本
# ==============================================================
# 功能列表：
# 1. 自动补全 Debian/CentOS 缺失的基础依赖 (cron, socat, lsof等)
# 2. 自动安装 acme.sh 并强制切换为 Let's Encrypt (免邮箱/免验证)
# 3. 自动检测并杀掉占用 80 端口的进程 (Nginx/Apache)
# 4. 自动拉起 3x-ui 安装脚本，并自动确认 "是否安装" 的回车步骤
# ==============================================================

# 定义颜色，看起来更专业
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
PLAIN='\033[0m'

echo -e "${YELLOW}正在检查系统环境...${PLAIN}"

# --------------------------------------------------------------
# 第一步：暴力补全依赖 (针对 DMIT/搬瓦工/OVH 等各种镜像优化)
# --------------------------------------------------------------
if [ -f /etc/debian_version ]; then
    # Debian/Ubuntu
    echo -e "${YELLOW}检测到 Debian/Ubuntu 系统，正在优化软件源并更新...${PLAIN}"
    
    # [新增] 1. 强力清理旧缓存 (解决 Hash Sum mismatch 问题)
    rm -rf /var/lib/apt/lists/*
    
    # 2. 尝试常规更新
    apt-get update -y
    
    # [新增] 3. 安装依赖 (增加 --fix-missing 自动修复参数)
    echo -e "${YELLOW}正在安装基础依赖 (cron, socat, curl)...${PLAIN}"
    apt-get install -y --fix-missing cron socat curl lsof tar

    # [新增] 4. 失败检测与自动换源 (解决 OVH 404 问题)
    if ! command -v socat &> /dev/null; then
        echo -e "${RED}依赖安装失败 (可能是镜像源损坏)，正在尝试切换回官方源重试...${PLAIN}"
        
        # 备份源文件
        cp /etc/apt/sources.list /etc/apt/sources.list.bak
        
        # 智能识别系统并替换源
        if grep -q "Ubuntu" /etc/issue || grep -q "Ubuntu" /etc/os-release; then
            # Ubuntu: 替换为 archive.ubuntu.com
            sed -i 's/http:\/\/.*\.com/http:\/\/archive.ubuntu.com/g' /etc/apt/sources.list
            sed -i 's/http:\/\/.*\.net/http:\/\/archive.ubuntu.com/g' /etc/apt/sources.list
            sed -i 's/http:\/\/.*\.org/http:\/\/archive.ubuntu.com/g' /etc/apt/sources.list
        else
            # Debian: 替换为 deb.debian.org
            sed -i 's/http:\/\/.*\.com/http:\/\/deb.debian.org/g' /etc/apt/sources.list
            sed -i 's/http:\/\/.*\.net/http:\/\/deb.debian.org/g' /etc/apt/sources.list
            sed -i 's/http:\/\/.*\.org/http:\/\/deb.debian.org/g' /etc/apt/sources.list
        fi
        
        # 再次清理并更新
        rm -rf /var/lib/apt/lists/*
        apt-get update -y
        apt-get install -y --fix-missing cron socat curl lsof tar
    fi

    systemctl enable cron
    systemctl start cron

elif [ -f /etc/redhat-release ]; then
    # CentOS/AlmaLinux
    echo -e "${YELLOW}检测到 CentOS/RedHat 系统，正在更新...${PLAIN}"
    yum clean all
    yum makecache
    yum update -y
    yum install -y cronie socat curl lsof tar
    systemctl enable crond
    systemctl start crond
fi

# 再次检查关键依赖 socat 是否存在，确保不带病运行
if ! command -v socat &> /dev/null; then
    echo -e "${RED}严重错误：依赖 (socat) 安装失败，脚本无法继续。${PLAIN}"
    echo -e "${RED}请尝试手动执行: apt-get update && apt-get install -y socat${PLAIN}"
    exit 1
fi

echo -e "${GREEN}依赖环境安装完毕！${PLAIN}"

# --------------------------------------------------------------
# 第二步：解决 acme.sh 的 ZeroSSL 邮箱验证死循环
# --------------------------------------------------------------
if ! command -v ~/.acme.sh/acme.sh &> /dev/null; then
    echo -e "${YELLOW}正在安装 acme.sh...${PLAIN}"
    curl https://get.acme.sh | sh
fi

echo -e "${YELLOW}正在切换证书默认机构为 Let's Encrypt (跳过邮箱验证)...${PLAIN}"
# 这一步是关键，防止出现 "Please update your account with an email" 报错
~/.acme.sh/acme.sh --set-default-ca --server letsencrypt

# --------------------------------------------------------------
# 第三步：端口 80 大扫除
# --------------------------------------------------------------
echo -e "${YELLOW}正在检测 80 端口占用...${PLAIN}"
if lsof -i :80 | grep -q "LISTEN"; then
    echo -e "${RED}检测到 80 端口被占用，正在执行强制清理...${PLAIN}"
    # 优先停止服务
    systemctl stop nginx 2>/dev/null
    systemctl stop apache2 2>/dev/null
    systemctl stop httpd 2>/dev/null
    # 强制杀进程 (双重保险)
    lsof -t -i:80 | xargs kill -9 2>/dev/null
    echo -e "${GREEN}80 端口已释放。${PLAIN}"
else
    echo -e "${GREEN}80 端口空闲，检测通过。${PLAIN}"
fi

# --------------------------------------------------------------
# 第四步：拉起原版 3x-ui 脚本 (自动确认安装)
# --------------------------------------------------------------
echo -e "${GREEN}环境准备就绪，正在启动 X-UI 安装程序...${PLAIN}"
echo -e "${YELLOW}提示：已自动帮你跳过安装确认，请直接设置账号密码。${PLAIN}"

# 解释：这里使用了 <<< "y" 将 "y" 自动输入给脚本
# 解决了你遇到的 "需要手动按一下回车确认安装" 的问题
bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh) <<< "y"
