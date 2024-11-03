certs_directory="/etc/letsencrypt/live/"
days_before_expiry=5
log_file="/var/log/cert_renewal.log"
certs_backup_path="/home/web/certs/"

for cert_dir in "${certs_directory}"*; do
    yuming=$(basename "$cert_dir")

    if [ "$yuming" = "README" ]; then
        continue
    fi

    echo "检查证书过期日期： ${yuming}" | tee -a "${log_file}"
    cert_file="${cert_dir}/fullchain.pem"

    if [ ! -f "${cert_file}" ]; then
        echo "证书文件不存在：${cert_file}" | tee -a "${log_file}"
        continue
    fi

    expiration_date=$(openssl x509 -enddate -noout -in "${cert_file}" | cut -d "=" -f 2-)
    echo "过期日期： ${expiration_date}" | tee -a "${log_file}"

    expiration_timestamp=$(date -d "${expiration_date}" +%s)
    current_timestamp=$(date +%s)
    days_until_expiry=$(( ($expiration_timestamp - $current_timestamp) / 86400 ))

    if [ "$days_until_expiry" -le "$days_before_expiry" ]; then
        echo "证书将在${days_before_expiry}天内过期，正在进行自动续签。" | tee -a "${log_file}"
        
        # 执行续签操作，注意避免不必要的删除
        docker stop nginx > /dev/null 2>&1

        # 开放防火墙规则
        iptables -P INPUT ACCEPT
        iptables -P FORWARD ACCEPT
        iptables -P OUTPUT ACCEPT
        iptables -F
        ip6tables -P INPUT ACCEPT
        ip6tables -P FORWARD ACCEPT
        ip6tables -P OUTPUT ACCEPT
        ip6tables -F

        docker run --rm -p 80:80 -v /etc/letsencrypt/:/etc/letsencrypt certbot/certbot certonly --standalone -d "$yuming" --email your@email.com --agree-tos --no-eff-email --force-renewal --key-type ecdsa

        cp "/etc/letsencrypt/live/$yuming/fullchain.pem" "${certs_backup_path}${yuming}_cert.pem" > /dev/null 2>&1
        cp "/etc/letsencrypt/live/$yuming/privkey.pem" "${certs_backup_path}${yuming}_key.pem" > /dev/null 2>&1

        openssl rand -out "${certs_backup_path}ticket12.key" 48
        openssl rand -out "${certs_backup_path}ticket13.key" 80

        docker start nginx > /dev/null 2>&1
        echo "证书已成功续签。" | tee -a "${log_file}"
    else
        echo "证书仍然有效，距离过期还有 ${days_until_expiry} 天。" | tee -a "${log_file}"
    fi

    echo "--------------------------" | tee -a "${log_file}"
done
