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

    if [[ -n "$ipv4_address" ]]; then
        ip_address=$ipv4_address
    elif [[ -n "$ipv6_address" ]]; then
        ip_address=[$ipv6_address]
    else
        echo "无法获取IP地址"
        ip_address=""
    fi
}

check_port() {
    PORT=$1
    if ss -tuln | grep -q ":$PORT "; then
        echo -e "${RED}错误: 端口 $PORT 已被占用 (LISTEN)${NC}"
        ss -tulnp | grep ":$PORT "
        return 1
    fi
    return 0
}


install_or_update() {
    echo -e "${GREEN}开始安装所需组件...${NC}"
    check_port 80 || { read -p "按回车返回主菜单..."; return 1; }
    check_port 443 || { read -p "按回车返回主菜单..."; return 1; }

    apt update && \
    apt install nginx -y && \
    apt install net-tools -y && \
    apt install certbot -y

    systemctl enable nginx
    systemctl start nginx

    if ! crontab -l 2>/dev/null | grep -Fxq "@weekly systemctl stop nginx && certbot renew --standalone --pre-hook 'systemctl stop nginx' --post-hook 'systemctl start nginx'"; then
        (crontab -l 2>/dev/null; echo "@weekly systemctl stop nginx && certbot renew --standalone --pre-hook 'systemctl stop nginx' --post-hook 'systemctl start nginx'") | crontab -
    fi

    echo -e "${GREEN}安装和配置已完成${NC}"
}

cert_only() {
    clear
    check_ip_address
    echo "本机IP: $ip_address"
    
    read -p "申请证书域名为: " domain

    systemctl stop nginx
    certbot certonly --standalone -d ${domain} --non-interactive --agree-tos --email admin@${domain} || {
        echo -e "${RED}证书申请失败${NC}"
        systemctl start nginx
        return 1
    }
    systemctl start nginx

    echo -e "${GREEN}证书申请成功！${NC}"
    echo -e "\n证书路径:"
    echo "私钥: /etc/letsencrypt/live/${domain}/privkey.pem"
    echo "公钥: /etc/letsencrypt/live/${domain}/fullchain.pem"

    echo -e "\n私钥内容:"
    echo "------------------------"
    cat "/etc/letsencrypt/live/${domain}/privkey.pem"
    echo -e "\n公钥内容:"
    echo "------------------------"
    cat "/etc/letsencrypt/live/${domain}/fullchain.pem"

    if ! crontab -l 2>/dev/null | grep -Fxq "@weekly systemctl stop nginx && certbot renew --standalone --pre-hook 'systemctl stop nginx' --post-hook 'systemctl start nginx'"; then
        (crontab -l 2>/dev/null; echo "@weekly systemctl stop nginx && certbot renew --standalone --pre-hook 'systemctl stop nginx' --post-hook 'systemctl start nginx'") | crontab -
        echo -e "\n${GREEN}已配置 standalone 自动续签计划任务${NC}"
    fi
}

proxy() {
    clear
    check_ip_address
    echo "本机IP: $ip_address"

    read -p "输入域名 (例如a.com): " domain
    read -p "输入反代目标 (例如 1.1.1.1:123 或 b.com): " target

    mkdir -p "$NGINX_DIR"
    wget -O "$NGINX_DIR/${domain}" "$PROXY_URL" || { echo -e "${RED}下载配置失败${NC}"; return 1; }

    if [[ "$target" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+$ ]]; then
        sed -i "s/example/${domain}/g; s|127.0.0.1:0000|${target}|g" "$NGINX_DIR/${domain}"
    else
        sed -i "s/example/${domain}/g; s|127.0.0.1:0000|${target}|g; s|proxy_set_header Host \$host;|proxy_set_header Host ${target};|g" "$NGINX_DIR/${domain}"
    fi

    ln -sf "$NGINX_DIR/${domain}" "/etc/nginx/sites-enabled/${domain}"
    nginx -t && systemctl reload nginx || { echo -e "${RED}Nginx配置错误${NC}"; return 1; }

    certbot --nginx -d ${domain} --non-interactive --agree-tos --email admin@${domain} --redirect || {
        echo -e "${RED}SSL配置失败${NC}"
        return 1
    }

    echo -e "${GREEN}配置完成: https://${domain} -> ${target}${NC}"
}

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

    certbot --nginx -d ${domain} --non-interactive --agree-tos --email admin@${domain} --redirect || {
        echo -e "${RED}SSL配置失败${NC}"
        return 1
    }

    echo -e "${GREEN}配置完成: https://${domain} -> ${url}${NC}"
}

manage() {
    echo "已配置的域名:"
    echo "------------------------"
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

        if grep -q "proxy_pass" "$conf"; then
            target=$(grep "proxy_pass" "$conf" | awk '{print $2}' | tr -d ';')
            config_type="反代至: $target"
        elif grep -q "root" "$conf" && ! grep -q "^[[:space:]]*root[[:space:]]/var/www/html;" "$conf"; then
            root_path=$(grep "root" "$conf" | head -n1 | awk '{print $2}' | tr -d ';')
            config_type="普通站点 (根目录: $root_path)"
        elif grep -q "return 301" "$conf" && ! grep -q "\$host\$request_uri" "$conf" && ! grep -q "\$scheme://\$host\$request_uri" "$conf"; then
            target=$(grep "return 301" "$conf" | grep -v "\$host" | awk '{print $3}' | tr -d ';')
            config_type="重定向至: $target"
        else
            config_type="普通站点"
        fi

        if [[ -n "${expiry_dates[$domain]}" ]]; then
            echo "$domain  > $config_type (距离下次续签: ${valid_days[$domain]}天)"
        else
            echo "$domain  > $config_type (无SSL证书)"
        fi
    done

    echo -e "\n仅申请证书的域名:"
    echo "------------------------"
    for cert_dir in /etc/letsencrypt/live/*; do
        [ -d "$cert_dir" ] || continue
        domain=$(basename "$cert_dir")
        [ -f "$NGINX_DIR/$domain" ] && continue
        if [[ -n "${expiry_dates[$domain]}" ]]; then
            echo "$domain (距离下次续签: ${valid_days[$domain]}天)"
        fi
    done

    echo -e "\n${RED}可能续签失败的证书（无 nginx 配置，非 standalone 模式）:${NC}"
    echo "------------------------"
    for cert_dir in /etc/letsencrypt/live/*; do
        [ -d "$cert_dir" ] || continue
        domain=$(basename "$cert_dir")
        if [[ ! -f "$NGINX_DIR/$domain" ]] && ! grep -q "authenticator = standalone" "/etc/letsencrypt/renewal/${domain}.conf" 2>/dev/null; then
            echo "$domain (请检查是否能正常续签)"
        fi
    done

    [ $count -eq 0 ] && echo "暂无配置"
    echo "------------------------"
    echo "输入要删除的域名(直接回车取消):"
    read domain
    [ -z "$domain" ] && return

    conf_path="$NGINX_DIR/${domain}"

    # 检查是否存在配置或证书
    has_conf=false
    has_cert=false
    [ -f "$conf_path" ] && has_conf=true
    [ -d "/etc/letsencrypt/live/${domain}" ] && has_cert=true

    if ! $has_conf && ! $has_cert; then
        echo -e "${RED}未找到该域名的配置或证书${NC}"
        return
    fi

    # 删除 Nginx 配置
    if $has_conf; then
        rm -f "$conf_path"
        rm -f "/etc/nginx/sites-enabled/${domain}"
        echo -e "${GREEN}已删除 Nginx 配置${NC}"
    fi

    # 删除证书（可选）
    if $has_cert; then
        echo -e "${RED}检测到 SSL 证书，是否一并撤销并删除？(y/n):${NC}"
        read revoke
        if [[ "$revoke" == "y" ]]; then
            certbot revoke --cert-name ${domain} --delete-after-revoke --non-interactive
            echo -e "${GREEN}已撤销并删除证书${NC}"
        else
            echo "已保留 SSL 证书"
        fi
    fi

    nginx -t && systemctl reload nginx
    echo -e "${GREEN}删除完成${NC}"
}



cd_nginx() {
    cd /etc/nginx/sites-available
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
        10) cd_nginx ;;
        0) exit ;;
        *) echo -e "${RED}无效选项${NC}" ;;
    esac
    echo; read -p "按回车继续..."
done
