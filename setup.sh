#!/bin/bash

# ==============================================================
# 🚀 X-UI 智能引导安装脚本 (环境修复 + 证书向导 + 自动安装)
# ==============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
PLAIN='\033[0m'

# 1. 基础环境修复 (静默执行)
echo -e "${YELLOW}正在初始化系统环境...${PLAIN}"
if [ -f /etc/debian_version ]; then
    apt update -y && apt install -y cron socat curl lsof tar openssl
    systemctl enable cron && systemctl start cron
elif [ -f /etc/redhat-release ]; then
    yum update -y && yum install -y cronie socat curl lsof tar openssl
    systemctl enable crond && systemctl start crond
fi

# 2. 端口清理 (静默执行)
if lsof -i :80 | grep -q "LISTEN"; then
    echo -e "${YELLOW}释放 80 端口...${PLAIN}"
    lsof -t -i:80 | xargs kill -9 2>/dev/null
fi

# ==============================================================
# 🎯 交互式证书向导 (核心修改部分)
# ==============================================================
clear
echo -e "========================================================"
echo -e "${GREEN}             X-UI 证书配置向导             ${PLAIN}"
echo -e "========================================================"
echo -e "请选择你的证书模式："
echo -e "  ${GREEN}1.${PLAIN} 我有域名 (申请 Let's Encrypt 真实证书，推荐)"
echo -e "  ${GREEN}2.${PLAIN} 我没有域名 (生成 IP 自签名证书，浏览器会提示不安全)"
echo -e "========================================================"
read -p "请输入选项 [1-2] (默认1): " ssl_choice
[ -z "$ssl_choice" ] && ssl_choice="1"

# 准备存放证书的目录
mkdir -p /root/cert

if [ "$ssl_choice" == "1" ]; then
    # --- 选项1：域名证书 ---
    read -p "请输入你的域名 (例如 your.com): " user_domain
    if [ -z "$user_domain" ]; then
        echo -e "${RED}错误：域名不能为空！${PLAIN}"
        exit 1
    fi

    # 安装 acme.sh 并申请
    echo -e "${YELLOW}正在安装 acme.sh 并申请证书...${PLAIN}"
    curl https://get.acme.sh | sh
    ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
    ~/.acme.sh/acme.sh --issue -d "$user_domain" --standalone --force

    # 安装证书到指定目录
    ~/.acme.sh/acme.sh --install-cert -d "$user_domain" \
        --key-file       /root/cert/private.key \
        --fullchain-file /root/cert/cert.crt
    
    CERT_PATH="/root/cert/cert.crt"
    KEY_PATH="/root/cert/private.key"
    echo -e "${GREEN}域名证书申请完成！${PLAIN}"

else
    # --- 选项2：IP 自签名证书 ---
    echo -e "${YELLOW}正在检测公网 IP 并生成自签名证书...${PLAIN}"
    public_ip=$(curl -s4 ifconfig.me)
    
    openssl req -x509 -newkey rsa:2048 -nodes -sha256 -keyout /root/cert/private.key -out /root/cert/cert.crt -days 3650 -subj "/C=US/ST=Earth/L=City/O=X-UI/OU=IT/CN=$public_ip"
    
    CERT_PATH="/root/cert/cert.crt"
    KEY_PATH="/root/cert/private.key"
    echo -e "${GREEN}IP 自签名证书生成完成！(有效期10年)${PLAIN}"
fi

# ==============================================================
# 🚀 自动安装 X-UI 面板
# ==============================================================
echo -e "${YELLOW}正在启动 X-UI 安装程序...${PLAIN}"

# 这里你可以修改默认的账号密码端口
bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh) <<EOF
y
admin
admin
54321
EOF

# ==============================================================
# 🏁 结束汇总
# ==============================================================
clear
echo -e "========================================================"
echo -e "${GREEN}           安装全部完成！(Install Complete)           ${PLAIN}"
echo -e "========================================================"
echo -e "面板地址: ${YELLOW}http://$(curl -s4 ifconfig.me):54321${PLAIN}"
echo -e "用户名:   ${YELLOW}admin${PLAIN}"
echo -e "密码:     ${YELLOW}admin${PLAIN}"
echo -e "--------------------------------------------------------"
echo -e "请进入面板 -> 面板设置 -> Xray配置，填入以下路径："
echo -e "公钥路径 (Certificate): ${GREEN}$CERT_PATH${PLAIN}"
echo -e "私钥路径 (Private Key): ${GREEN}$KEY_PATH${PLAIN}"
echo -e "========================================================"
