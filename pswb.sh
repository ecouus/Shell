#!/bin/bash
#安装weget curl依赖包
#yum update -y && yum install curl -y #CentOS/Fedora
#apt-get update -y && apt-get install curl -y #Debian/Ubuntu
#远程下载代码curl -sS -O https://raw.githubusercontent.com/ecouus/Shell/main/pswb.sh && sudo chmod +x pswb.sh && ./pswb.sh

install_docker() {
    if ! command -v docker &>/dev/null; then
        if [ -f "/etc/alpine-release" ]; then
            apk update && apk add docker docker-compose
            rc-update add docker default && service docker start
        else
            curl -fsSL https://get.docker.com | sh
            if ! command -v docker-compose &>/dev/null; then
                curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
                chmod +x /usr/local/bin/docker-compose
            fi
            systemctl start docker && systemctl enable docker
        fi
    else
        echo "Docker 已经安装."
    fi
}



sudo apt install wget unzip -y
install_docker

DIR="/home/dc/website"
# Check if the directory exists
if [ -d "$DIR" ]; then
    echo "Directory $DIR already exists."
else
    echo "Creating directory $DIR."
    mkdir -p "$DIR"
fi

# Navigate to the directory
cd "$DIR"

# Define the URL of the GitHub repository zip file
ZIP_URL="https://github.com/ecouus/PersonalPage/archive/refs/heads/main.zip"
ZIP_FILE="${DIR}/website.zip"

# Download the zip file
echo "Downloading the zip file from $ZIP_URL..."
wget -O "$ZIP_FILE" "$ZIP_URL"

# Unzip the contents of the zip file
echo "Unzipping the file..."
unzip -o "$ZIP_FILE" -d "$DIR"

EXTRACTED_DIR="${DIR}/PersonalPage-main"
if [ -d "$EXTRACTED_DIR" ]; then
    mv -v "$EXTRACTED_DIR"/* "$DIR/"
    rmdir "$EXTRACTED_DIR"
fi

# Remove the zip file
echo "Removing the zip file..."
rm -f "$ZIP_FILE"
echo "Setup completed."




docker run -d \
    -p 8899:80 \
    --name pswb \
    -v /home/dc/website/nginx/pswb.conf:/etc/nginx/pswb.conf \
    -v /home/dc/website/:/usr/share/nginx/html \
    nginx:alpine

docker exec pswb nginx -t
docker exec pswb nginx -s reload

ip_address=$(hostname -I | cut -d' ' -f1)

# 输出完成的提示信息
echo "个人网页搭建好咯~ 通过http://${ip_address}:8899访问"
