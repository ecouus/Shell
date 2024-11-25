#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'
PROXY_URL="https://raw.githubusercontent.com/ecouus/Shell/refs/heads/main/conf/Reverse_proxy.conf"
REDIRECT_URL="https://raw.githubusercontent.com/ecouus/Shell/refs/heads/main/conf/Redirect.conf"
NGINX_DIR="/etc/nginx/sites-available"

[[ $(id -u) != 0 ]] && echo -e "${RED}需要root权限${NC}" && exit 1

check_ip_address() {
    local ipv4_address=$(curl -s --max-time 5 ipv4.ip.sb)
    local ipv6_address=$(curl -s --max-time 5 ipv6.ip.sb)

    # 判断IPv4地址是否获取成功
    if [[ -n "$ipv4_address" ]]; then
        ip_address=$ipv4_address
    elif [[ -n "$ipv6_address" ]]; then
        # 如果IPv4地址未获取到，但IPv6地址获取成功，则使用IPv6地址
        ip_address=[$ipv6_address]
    else
        # 如果两个地址都没有获取到，可以在这里处理这种情况
        echo "无法获取IP地址"
        ip_address=""
    fi
}

# 安装或更新工具
install_or_update_tool() {
    # 遍历传入的工具列表
    for TOOL in "$@"; do
        # 更新软件源
        if [ -f /etc/debian_version ]; then
            apt update -y &>/dev/null
        elif [ -f /etc/redhat-release ]; then
            yum makecache -y &>/dev/null
        fi

        # 检查并安装或更新工具
        if ! command -v $TOOL &>/dev/null; then
            if [ -f /etc/debian_version ]; then
                apt install -y $TOOL &>/dev/null
            elif [ -f /etc/redhat-release ]; then
                yum install -y $TOOL &>/dev/null
            fi
        else
            if [ -f /etc/debian_version ]; then
                apt install --only-upgrade -y $TOOL &>/dev/null
            elif [ -f /etc/redhat-release ]; then
                yum update -y $TOOL &>/dev/null
            fi
        fi
    done
}

# 检测端口是否被占用
check_port() {
    PORT=$1
    if lsof -i:$PORT &>/dev/null; then
        exit 1
    fi
}

install_or_update() {
    # 检查并更新所需工具
    install_or_update_tool nginx certbot python3-certbot-nginx curl wget

    check_port 80
    check_port 443

    # 启动 nginx 并设置开机自启
    systemctl enable nginx &>/dev/null
    systemctl start nginx &>/dev/null

    # 设置证书自动续期
    if ! crontab -l 2>/dev/null | grep -Fxq "0 9 * * 1 certbot renew -q"; then
    (crontab -l 2>/dev/null; echo "0 9 * * 1 certbot renew -q") | crontab - &>/dev/null
    fi

    echo -e "${GREEN}安装或更新完成${NC}"
    read -p "按回车返回..."
}

# ———————————————————————————————

# 配置反向代理
proxy() {
    clear
    check_ip_address
    echo "本机IP:$ip_address"
    read -p "输入域名: " domain
    read -p "输入反代IP: " ip
    read -p "输入反代端口: " port

    # 1. 下载并配置nginx
    mkdir -p $NGINX_DIR
    wget -O "$NGINX_DIR/${domain}" "$PROXY_URL" || { echo -e "${RED}下载配置失败${NC}"; return 1; }
    sed -i "s/example/${domain}/g; s/127.0.0.1:0000/${ip}:${port}/g" "$NGINX_DIR/${domain}"
    ln -sf "$NGINX_DIR/${domain}" "/etc/nginx/sites-enabled/${domain}"

    # 2. 检查并应用配置
    nginx -t && systemctl reload nginx || { echo -e "${RED}Nginx配置错误${NC}"; return 1; }

    # 3. 配置SSL
    certbot --nginx -d ${domain} --non-interactive --agree-tos --email admin@${domain} --redirect || \
    { echo -e "${RED}SSL配置失败${NC}"; return 1; }

    echo -e "${GREEN}配置完成: https://${domain} -> ${ip}:${port}${NC}"
}

# 配置重定向
redirect() {
    clear
    check_ip_address
    echo "本机IP:$ip_address"
    read -p "输入域名: " domain
    read -p "输入目标URL: " url

    mkdir -p $NGINX_DIR
    wget -O "$NGINX_DIR/${domain}" "$REDIRECT_URL"
    sed -i "s/example.com/${domain}/g; s|https://baidu.com|${url}|g" "$NGINX_DIR/${domain}"
    ln -sf "$NGINX_DIR/${domain}" "/etc/nginx/sites-enabled/${domain}"

    nginx -t && systemctl reload nginx || { echo -e "${RED}Nginx配置错误${NC}"; return 1; }

    certbot --nginx -d ${domain} --non-interactive --agree-tos --email admin@${domain} --redirect || \
    { echo -e "${RED}SSL配置失败${NC}"; return 1; }

    echo -e "${GREEN}配置完成: https://${domain} -> ${url}${NC}"
}

# 管理配置
manage() {
    echo "已配置的域名:"
    echo "------------------------"
    count=0
    for conf in $NGINX_DIR/*; do
        [ -f "$conf" ] || continue
        ((count++))
        domain=$(basename "$conf")
        if grep -q "proxy_pass" "$conf"; then
            target=$(grep "proxy_pass" "$conf" | awk '{print $2}' | tr -d ';')
            echo "$count. $domain  > 反代至: $target"
        else
            target=$(grep "return 301" "$conf" | awk '{print $3}' | cut -d'$' -f1)
            echo "$count. $domain  > 重定向至: $target"
        fi
    done
    [ $count -eq 0 ] && echo "暂无配置"
    echo "------------------------"
    echo "输入要删除的域名(直接回车取消):"
    read domain
    [ -z "$domain" ] && return
    [ -f "$NGINX_DIR/${domain}" ] || { echo "域名不存在"; return; }

    rm -f "$NGINX_DIR/${domain}"
    rm -f "/etc/nginx/sites-enabled/${domain}"
    [ -d "/etc/letsencrypt/live/${domain}" ] && certbot revoke --cert-name ${domain} --delete-after-revoke --non-interactive
    nginx -t && systemctl reload nginx && echo -e "${GREEN}删除完成${NC}"
}

# 主菜单
while true; do
    clear
    echo -e "${GREEN}Nginx配置管理${NC}"
    echo "1. 安装/更新所需软件
2. 配置反代
3. 配置重定向
9. 管理配置
0. 退出"
    read -p "选择功能: " choice

    case "$choice" in
        1) install_or_update ;;
        2) proxy ;;
        3) redirect ;;
        9) manage ;;
        0) exit ;;
        *) echo -e "${RED}无效选项${NC}" ;;
    esac
    echo; read -p "按回车继续..."
done
