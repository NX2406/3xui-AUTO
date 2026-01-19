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
# 第一步：暴力补全依赖 (针对 DMIT/搬瓦工 等精简镜像)
# --------------------------------------------------------------
if [ -f /etc/debian_version ]; then
    # Debian/Ubuntu
    apt update -y
    # 强制安装 cron, socat, lsof, curl, tar (防止脚本运行中途找不到命令)
    apt install -y cron socat curl lsof tar
    systemctl enable cron
    systemctl start cron
elif [ -f /etc/redhat-release ]; then
    # CentOS/AlmaLinux
    yum update -y
    yum install -y cronie socat curl lsof tar
    systemctl enable crond
    systemctl start crond
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
