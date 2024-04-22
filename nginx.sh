#!/bin/bash

# 清除屏幕
clear

# 创建宿主机上的目录结构以存放Nginx配置和证书
mkdir -p /home/dc/nginx/{conf.d,ssl,certbot,www}

# 拉取Nginx的Docker镜像
echo "拉取Nginx Docker镜像..."
docker pull nginx:latest

# 读取用户输入的域名和目标网址
read -p "请输入你的域名（如 example.com）: " yuming
read -p "请输入目标网址（如 https://example-target.com）: " target_url

# 在宿主机上创建Nginx配置文件
config_file="/home/dc/nginx/conf.d/$yuming.conf"
cat << EOF > $config_file
server {
    listen 80;
    server_name $yuming www.$yuming;

    location / {
        proxy_pass $target_url;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }

    location /.well-known/acme-challenge/ {
        root /usr/share/nginx/html;
    }

    listen 443 ssl; # SSL configuration
    ssl_certificate /etc/nginx/ssl/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers on;
}
EOF

# 运行Nginx Docker容器
echo "启动Nginx Docker容器..."
docker run -d --name nginx-proxy -p 80:80 -p 443:443 \
    -v /home/dc/nginx/conf.d:/etc/nginx/conf.d \
    -v /home/dc/nginx/ssl:/etc/nginx/ssl \
    -v /home/dc/nginx/www:/usr/share/nginx/html \
    nginx

# 等待Nginx启动
sleep 5

# 使用Certbot申请SSL证书
echo "使用Certbot为 $yuming 生成SSL证书..."
sudo certbot certonly --webroot -w /home/dc/nginx/www -d $yuming -d www.$yuming --agree-tos --email your-email@example.com --non-interactive --deploy-hook "docker exec nginx-proxy nginx -s reload"

# 证书路径更新
sudo cp /etc/letsencrypt/live/$yuming/fullchain.pem /home/dc/nginx/ssl/fullchain.pem
sudo cp /etc/letsencrypt/live/$yuming/privkey.pem /home/dc/nginx/ssl/privkey.pem

# 重启Nginx容器以加载新证书
docker restart nginx-proxy

# 清理屏幕
clear
echo "您的反向代理网站已经设置完毕！"
echo "您可以通过 http://$yuming 或 https://$yuming 访问该站点。"