#!/bin/bash
#安装weget curl依赖包
#yum update -y && yum install curl -y #CentOS/Fedora
#apt-get update -y && apt-get install curl -y #Debian/Ubuntu
#远程下载代码curl -sS -O https://raw.githubusercontent.com/ecouus/Shell/main/pswb.sh && sudo chmod +x pswb.sh && ./pswb.sh


ip_address() {
ipv4_address=$(curl -s ipv4.ip.sb)
ipv6_address=$(curl -s --max-time 1 ipv6.ip.sb)
}

iptables_open() {
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -F

    ip6tables -P INPUT ACCEPT
    ip6tables -P FORWARD ACCEPT
    ip6tables -P OUTPUT ACCEPT
    ip6tables -F

}

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
iptables_open

# 用户选择
clear
echo -e "\033[38;5;208m  ___  ___  __\033[0m"
echo -e "\033[38;5;208m |___ |    |  | \033[0m"
echo -e "\033[38;5;208m |___ |___ |__| \033[0m"
echo -e "\033[38;5;208m 脚本作者：Rantional \033[0m"
echo -e "\033[38;5;208m 博客：https://ecouu.com \033[0m"
echo -e "\033[38;5;208m Github：https://github.com/ecouus \033[0m"
echo " "
echo "个人主页搭建"
echo "源码：https://github.com/DoWake/PersonalPage"
echo "------------------------"
echo "菜单栏："
echo "------------------------"
echo "1.安装项目     2.更新项目（删除并重新部署）     3.删除项目"
read -p "请输入你的选择：" user_choice

case $user_choice in
    1)
        DIR="/home/dc/PersonalWeb"
        # 检查目录是否存在
        if [ -d "$DIR" ]; then
            echo "Directory $DIR already exists."
        else
            echo "Creating directory $DIR."
            mkdir -p "$DIR"
        fi

        # 导航到目录
        cd "$DIR"

        # 定义GitHub仓库zip文件的URL
        ZIP_URL="https://github.com/ecouus/PersonalPage/archive/refs/heads/main.zip"
        ZIP_FILE="${DIR}/PersonalWeb.zip"

        # 下载zip文件
        echo "Downloading the zip file from $ZIP_URL..."
        wget -O "$ZIP_FILE" "$ZIP_URL"

        # 解压zip文件
        echo "Unzipping the file..."
        unzip -o "$ZIP_FILE" -d "$DIR"

        EXTRACTED_DIR="${DIR}/PersonalPage-main"
        if [ -d "$EXTRACTED_DIR" ]; then
            mv -v "$EXTRACTED_DIR"/* "$DIR/"
            rmdir "$EXTRACTED_DIR"
        fi

        # 删除zip文件
        echo "Removing the zip file..."
        rm -f "$ZIP_FILE"
        echo "Setup completed."

        # 运行Docker容器
        docker run -d \
            -p 8899:80 \
            --name pswb \
            -v /home/dc/PersonalWeb/nginx/pswb.conf:/etc/nginx/pswb.conf \
            -v /home/dc/PersonalWeb/:/usr/share/nginx/html \
            nginx:alpine

        docker exec pswb nginx -t
        docker exec pswb nginx -s reload

        clear

        ip_address
        echo "个人网页搭建好咯~ "
        echo "http://$ipv4_address:8899"
        echo " "
        echo "html和nginx路径均为/home/dc/PersonalWeb/"
        echo "自行更改html文件及nginx配置文件哦~"
        echo " "
        ;;
    2)
        echo "停止并删除pswb容器..."
        docker stop pswb
        docker rm pswb
        rm -rf /home/dc/PersonalWeb
                DIR="/home/dc/PersonalWeb"
        # 检查目录是否存在
        if [ -d "$DIR" ]; then
            echo "Directory $DIR already exists."
        else
            echo "Creating directory $DIR."
            mkdir -p "$DIR"
        fi

        # 导航到目录
        cd "$DIR"

        # 定义GitHub仓库zip文件的URL
        ZIP_URL="https://github.com/ecouus/PersonalPage/archive/refs/heads/main.zip"
        ZIP_FILE="${DIR}/PersonalWeb.zip"

        # 下载zip文件
        echo "Downloading the zip file from $ZIP_URL..."
        wget -O "$ZIP_FILE" "$ZIP_URL"

        # 解压zip文件
        echo "Unzipping the file..."
        unzip -o "$ZIP_FILE" -d "$DIR"

        EXTRACTED_DIR="${DIR}/PersonalPage-main"
        if [ -d "$EXTRACTED_DIR" ]; then
            mv -v "$EXTRACTED_DIR"/* "$DIR/"
            rmdir "$EXTRACTED_DIR"
        fi

        # 删除zip文件
        echo "Removing the zip file..."
        rm -f "$ZIP_FILE"
        echo "Setup completed."

        # 运行Docker容器
        docker run -d \
            -p 8899:80 \
            --name pswb \
            -v /home/dc/PersonalWeb/nginx/pswb.conf:/etc/nginx/pswb.conf \
            -v /home/dc/PersonalWeb/:/usr/share/nginx/html \
            nginx:alpine

        docker exec pswb nginx -t
        docker exec pswb nginx -s reload

        clear

        ip_address
        echo "个人网页搭建好咯~ "
        echo "http://$ipv4_address:8899"
        echo " "
        echo "html和nginx路径均为/home/dc/PersonalWeb/"
        echo "自行更改html文件及nginx配置文件哦~"
        echo " "
        ;;
    3)
        echo "停止并删除pswb容器..."
        docker stop pswb
        docker rm pswb
        rm -rf /home/dc/PersonalWeb
        ;;
    *)
        echo "继续执行脚本..."
        ;;
esac


echo "脚本运行完毕"
# 提示用户按任意键继续
read -n 1 -s -r -p "按任意键退出"
echo ""

# 提示用户脚本执行完毕
echo "现在已返回到/root目录"


