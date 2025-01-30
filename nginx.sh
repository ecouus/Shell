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

# 端口检查函数
check_port() {
    PORT=$1
    if netstat -tuln | grep ":$PORT " | grep -q "LISTEN"; then
        echo -e "${RED}错误: 端口 $PORT 已被占用 (LISTEN)${NC}"
        echo "占用详情:"
        netstat -tulnp | grep ":$PORT "
        return 1
    fi
    return 0
}

# 安装或更新工具
install_or_update() {
    echo -e "${GREEN}开始安装所需组件...${NC}"
    
    # 检查端口
    check_port 80 || { read -p "按回车返回主菜单..."; return 1; }
    check_port 443 || { read -p "按回车返回主菜单..."; return 1; }

    # 安装组件
    apt update && \
    apt install nginx -y && \
    apt install net-tools -y && \
    apt install certbot python3-certbot-nginx -y

    systemctl enable nginx
    systemctl start nginx

    if ! crontab -l 2>/dev/null | grep -Fxq "0 9 * * 1 certbot renew -q"; then
        (crontab -l 2>/dev/null; echo "0 9 * * 1 certbot renew -q") | crontab -
    fi

    echo -e "${GREEN}安装和配置已完成${NC}"
}

# 仅申请证书功能
cert_only() {
    clear
    check_ip_address
    echo "本机IP: $ip_address"
    
    read -p "申请证书域名为: " domain
    
    # 确保nginx运行
    systemctl start nginx
    
    # 创建临时的nginx配置
    cat > "$NGINX_DIR/${domain}" << EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${domain};
    root /var/www/html;
}
EOF
    
    ln -sf "$NGINX_DIR/${domain}" "/etc/nginx/sites-enabled/${domain}"
    nginx -t && systemctl reload nginx || { echo -e "${RED}Nginx配置错误${NC}"; return 1; }
    
    # 申请证书
    certbot certonly --nginx -d ${domain} --non-interactive --agree-tos --email admin@${domain} || \
    { echo -e "${RED}证书申请失败${NC}"; return 1; }
    
    # 输出证书路径和内容
    echo -e "${GREEN}证书申请成功！${NC}"
    echo -e "\n证书路径:"
    echo "私钥: /etc/letsencrypt/live/${domain}/privkey.pem"
    echo "公钥: /etc/letsencrypt/live/${domain}/fullchain.pem"
    
    echo -e "\n证书内容:"
    echo -e "\n私钥内容:"
    echo "------------------------"
    cat "/etc/letsencrypt/live/${domain}/privkey.pem"
    echo -e "\n公钥内容:"
    echo "------------------------"
    cat "/etc/letsencrypt/live/${domain}/fullchain.pem"
    
    # 配置自动续签
    if ! crontab -l 2>/dev/null | grep -Fxq "0 9 * * 1 certbot renew -q"; then
        (crontab -l 2>/dev/null; echo "0 9 * * 1 certbot renew -q") | crontab -
        echo -e "\n${GREEN}已配置自动续签 (每周一上午9点)${NC}"
    fi
    
    # 清理临时配置
    rm -f "$NGINX_DIR/${domain}"
    rm -f "/etc/nginx/sites-enabled/${domain}"
    nginx -t && systemctl reload nginx
}

# 配置反向代理
proxy() {
    clear
    check_ip_address
    echo "本机IP: $ip_address"

    read -p "输入域名 (例如a.com):: " domain
    read -p "输入反代目标 (例如 1.1.1.1:123 或 b.com): " target

    mkdir -p "$NGINX_DIR"
    wget -O "$NGINX_DIR/${domain}" "$PROXY_URL" || { echo -e "${RED}下载配置失败${NC}"; return 1; }

    # 智能判断反代目标是否为 IP+端口或域名
    if [[ "$target" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+$ ]]; then
        # 如果是 IP:端口，保留原始 proxy_set_header Host $host;
        sed -i "s/example/${domain}/g; s|127.0.0.1:0000|${target}|g" "$NGINX_DIR/${domain}"
    else
        # 如果是域名，修改 proxy_set_header Host 为目标域名
        sed -i "s/example/${domain}/g; s|127.0.0.1:0000|${target}|g; s|proxy_set_header Host \$host;|proxy_set_header Host ${target};|g" "$NGINX_DIR/${domain}"
    fi

    ln -sf "$NGINX_DIR/${domain}" "/etc/nginx/sites-enabled/${domain}"

    nginx -t && systemctl reload nginx || { echo -e "${RED}Nginx配置错误${NC}"; return 1; }

    certbot --nginx -d ${domain} --non-interactive --agree-tos --email admin@${domain} --redirect || \
    { echo -e "${RED}SSL配置失败${NC}"; return 1; }

    echo -e "${GREEN}配置完成: https://${domain} -> ${target}${NC}"
}

# 配置重定向
redirect() {
    clear
    check_ip_address
    echo "本机IP:$ip_address"
    read -p "输入域名（例如a.com）: " domain
    read -p "输入目标URL(例如b.com): " url

    mkdir -p $NGINX_DIR
    wget -O "$NGINX_DIR/${domain}" "$REDIRECT_URL"
    sed -i "s/example.com/${domain}/g; s|targeturl.com|${url}|g" "$NGINX_DIR/${domain}"
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
    # 获取所有证书信息
    declare -A expiry_dates valid_days
    count=0
    while IFS= read -r line; do
        if [[ $line =~ "Certificate Name:" ]]; then
            current_cert=$(echo "$line" | awk '{print $NF}')
        elif [[ $line =~ "Expiry Date:" ]]; then
            expiry_dates[$current_cert]=$(echo "$line" | cut -d':' -f2- | sed 's/([^)]*)//g' | xargs)
            valid_days[$current_cert]=$(echo "$line" | grep -o 'VALID: [0-9]*' | awk '{print $2}')
        fi
    done < <(certbot certificates 2>/dev/null)
    
    for conf in $NGINX_DIR/*; do
        [ -f "$conf" ] || continue
        count=$((count + 1))
        domain=$(basename "$conf")
        
        # 获取配置类型
        if grep -q "proxy_pass" "$conf"; then
            target=$(grep "proxy_pass" "$conf" | awk '{print $2}' | tr -d ';')
            config_type="反代至: $target"
        elif grep -q "return 301" "$conf"; then
            target=$(grep "return 301" "$conf" | awk '{print $3}' | cut -d'$' -f1)
            config_type="重定向至: $target"
        else
            config_type="普通站点"
        fi
        
        # 获取证书续签时间
        if [[ -n "${expiry_dates[$domain]}" ]]; then
            echo "$count. $domain  > $config_type (距下次续签剩余: ${valid_days[$domain]} 天)"
        else
            echo "$count. $domain  > $config_type (无SSL证书)"
        fi
    done
    
    # 检查是否有证书但没有配置的域名
    if [ -d "/etc/letsencrypt/live" ]; then
        echo -e "\n仅申请证书的域名:"
        echo "------------------------"
        for cert_dir in /etc/letsencrypt/live/*; do
            [ -d "$cert_dir" ] || continue
            domain=$(basename "$cert_dir")
            # 跳过已经在nginx配置中的域名
            [ -f "$NGINX_DIR/$domain" ] && continue
            if [[ -n "${expiry_dates[$domain]}" ]]; then
                #echo "$domain (证书续签时间: ${expiry_dates[$domain]} (剩余: ${valid_days[$domain]} 天))"
                echo "$domain (距下次续签剩余: ${valid_days[$domain]} 天)"
            fi
        done
    fi
    
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
6. 仅申请证书
9. 管理配置
0. 退出"
    read -p "选择功能: " choice

    case "$choice" in
        1) install_or_update ;;
        2) proxy ;;
        3) redirect ;;
        6) cert_only ;;
        9) manage ;;
        0) exit ;;
        *) echo -e "${RED}无效选项${NC}" ;;
    esac
    echo; read -p "按回车继续..."
done
