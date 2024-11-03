#!/bin/bash

gl_huang='\033[33m'
gl_lv='\033[32m'
gl_bai='\033[0m'

add_ssl() {
  local domain="${1:-}"
  if [ -z "$domain" ]; then
    add_domain
  fi
  ensure_docker
  ensure_certbot
  delete_existing_cert "$domain"
  request_ssl_cert "$domain"
  certs_status "$domain"
  display_ssl_cert_info "$domain"
  show_cert_expiry
}

add_domain() {
  ip_address
  echo -e "先将域名解析到本机IP: ${gl_huang}$ipv4_address  $ipv6_address${gl_bai}"
  read -e -p "请输入你解析的域名: " domain
}

ensure_docker() {
  if ! command -v docker &>/dev/null; then
    install_add_docker
  else
    echo -e "${gl_lv}Docker环境已经安装${gl_bai}"
  fi
}

ensure_certbot() {
  if ! command -v certbot &>/dev/null; then
    echo "安装 Certbot..."
    curl -sS -O https://raw.githubusercontent.com/ecouus/Shell/refs/heads/main/renew_cert.sh
        if [ $? -ne 0 ]; then
            echo "下载失败，请检查网络或文件路径。"
            exit 1
        fi
    chmod +x renew_cert.sh
    schedule_cert_renewal
  fi
}

schedule_cert_renewal() {
  check_crontab_installed
  cron_job="0 0 * * * ~/renew_cert.sh"
  if ! crontab -l 2>/dev/null | grep -q "$cron_job"; then
    (crontab -l 2>/dev/null; echo "$cron_job") | crontab -
    echo "续签任务已添加"
  fi
}

delete_existing_cert() {
  local domain=$1
  yes | certbot delete --cert-name "$domain" > /dev/null 2>&1
}

request_ssl_cert() {
  local domain=$1
  docker stop nginx > /dev/null 2>&1
  iptables_open > /dev/null 2>&1
  if ! docker run -it --rm -p 80:80 -v /etc/letsencrypt/:/etc/letsencrypt certbot/certbot certonly --standalone -d "$domain" --email your@email.com --agree-tos --no-eff-email --force-renewal --key-type ecdsa; then
    echo "证书申请失败，请检查域名解析是否正确！"
    exit 1
  fi
  cp /etc/letsencrypt/live/$domain/fullchain.pem /home/web/certs/${domain}_cert.pem > /dev/null 2>&1
  cp /etc/letsencrypt/live/$domain/privkey.pem /home/web/certs/${domain}_key.pem > /dev/null 2>&1
  docker start nginx > /dev/null 2>&1
}

display_ssl_cert_info() {
  local domain=$1
  echo -e "${gl_huang}$domain 公钥信息${gl_bai}"
  cat /etc/letsencrypt/live/$domain/fullchain.pem
  echo ""
  echo -e "${gl_huang}$domain 私钥信息${gl_bai}"
  cat /etc/letsencrypt/live/$domain/privkey.pem
  echo ""
  echo -e "${gl_huang}证书存放路径${gl_bai}"
  echo "公钥: /etc/letsencrypt/live/$domain/fullchain.pem"
  echo "私钥: /etc/letsencrypt/live/$domain/privkey.pem"
  echo ""
}

show_cert_expiry() {
  echo -e "${gl_huang}已申请的证书到期情况${gl_bai}"
  echo "站点信息                      证书到期时间"
  echo "------------------------"
  for cert_dir in /etc/letsencrypt/live/*; do
    cert_file="$cert_dir/fullchain.pem"
    if [ -f "$cert_file" ]; then
      local domain=$(basename "$cert_dir")
      local expire_date=$(openssl x509 -noout -enddate -in "$cert_file" | awk -F'=' '{print $2}')
      local formatted_date=$(date -d "$expire_date" '+%Y-%m-%d')
      printf "%-30s%s\n" "$domain" "$formatted_date"
    fi
  done
  echo ""
}

# 自动调用 add_ssl 函数
add_ssl
