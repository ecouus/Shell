#!/bin/bash
#安装weget curl依赖包
#yum update -y && yum install curl -y #CentOS/Fedora
#apt-get update -y && apt-get install curl -y #Debian/Ubuntu
#远程下载代码curl -sS -O https://raw.githubusercontent.com/ecouus/Shell/main/ecouu.sh && sudo chmod +x ecouu.sh && ./ecouu.sh
ln -sf ~/ecouu.sh /usr/local/bin/e

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

renew(){
    curl -sS -O https://raw.githubusercontent.com/ecouus/Shell/main/ecouu.sh && sudo chmod +x ecouu.sh && ./ecouu.sh
}


sudo apt install wget unzip -y


# 用户选择
clear
while true; do
    echo -e "\033[38;5;208m ___  ___  __\033[0m"
    echo -e "\033[38;5;208m|___ |    |  | \033[0m"
    echo -e "\033[38;5;208m|___ |___ |__| \033[0m"
    echo -e "\033[38;5;208mBy Rational \033[0m"
    echo -e "\033[38;5;208mBlog：https://ecouu.com \033[0m"
    echo " "

    echo "菜单栏："
    echo "------------------------"
    echo "1.个人主页     2.导航站     3.Nginx Proxy Manager"
    echo "9.更新脚本"
    read -p "请输入你的选择：" choice
        case $choice in
            1)
                while true; do
                    clear
                    echo -e "\033[38;5;208m个人主页搭建\033[0m"
                    echo "源码：https://github.com/DoWake/PersonalPage"
                    echo "------------------------"
                    echo "菜单栏："
                    echo "------------------------"
                    echo "1.安装项目     2.删除项目"
                    echo "0.返回主菜单"
                    read -p "请输入你的选择：" user_choice

                    case $user_choice in
                        1)
                            install_docker
                            iptables_open
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
                            ZIP_URL="https://github.com/DoWake/PersonalPage/archive/refs/heads/main.zip"
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
                            port=8899
                            # 运行Docker容器
                            docker run -d \
                                -p $port:80 \
                                --name pswb \
                                -v /home/dc/PersonalWeb/:/usr/share/nginx/html \
                                nginx:alpine

                            docker exec pswb nginx -t
                            docker exec pswb nginx -s reload

                            clear

                            check_ip_address
                            echo "个人网页已搭建 "
                            echo "http://$ip_address:$port"
                            echo " "
                            echo "html路径为/home/dc/PersonalWeb/"
                            echo "请自行配置html"
                            echo " "
                            # 提示用户按任意键继续
                            read -n 1 -s -r -p "按任意键退出脚本"
                            echo  # 添加一个新行作为输出的一部分
                            exit 0  # 退出脚本
                            ;;
                        2)
                            echo "停止并删除pswb容器..."
                            docker stop pswb
                            docker rm pswb
                            rm -rf /home/dc/PersonalWeb
                            echo "已彻底删除"
                            read -n 1 -s -r -p "按任意键返回"
                            echo  # 添加一个新行作为输出的一部分
                            ;;
                        0)
                            e
                            exit
                            ;;
                        *)
                            echo "无效输入"
                            ;; 
                    esac           
                done
                ;;  
            2)
                while true; do
                clear
                    echo -e "\033[38;5;208m导航站搭建\033[0m"
                    echo "源码：https://github.com/hslr-s/sun-panel"
                    echo "------------------------"
                    echo "菜单栏："
                    echo "------------------------"
                    echo "1.安装项目     3.删除项目"
                    echo "0.返回主菜单"
                    read -p "请输入你的选择：" user_choice

                    case $user_choice in
                        1)
                            install_docker
                            iptables_open
                            # 检查名为sun-panel的容器是否存在
                            container_exists=$(docker ps -a --format '{{.Names}}' | grep -w "sun-panel")
                            if [ "$container_exists" = "sun-panel" ]; then
                                echo "已安装"
                            else
                                port=3002
                                docker pull hslr/sun-panel
                                docker run -d --restart=always -p $port:3002 \
                                -v /home/dc/sun-panel/conf:/app/conf \
                                -v /home/dc/sun-panel/uploads:/app/uploads \
                                -v /home/dc/sun-panel/database:/app/database \
                                --name sun-panel \
                                hslr/sun-panel
                            fi
                            check_ip_address
                            echo "导航站已搭建 "
                            echo "http://$ip_address:$port"
                            echo "默认账号：admin@sun.cc"
                            echo "默认密码：12345678"
                            echo " "
                            echo "脚本运行完毕"
                            # 提示用户按任意键继续
                            read -n 1 -s -r -p "按任意键退出脚本"
                            echo  # 添加一个新行作为输出的一部分
                            exit 0  # 退出脚本
                            ;;                   
                        2)
                            # 停止并删除名为sun-panel的容器
                            docker stop sun-panel
                            docker rm sun-panel
                            rm -rf /home/dc/sun-panel
                            echo "已彻底删除"
                            read -n 1 -s -r -p "按任意键返回"
                            echo  # 添加一个新行作为输出的一部分
                            ;;
                        0)
                            e
                            exit
                            ;;   
                        *)
                            echo "无效输入"
                            ;;
                    esac
                done
                ;;
            3)
                while true; do
                clear
                    echo -e "\033[38;5;208mNginx Proxy Manager\033[0m"
                    echo "请确保未安装nginx或已停止nginx后再进行安装 并释放80端口"
                    echo "1.安装   2.更新   3.卸载"                   
                    echo "0.返回主菜单"
                    read -p "请输入你的选择：" user_choice
                    case $user_choice in
                        1)
                            
                            install_docker
                            iptables_open
                            # 检查80端口是否被占用
                            if ss -ltn | grep -q ':80 '; then
                                echo "80端口已被占用，安装失败"
                                exit 1
                            else
                                container_exists=$(docker ps -a --format '{{.Names}}' | grep -w "npm-app-1")
                                if [ "$container_exists" = "npm-app-1" ]; then
                                    echo "已安装"
                                else
                                    port=81 
                                    curl https://raw.githubusercontent.com/ecouus/Shell/main/dockeryml/daemon.json -o /etc/docker/daemon.json
                                    sudo systemctl reload docker
                                    mkdir -p /home/dc/npm
                                    curl https://raw.githubusercontent.com/ecouus/Shell/main/dockeryml/npm.yml -o /home/dc/npm/docker-compose.yml
                                    cd /home/dc/npm   # 来到 docker-compose 文件所在的文件夹下
                                    docker-compose up -d
                                fi
                            fi
                            check_ip_address
                            echo "Nginx Proxy Manager已搭建 "
                            echo "http://$ip_address:$port"
                            echo "默认账号：admin@example.com"
                            echo "默认密码：changeme"
                            echo " "
                            echo "脚本运行完毕"
                            # 提示用户按任意键继续
                            read -n 1 -s -r -p "按任意键退出脚本"
                            echo  # 添加一个新行作为输出的一部分
                            exit 0  # 退出脚本
                            ;;
                        2)
                            cd /home/dc/npm
                            docker-compose down 
                            cp -r /home/dc/npm /home/dc/backups/npm.archive  # 备个份先
                            docker-compose pull
                            docker-compose up -d    # docker-compose up -d 直接升级容器时会自动停止并立刻重建新的容器，节省时间
                            docker image prune 
                            ;;
                        3)
                            # 停止并删除名为sun-panel的容器
                            cd /home/dc/npm
                            docker-compose down 
                            rm -rf /home/dc/npm
                            echo "已彻底删除"
                            read -n 1 -s -r -p "按任意键返回"
                            echo  # 添加一个新行作为输出的一部分
                            ;;

                        0)
                            e
                            exit
                            ;;   
                        *)
                            echo "无效输入"
                            ;;              
                    esac
                done
                ;;        
            0)
                clear
                exit
                ;;
            9)
                renew
                ;;
            *)
                echo "无效输入"
                ;;

        esac
done
