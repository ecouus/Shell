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


check_ports() {
    local ports=("$@")  # 接受一个数组参数，包含所有要检查的端口
    local port_errors=""

    for port in "${ports[@]}"; do
        if ss -ltn | grep -q ":$port "; then
            port_errors+="$port端口已被占用 "
        fi
    done

    if [ ! -z "$port_errors" ]; then
        echo "$port_errors 安装失败"
        return 1  # 返回1表示有端口被占用
    fi

    return 0  # 返回0表示所有端口都未被占用
}


iptables_open() {
    # 允许指定端口的流量通过
    ports="$port"
    iptables -A INPUT -p tcp --dport "$ports" -j ACCEPT
    iptables -A OUTPUT -p tcp --sport "$ports" -j ACCEPT
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

eco() {
    e
}

sudo apt install wget unzip -y


# 用户选择
while true; do
    clear
    echo "███████╗ ██████╗ ██████╗ "
    echo "██╔════╝██╔════╝██╔═══██╗"
    echo "█████╗  ██║     ██║   ██║"
    echo "██╔══╝  ██║     ██║   ██║"
    echo "███████╗╚██████╗╚██████╔╝"
    echo "╚══════╝ ╚═════╝ ╚═════╝ "
     
    echo -e "\033[92mAuthor：Rational\033[0m"
    echo -e "\033[92mBlog：https://ecouu.com\033[0m"
    echo "输入e即可召唤此脚本"
    echo "------------------------"

    echo -e "\033[38;5;208m菜单栏 \033[0m"
    echo "------------------------"
    echo "1.Docker百宝箱     2.工具箱 "
    echo "3.Nginx配置        4.系统安全 "
    echo " "
    echo "0.退出脚本         88.更新脚本"
    read -p "请输入你的选择：" choice
        case $choice in
            1)   
                while true; do
                clear
                echo -e "\033[92mDocker百宝箱\033[0m"
                echo "1.Nginx Proxy Manager          2.memos     "
                echo "3.PersonalPage                 4.homepage    "
                echo "5.sun-panel                    6.兰空图床"
                echo "7.Filecodebox                  8.Wallos  "
                echo "9.Linkding                     10.Alist    "
                echo "11.Vocechat                    12.ChatGPT-Next-Web    "
                echo "13.Trilium                   "           
                echo " "  
                echo "99.单独安装Docker"  
                echo "0.返回主菜单   "
                read -p "请输入你的选择：" choice
                    case $choice in
                        99)
                            install_docker
                            ;;
                        1)
                            while true; do
                            clear
                                echo -e "\033[38;5;208m'Nginx Proxy Manager' \033[0m"
                                echo "请确保未安装nginx或已停止nginx后再进行安装 并释放80和443端口"
                                echo "1.安装   2.卸载   3.更新"                   
                                echo "0.返回主菜单"
                                read -p "请输入你的选择：" user_choice
                                name=npm
                                port=81
                                case $user_choice in
                                    1)                           
                                        install_docker
                                        iptables_open
                                        # 初始化端口占用信息变量
                                        ports_to_check=(80 443)
                                        # 使用函数检查定义的端口数组
                                        if ! check_ports "${ports_to_check[@]}"; then
                                            exit 1  # 如果检查失败则退出
                                        else
                                            echo "端口未被占用，可以继续执行"
                                        fi

                                        container_exists=$(docker ps -a --format '{{.Names}}' | grep -w "npm-app-1")
                                        if [ "$container_exists" = "npm-app-1" ]; then
                                            echo "npm-app-1容器已存在"
                                        else
            
                                            curl https://raw.githubusercontent.com/ecouus/Shell/main/dockeryml/daemon.json -o /etc/docker/daemon.json
                                            sudo systemctl reload docker
                                            mkdir -p /home/dc/$name
                                            curl https://raw.githubusercontent.com/ecouus/Shell/main/dockeryml/npm.yml -o /home/dc/$name/docker-compose.yml
                                            cd /home/dc/$name  # 来到 docker-compose 文件所在的文件夹下
                                            docker-compose up -d
                                        fi

                                        clear
                                        check_ip_address
                                        echo "Nginx Proxy Manager已搭建 "
                                        echo "http://$ip_address:81"
                                        echo "默认账号：admin@example.com"
                                        echo "默认密码：changeme"
                                        echo " "
                                        echo "脚本运行完毕"
                                        # 提示用户按任意键继续
                                        read -n 1 -s -r -p "按任意键返回"
                                        echo  # 添加一个新行作为输出的一部分
                                        ;;   
                                    2)
                                        # 提示用户输入
                                        echo "是否删除宿主机挂载卷 /home/dc/$name? (y/n)"
                                        read answer
                                        # 根据用户输入决定操作
                                        case $answer in
                                        y)
                                            echo "Deleting..."
                                            docker stop npm-app-1
                                            docker rm npm-app-1
                                            rm -rf /home/dc/$name
                                            echo "Deleted."
                                            ;;
                                        n)
                                            echo "Deleting..."  
                                            docker stop npm-app-1
                                            docker rm npm-app-1
                                            echo "Docker项目已删除 挂载卷保留."
                                            ;;
                                        *)
                                            echo "Invalid input. Please enter 'y' for yes or 'n' for no."
                                            ;;
                                        esac
                                        read -n 1 -s -r -p "按任意键返回"
                                        echo  # 添加一个新行作为输出的一部分
                                        ;;
                                    3)
                                        cd /home/dc/$name
                                        docker-compose pull
                                        docker-compose up -d
                                        docker image prune
                                        ;;
                                    0)
                                        eco
                                        exit
                                        ;;   
                                    *)
                                        echo "无效输入"
                                        sleep 1
                                        ;;              
                                esac
                            done
                            ;;
                        2)
                            while true; do
                                clear
                                echo -e "\033[38;5;208m'Memos' \033[0m"
                                echo "1.安装   2.卸载"                   
                                echo "0.返回主菜单"
                                read -p "请输入你的选择：" user_choice
                                name=memos
                                port=5230
                                case $user_choice in
                                    1)
                                        install_docker
                                        iptables_open                     
                                        # 检查名为memos的容器是否存在
                                        container_exists=$(docker ps -a --format '{{.Names}}' | grep -w "$name")
                                        if [ "$container_exists" = "$name" ]; then
                                            echo "已安装"
                                        else
                                            
                                            # 初始化端口占用信息变量
                                            ports_to_check=$port
                                            # 使用函数检查定义的端口数组
                                            if ! check_ports "${ports_to_check[@]}"; then
                                                exit 1  # 如果检查失败则退出
                                            else
                                                echo "端口未被占用，可以继续执行"
                                            fi
                                            docker pull neosmemo/memos:latest
                                            docker run -d --restart=always -p $port:5230 \
                                            -v /home/dc/$name:/var/opt/memos \
                                            --name $name \
                                            neosmemo/memos:latest
                                        fi

                                        clear
                                        check_ip_address
                                        echo "$name已搭建 "
                                        echo "http://$ip_address:$port"
                                        echo " "
                                        echo "脚本运行完毕"
                                        # 提示用户按任意键继续
                                        read -n 1 -s -r -p "按任意键返回"
                                        echo  # 添加一个新行作为输出的一部分
                                        ;;                   
                                    2)
                                        # 提示用户输入
                                        echo "是否删除宿主机挂载卷 /home/dc/$name? (y/n)"
                                        read answer
                                        # 根据用户输入决定操作
                                        case $answer in
                                        y)
                                            echo "Deleting..."
                                            docker stop $name
                                            docker rm $name
                                            rm -rf /home/dc/$name
                                            echo "Deleted."
                                            ;;
                                        n)
                                            echo "Deleting..."  
                                            docker stop $name
                                            docker rm $name
                                            echo "Docker项目已删除 挂载卷保留."
                                            ;;
                                        *)
                                            echo "Invalid input. Please enter 'y' for yes or 'n' for no."
                                            ;;
                                        esac
                                        read -n 1 -s -r -p "按任意键返回"
                                        echo  # 添加一个新行作为输出的一部分
                                        ;;
                                    0)
                                        eco
                                        exit
                                        ;;   
                                    *)
                                        echo "无效输入"
                                        sleep 1
                                        ;;
                                esac
                            done
                            ;;   
                        3)
                            while true; do
                                clear
                                echo -e "\033[38;5;208m'PersonalPage' \033[0m"
                                echo "源码：https://github.com/DoWake/PersonalPage"
                                echo "------------------------"
                                echo "菜单栏："
                                echo "------------------------"
                                echo "1.安装项目     2.删除项目"
                                echo "0.返回主菜单"
                                read -p "请输入你的选择：" user_choice
                                name=PersonalPage
                                port=8899
                                case $user_choice in
                                    1)
                                        install_docker
                                        iptables_open

                                        # 检查名为PersonalPage的容器是否存在
                                        container_exists=$(docker ps -a --format '{{.Names}}' | grep -w "$name")
                                        if [ "$container_exists" = "$name" ]; then
                                            echo "已安装"
                                        else
                                            DIR="/home/dc/$name"
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
                                            ZIP_FILE="${DIR}/$name.zip"

                                            # 下载zip文件
                                            echo "Downloading the zip file from $ZIP_URL..."
                                            wget -O "$ZIP_FILE" "$ZIP_URL"

                                            # 解压zip文件
                                            echo "Unzipping the file..."
                                            unzip -o "$ZIP_FILE" -d "$DIR"

                                            EXTRACTED_DIR="${DIR}/$name-main"
                                            if [ -d "$EXTRACTED_DIR" ]; then
                                                mv -v "$EXTRACTED_DIR"/* "$DIR/"
                                                rmdir "$EXTRACTED_DIR"
                                            fi

                                            # 删除zip文件
                                            echo "Removing the zip file..."
                                            rm -f "$ZIP_FILE"
                                            echo "Setup completed."
                                            
                                            # 初始化端口占用信息变量
                                            ports_to_check=$port
                                            # 使用函数检查定义的端口数组
                                            if ! check_ports "${ports_to_check[@]}"; then
                                                exit 1  # 如果检查失败则退出
                                            else
                                                echo "端口未被占用，可以继续执行"
                                            fi

                                            # 运行Docker容器
                                            docker run -d \
                                                -p $port:80 \
                                                --name $name \
                                                -v /home/dc/$name/:/usr/share/nginx/html \
                                                nginx:alpine

                                            docker exec $name nginx -t
                                            docker exec $name nginx -s reload
                                        fi
                                    
                                        clear
                                        check_ip_address
                                        echo "$name已搭建 "
                                        echo "http://$ip_address:$port"
                                        echo " "
                                        echo "html路径为/home/dc/$name/"
                                        echo "请自行配置html"
                                        echo " "
                                        # 提示用户按任意键继续
                                        read -n 1 -s -r -p "按任意键返回"
                                        echo  # 添加一个新行作为输出的一部分
                                        ;;
                                    2)
                                        # 提示用户输入
                                        echo "是否删除宿主机挂载卷 /home/dc/$name? (y/n)"
                                        read answer
                                        # 根据用户输入决定操作
                                        case $answer in
                                        y)
                                            echo "Deleting..."
                                            docker stop $name
                                            docker rm $name
                                            rm -rf /home/dc/$name
                                            echo "Deleted."
                                            ;;
                                        n)
                                            echo "Deleting..."  
                                            docker stop $name
                                            docker rm $name
                                            echo "Docker项目已删除 挂载卷保留."
                                            ;;
                                        *)
                                            echo "Invalid input. Please enter 'y' for yes or 'n' for no."
                                            ;;
                                        esac
                                        read -n 1 -s -r -p "按任意键返回"
                                        echo  # 添加一个新行作为输出的一部分
                                        ;;
                                    0)
                                        eco
                                        exit
                                        ;;
                                    *)
                                        echo "无效输入"
                                        sleep 1
                                        ;; 
                                esac           
                            done
                            ;;  
                        4)
                            while true; do
                                clear
                                echo -e "\033[38;5;208m'homepage' \033[0m"
                                echo "源码：https://github.com/ZYYO666/homepage/archive/refs/heads/main.zip"
                                echo "------------------------"
                                echo "菜单栏："
                                echo "------------------------"
                                echo "1.安装项目     2.删除项目"
                                echo "0.返回主菜单"
                                read -p "请输入你的选择：" user_choice
                                name=homepage
                                port=6292
                                case $user_choice in
                                    1)
                                        install_docker
                                        iptables_open
                                        
                                        # 检查名为homepage的容器是否存在
                                        container_exists=$(docker ps -a --format '{{.Names}}' | grep -w "$name")
                                        if [ "$container_exists" = "$name" ]; then
                                            echo "已安装"
                                        else
                                            DIR="/home/dc/$name"
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
                                            ZIP_URL="https://github.com/ZYYO666/homepage/archive/refs/heads/main.zip"
                                            ZIP_FILE="${DIR}/$name.zip"

                                            # 下载zip文件
                                            echo "Downloading the zip file from $ZIP_URL..."
                                            wget -O "$ZIP_FILE" "$ZIP_URL"

                                            # 解压zip文件
                                            echo "Unzipping the file..."
                                            unzip -o "$ZIP_FILE" -d "$DIR"

                                            EXTRACTED_DIR="${DIR}/$name-main"
                                            if [ -d "$EXTRACTED_DIR" ]; then
                                                mv -v "$EXTRACTED_DIR"/* "$DIR/"
                                                rmdir "$EXTRACTED_DIR"
                                            fi

                                            # 删除zip文件
                                            echo "Removing the zip file..."
                                            rm -f "$ZIP_FILE"
                                            echo "Setup completed."
                                            
                                            # 初始化端口占用信息变量
                                            ports_to_check=$port
                                            # 使用函数检查定义的端口数组
                                            if ! check_ports "${ports_to_check[@]}"; then
                                                exit 1  # 如果检查失败则退出
                                            else
                                                echo "端口未被占用，可以继续执行"
                                            fi

                                            # 运行Docker容器
                                            docker run -d \
                                                -p $port:80 \
                                                --name $name \
                                                -v /home/dc/$name/:/usr/share/nginx/html \
                                                nginx:alpine

                                            docker exec $name nginx -t
                                            docker exec $name nginx -s reload
                                        fi      

                                        clear
                                        check_ip_address
                                        echo "$name已搭建 "
                                        echo "http://$ip_address:$port"
                                        echo " "
                                        echo "html路径为/home/dc/$name/"
                                        echo "请自行配置html"
                                        echo " "
                                        # 提示用户按任意键继续
                                        read -n 1 -s -r -p "按任意键返回"
                                        echo  # 添加一个新行作为输出的一部分
                                        ;;
                                    2)
                                        # 提示用户输入
                                        echo "是否删除宿主机挂载卷 /home/dc/$name? (y/n)"
                                        read answer
                                        # 根据用户输入决定操作
                                        case $answer in
                                        y)
                                            echo "Deleting..."
                                            docker stop $name
                                            docker rm $name
                                            rm -rf /home/dc/$name
                                            echo "Deleted."
                                            ;;
                                        n)
                                            echo "Deleting..."  
                                            docker stop $name
                                            docker rm $name
                                            echo "Docker项目已删除 挂载卷保留."
                                            ;;
                                        *)
                                            echo "Invalid input. Please enter 'y' for yes or 'n' for no."
                                            ;;
                                        esac
                                        read -n 1 -s -r -p "按任意键返回"
                                        echo  # 添加一个新行作为输出的一部分
                                        ;;
                                    0)
                                        eco
                                        exit
                                        ;;
                                    *)
                                        echo "无效输入"
                                        sleep 1
                                        ;; 
                                esac           
                            done
                            ;;    
                        5)
                            while true; do
                            clear
                                echo -e "\033[38;5;208m'sun-panel' \033[0m"
                                echo "源码：https://github.com/hslr-s/sun-panel"
                                echo "------------------------"
                                echo "菜单栏："
                                echo "------------------------"
                                echo "1.安装项目     2.删除项目"
                                echo "0.返回主菜单"
                                read -p "请输入你的选择：" user_choice
                                name=sun-panel
                                port=3002
                                case $user_choice in
                                    1)
                                        install_docker
                                        iptables_open                     
                                        # 检查名为sun-panel的容器是否存在
                                        container_exists=$(docker ps -a --format '{{.Names}}' | grep -w "$name")
                                        if [ "$container_exists" = "$name" ]; then
                                            echo "已安装"
                                        else
                                            
                                            # 初始化端口占用信息变量
                                            ports_to_check=$port
                                            # 使用函数检查定义的端口数组
                                            if ! check_ports "${ports_to_check[@]}"; then
                                                exit 1  # 如果检查失败则退出
                                            else
                                                echo "端口未被占用，可以继续执行"
                                            fi

                                            docker pull hslr/sun-panel
                                            docker run -d --restart=always -p $port:3002 \
                                            -v /home/dc/$name/conf:/app/conf \
                                            -v /home/dc/$name/uploads:/app/uploads \
                                            -v /home/dc/$name/database:/app/database \
                                            --name $name \
                                            hslr/sun-panel
                                        fi

                                        clear
                                        check_ip_address
                                        echo "$name已搭建 "
                                        echo "http://$ip_address:$port"
                                        echo "默认账号：admin@sun.cc"
                                        echo "默认密码：12345678"
                                        echo " "
                                        echo "脚本运行完毕"
                                        # 提示用户按任意键继续
                                        read -n 1 -s -r -p "按任意键返回"
                                        echo  # 添加一个新行作为输出的一部分
                                        ;;                   
                                    2)
                                        # 提示用户输入
                                        echo "是否删除宿主机挂载卷 /home/dc/$name? (y/n)"
                                        read answer
                                        # 根据用户输入决定操作
                                        case $answer in
                                        y)
                                            echo "Deleting..."
                                            docker stop $name
                                            docker rm $name
                                            rm -rf /home/dc/$name
                                            echo "Deleted."
                                            ;;
                                        n)
                                            echo "Deleting..."  
                                            docker stop $name
                                            docker rm $name
                                            echo "Docker项目已删除 挂载卷保留."
                                            ;;
                                        *)
                                            echo "Invalid input. Please enter 'y' for yes or 'n' for no."
                                            ;;
                                        esac
                                        read -n 1 -s -r -p "按任意键返回"
                                        echo  # 添加一个新行作为输出的一部分
                                        ;;
                                    0)
                                        eco
                                        exit
                                        ;;   
                                    *)
                                        echo "无效输入"
                                        sleep 1
                                        ;;
                                esac
                            done
                            ;;            
                        6)
                            while true; do
                            clear
                                echo -e "\033[38;5;208m'兰空图床lsky-pro' \033[0m"
                                echo "1.安装   2.卸载   3.更新"                   
                                echo "0.返回主菜单"
                                read -p "请输入你的选择：" user_choice
                                port=7791
                                case $user_choice in
                                    1)                           
                                        install_docker
                                        iptables_open
                                        # 初始化端口占用信息变量
                                        ports_to_check=7791
                                        # 使用函数检查定义的端口数组
                                        if ! check_ports "${ports_to_check[@]}"; then
                                            exit 1  # 如果检查失败则退出
                                        else
                                            echo "端口未被占用，可以继续执行"
                                        fi

                                        container_exists=$(docker ps -a --format '{{.Names}}' | grep -w "lsky-pro")
                                        if [ "$container_exists" = "lsky-pro" ]; then
                                            echo "lsky-pro容器已存在"
                                        else

                                            mkdir -p /home/dc/lsky-pro
                                            curl https://raw.githubusercontent.com/ecouus/Shell/main/dockeryml/lsky-pro.yml -o /home/dc/lsky-pro/docker-compose.yml
                                            cd /home/dc/lsky-pro   # 来到 docker-compose 文件所在的文件夹下
                                            docker-compose up -d
                                        fi

                                        clear
                                        check_ip_address
                                        echo "Nginx Proxy Manager已搭建 "
                                        echo "http://$ip_address:$port"
                                        echo "数据库地址：lsky-pro-db"
                                        echo "数据库链接端口留空"
                                        echo "数据库名称/路径、数据库用户名、密码：lsky-pro"
                                        echo " "
                                        echo "脚本运行完毕"
                                        # 提示用户按任意键继续
                                        read -n 1 -s -r -p "按任意键返回"
                                        echo  # 添加一个新行作为输出的一部分
                                        ;;   
                                    2)
                                        # 提示用户输入
                                        echo "是否删除宿主机挂载卷 /home/dc/$name? (y/n)"
                                        read answer
                                        # 根据用户输入决定操作
                                        case $answer in
                                        y)
                                            echo "Deleting..."
                                            docker stop $name
                                            docker rm $name
                                            rm -rf /home/dc/$name
                                            echo "Deleted."
                                            ;;
                                        n)
                                            echo "Deleting..."  
                                            docker stop $name
                                            docker rm $name
                                            echo "Docker项目已删除 挂载卷保留."
                                            ;;
                                        *)
                                            echo "Invalid input. Please enter 'y' for yes or 'n' for no."
                                            ;;
                                        esac
                                        read -n 1 -s -r -p "按任意键返回"
                                        echo  # 添加一个新行作为输出的一部分
                                        ;;
                                    3)
                                        cd /home/dc/lsky-pro
                                        docker-compose pull
                                        docker-compose up -d
                                        docker image prune
                                        ;;
                                    0)
                                        eco
                                        exit
                                        ;;   
                                    *)
                                        echo "无效输入"
                                        sleep 1
                                        ;;              
                                esac
                            done
                            ;;
                        7)
                            while true; do
                            clear
                                echo -e "\033[38;5;208m'文件快递柜Filecodebox' \033[0m"
                                echo "1.安装   2.卸载   3.更新"                   
                                echo "0.返回主菜单"
                                read -p "请输入你的选择：" user_choice
                                name=filecodebox
                                port=8060
                                case $user_choice in
                                    1)                           
                                        install_docker
                                        iptables_open
                                        # 初始化端口占用信息变量
                                        ports_to_check=8060
                                        # 使用函数检查定义的端口数组
                                        if ! check_ports "${ports_to_check[@]}"; then
                                            exit 1  # 如果检查失败则退出
                                        else
                                            echo "端口未被占用，可以继续执行"
                                        fi

                                        container_exists=$(docker ps -a --format '{{.Names}}' | grep -w "filecodebox")
                                        if [ "$container_exists" = "filecodebox" ]; then
                                            echo "filecodebox容器已存在"
                                        else

                                            mkdir -p /home/dc/filecodebox
                                            curl https://raw.githubusercontent.com/ecouus/Shell/main/dockeryml/filecodebox.yml -o /home/dc/filecodebox/docker-compose.yml
                                            cd /home/dc/filecodebox   # 来到 docker-compose 文件所在的文件夹下
                                            docker-compose up -d
                                        fi

                                        clear
                                        check_ip_address
                                        echo "文件快递柜已搭建 "
                                        echo "http://$ip_address:$port"
                                        echo "后台：http://$ip_address:$port/#/admin"
                                        echo "后台默认密码：FileCodeBox2023"
                                        echo " "
                                        echo "脚本运行完毕"
                                        # 提示用户按任意键继续
                                        read -n 1 -s -r -p "按任意键返回"
                                        echo  # 添加一个新行作为输出的一部分
                                        ;;   
                                    2)
                                        # 提示用户输入
                                        echo "是否删除宿主机挂载卷 /home/dc/$name? (y/n)"
                                        read answer
                                        # 根据用户输入决定操作
                                        case $answer in
                                        y)
                                            echo "Deleting..."
                                            docker stop $name
                                            docker rm $name
                                            rm -rf /home/dc/$name
                                            echo "Deleted."
                                            ;;
                                        n)
                                            echo "Deleting..."  
                                            docker stop $name
                                            docker rm $name
                                            echo "Docker项目已删除 挂载卷保留."
                                            ;;
                                        *)
                                            echo "Invalid input. Please enter 'y' for yes or 'n' for no."
                                            ;;
                                        esac
                                        read -n 1 -s -r -p "按任意键返回"
                                        echo  # 添加一个新行作为输出的一部分
                                        ;;
                                    3)
                                        cd /home/dc/filecodebox
                                        docker-compose pull
                                        docker-compose up -d
                                        docker image prune
                                        ;;
                                    0)
                                        eco
                                        exit
                                        ;;   
                                    *)
                                        echo "无效输入"
                                        sleep 1
                                        ;;              
                                esac
                            done
                            ;;
                        8)
                            while true; do
                            clear
                                echo -e "\033[38;5;208m'订阅管理系统Wallos' \033[0m"
                                echo "源码：https://github.com/ellite/Wallos"
                                echo "------------------------"
                                echo "菜单栏："
                                echo "------------------------"
                                echo "1.安装项目     2.删除项目"
                                echo "0.返回主菜单"
                                read -p "请输入你的选择：" user_choice
                                name=wallos
                                port=8282
                                case $user_choice in
                                    1)
                                        install_docker
                                        iptables_open                     
                                        # 检查名为sun-panel的容器是否存在
                                        container_exists=$(docker ps -a --format '{{.Names}}' | grep -w "$name")
                                        if [ "$container_exists" = "$name" ]; then
                                            echo "已安装"
                                        else
                                            
                                            # 初始化端口占用信息变量
                                            ports_to_check=$port
                                            # 使用函数检查定义的端口数组
                                            if ! check_ports "${ports_to_check[@]}"; then
                                                exit 1  # 如果检查失败则退出
                                            else
                                                echo "端口未被占用，可以继续执行"
                                            fi
                                            
                                        docker pull bellamy/wallos:latest
                                        docker run -d --name wallos \
                                        -v /home/dc/wallos/db:/var/www/html/db \
                                        -v /home/dc/wallos/logos:/var/www/html/images/uploads/logos \
                                        -e TZ=Europe/Berlin -p 8282:80 --restart unless-stopped \
                                        bellamy/wallos:latest

                                        fi

                                        clear
                                        check_ip_address
                                        echo "$name已搭建 "
                                        echo "http://$ip_address:$port"
                                        echo " "
                                        echo "脚本运行完毕"
                                        # 提示用户按任意键继续
                                        read -n 1 -s -r -p "按任意键返回"
                                        echo  # 添加一个新行作为输出的一部分
                                        ;;                   
                                    2)
                                        # 提示用户输入
                                        echo "是否删除宿主机挂载卷 /home/dc/$name? (y/n)"
                                        read answer
                                        # 根据用户输入决定操作
                                        case $answer in
                                        y)
                                            echo "Deleting..."
                                            docker stop $name
                                            docker rm $name
                                            rm -rf /home/dc/$name
                                            echo "Deleted."
                                            ;;
                                        n)
                                            echo "Deleting..."  
                                            docker stop $name
                                            docker rm $name
                                            echo "Docker项目已删除 挂载卷保留."
                                            ;;
                                        *)
                                            echo "Invalid input. Please enter 'y' for yes or 'n' for no."
                                            ;;
                                        esac
                                        read -n 1 -s -r -p "按任意键返回"
                                        echo  # 添加一个新行作为输出的一部分
                                        ;;
                                    0)
                                        eco
                                        exit
                                        ;;   
                                    *)
                                        echo "无效输入"
                                        sleep 1
                                        ;;
                                esac
                            done
                            ;;
                        9)
                            while true; do
                            clear
                                echo -e "\033[38;5;208m'标签管理Linkding' \033[0m"
                                echo "源码：https://github.com/sissbruecker/linkding"
                                echo "------------------------"
                                echo "菜单栏："
                                echo "------------------------"
                                echo "1.安装项目     2.删除项目     3.迁移项目"
                                echo "0.返回主菜单"
                                read -p "请输入你的选择：" user_choice
                                name=linkding
                                case $user_choice in
                                    1)
                                        read -p "请输入可用端口：" port
                                        install_docker
                                        iptables_open                     
                                        # 检查名为sun-panel的容器是否存在
                                        container_exists=$(docker ps -a --format '{{.Names}}' | grep -w "$name")
                                        if [ "$container_exists" = "$name" ]; then
                                            echo "已安装"
                                        else
                                            
                                            # 初始化端口占用信息变量
                                            ports_to_check=$port
                                            # 使用函数检查定义的端口数组
                                            if ! check_ports "${ports_to_check[@]}"; then
                                                exit 1  # 如果检查失败则退出
                                            else
                                                echo "端口未被占用，可以继续执行"
                                            fi
                                        read -p $'\033[0;32m请输入域名(确保已反代至本机IP:'"$port"$'):\033[0m ' domain
                                        full_domain="https://$domain"
                                        read -p $'\033[0;32m请输入面板用户名:\033[0m' username
                                        read -p $'\033[0;32m请输入面板邮箱:\033[0m' email
                                        docker pull sissbruecker/linkding:latest-plus
                                        docker run -d --name linkding -p $port:9090 \
                                        -v /home/dc/linkding:/etc/linkding/data -d -e LD_CSRF_TRUSTED_ORIGINS="$full_domain" \
                                        sissbruecker/linkding:latest-plus    
                                        sleep 5
                                        docker exec -it linkding python manage.py createsuperuser --username="$username" --email="$email"
                                        
                                        fi

                                        clear
                                        check_ip_address
                                        echo "$name已搭建 "
                                        echo "$full_domain"
                                        echo " "
                                        echo "脚本运行完毕"
                                        # 提示用户按任意键继续
                                        read -n 1 -s -r -p "按任意键返回"
                                        echo  # 添加一个新行作为输出的一部分
                                        ;;                   
                                    2)
                                        # 提示用户输入
                                        echo "是否删除宿主机挂载卷 /home/dc/$name? (y/n)"
                                        read answer
                                        # 根据用户输入决定操作
                                        case $answer in
                                        y)
                                            echo "Deleting..."
                                            docker stop $name
                                            docker rm $name
                                            rm -rf /home/dc/$name
                                            echo "Deleted."
                                            ;;
                                        n)
                                            echo "Deleting..."  
                                            docker stop $name
                                            docker rm $name
                                            echo "Docker项目已删除 挂载卷保留."
                                            ;;
                                        *)
                                            echo "Invalid input. Please enter 'y' for yes or 'n' for no."
                                            ;;
                                        esac
                                        read -n 1 -s -r -p "按任意键返回"
                                        echo  # 添加一个新行作为输出的一部分
                                        ;;
                                    3)
                                        install_docker
                                        iptables_open                     
                                        # 检查名为sun-panel的容器是否存在
                                        container_exists=$(docker ps -a --format '{{.Names}}' | grep -w "$name")
                                        if [ "$container_exists" = "$name" ]; then
                                            echo "已安装"
                                        else
                                            
                                            # 初始化端口占用信息变量
                                            ports_to_check=$port
                                            # 使用函数检查定义的端口数组
                                            if ! check_ports "${ports_to_check[@]}"; then
                                                exit 1  # 如果检查失败则退出
                                            else
                                                echo "端口未被占用，可以继续执行"
                                            fi
                                        docker pull sissbruecker/linkding:latest-plus
                                        docker run --name linkding -p $port:9090 \
                                        -v /home/dc/linkding:/etc/linkding/data -d -e LD_CSRF_TRUSTED_ORIGINS="$full_domain" \
                                        sissbruecker/linkding:latest-plus    
                                        
                                        fi

                                        clear
                                        check_ip_address
                                        echo "$name已迁移成功 "
                                        echo " "
                                        echo "脚本运行完毕"
                                        # 提示用户按任意键继续
                                        read -n 1 -s -r -p "按任意键返回"
                                        echo  # 添加一个新行作为输出的一部分
                                        ;;     
                                    0)
                                        eco
                                        exit
                                        ;;   
                                    *)
                                        echo "无效输入"
                                        sleep 1
                                        ;;
                                esac
                            done
                            ;;
                        10)
                            while true; do
                            clear
                                echo -e "\033[38;5;208m'多存储文件列表程序Alist' \033[0m"
                                echo "源码：https://github.com/alist-org/alist"
                                echo "------------------------"
                                echo "菜单栏："
                                echo "------------------------"
                                echo "1.安装项目     2.删除项目"
                                echo "0.返回主菜单"
                                read -p "请输入你的选择：" user_choice
                                name=alist
                                port=5244
                                case $user_choice in
                                    1)
                                        install_docker
                                        iptables_open                     
                                        # 检查名为sun-panel的容器是否存在
                                        container_exists=$(docker ps -a --format '{{.Names}}' | grep -w "$name")
                                        if [ "$container_exists" = "$name" ]; then
                                            echo "已安装"
                                        else
                                            
                                            # 初始化端口占用信息变量
                                            ports_to_check=$port
                                            # 使用函数检查定义的端口数组
                                            if ! check_ports "${ports_to_check[@]}"; then
                                                exit 1  # 如果检查失败则退出
                                            else
                                                echo "端口未被占用，可以继续执行"
                                            fi

                                        docker pull xhofe/alist:latest
                                        docker run -d --name alist\
                                        --restart=always \
                                        -v /home/dc/alist:/opt/alist/data \
                                        -v /home/dc/alist/file:/opt/alist/data/file \
                                        -p 5244:5244 \
                                        -e PUID=0 \
                                        -e PGID=0 \
                                        -e UMASK=022 \
                                        xhofe/alist:latest

                                        fi

                                        clear
                                        check_ip_address
                                        echo "$name已搭建 "
                                        echo "http://$ip_address:$port"
                                        docker exec -it alist ./alist admin random
                                        echo " "
                                        echo "本地存储挂载路径（无需使用此项的可忽略）：-v /home/dc/alist/file:/opt/alist/data/file "
                                        echo "脚本运行完毕"
                                        # 提示用户按任意键继续
                                        read -n 1 -s -r -p "按任意键返回"
                                        echo  # 添加一个新行作为输出的一部分
                                        ;;                   
                                    2)
                                        # 提示用户输入
                                        echo "是否删除宿主机挂载卷 /home/dc/$name? (y/n)"
                                        read answer
                                        # 根据用户输入决定操作
                                        case $answer in
                                        y)
                                            echo "Deleting..."
                                            docker stop $name
                                            docker rm $name
                                            rm -rf /home/dc/$name
                                            echo "Deleted."
                                            ;;
                                        n)
                                            echo "Deleting..."  
                                            docker stop $name
                                            docker rm $name
                                            echo "Docker项目已删除 挂载卷保留."
                                            ;;
                                        *)
                                            echo "Invalid input. Please enter 'y' for yes or 'n' for no."
                                            ;;
                                        esac
                                        read -n 1 -s -r -p "按任意键返回"
                                        echo  # 添加一个新行作为输出的一部分
                                        ;;
                                    0)
                                        eco
                                        exit
                                        ;;   
                                    *)
                                        echo "无效输入"
                                        sleep 1
                                        ;;
                                esac
                            done
                            ;;
                        11)
                            while true; do
                            clear
                                echo -e "\033[38;5;208m'私人聊天室Vocechat' \033[0m"
                                echo "源码：https://github.com/Privoce/vocechat-web"
                                echo "------------------------"
                                echo "菜单栏："
                                echo "------------------------"
                                echo "1.安装项目     2.删除项目"
                                echo "0.返回主菜单"
                                read -p "请输入你的选择：" user_choice
                                name=vocechat-server
                                port=3009
                                case $user_choice in
                                    1)
                                        install_docker
                                        iptables_open                     
                                        # 检查名为sun-panel的容器是否存在
                                        container_exists=$(docker ps -a --format '{{.Names}}' | grep -w "$name")
                                        if [ "$container_exists" = "$name" ]; then
                                            echo "已安装"
                                        else
                                            
                                            # 初始化端口占用信息变量
                                            ports_to_check=$port
                                            # 使用函数检查定义的端口数组
                                            if ! check_ports "${ports_to_check[@]}"; then
                                                exit 1  # 如果检查失败则退出
                                            else
                                                echo "端口未被占用，可以继续执行"
                                            fi

                                        read -p $'\033[0;32m请输入域名(确保已反代至本机IP:3009):\033[0m' domain
                                        full_domain="https://$domain"
                                        docker pull privoce/vocechat-server:latest
                                        docker run -d --restart=always \
                                        -p 3009:3000 \
                                        --name vocechat-server \
                                        -v /home/dc/vocechat-server/data:/home/vocechat-server/data \
                                        -e NETWORK__FRONTEND_URL="$full_domain" \
                                        privoce/vocechat-server:latest

                                        fi

                                        clear
                                        check_ip_address
                                        echo "$name已搭建 "
                                        echo "http://$ip_address:$port"
                                        echo " "
                                        echo "脚本运行完毕"
                                        # 提示用户按任意键继续
                                        read -n 1 -s -r -p "按任意键返回"
                                        echo  # 添加一个新行作为输出的一部分
                                        ;;                   
                                    2)
                                        # 提示用户输入
                                        echo "是否删除宿主机挂载卷 /home/dc/$name? (y/n)"
                                        read answer
                                        # 根据用户输入决定操作
                                        case $answer in
                                        y)
                                            echo "Deleting..."
                                            docker stop $name
                                            docker rm $name
                                            rm -rf /home/dc/$name
                                            echo "Deleted."
                                            ;;
                                        n)
                                            echo "Deleting..."  
                                            docker stop $name
                                            docker rm $name
                                            echo "Docker项目已删除 挂载卷保留."
                                            ;;
                                        *)
                                            echo "Invalid input. Please enter 'y' for yes or 'n' for no."
                                            ;;
                                        esac
                                        read -n 1 -s -r -p "按任意键返回"
                                        echo  # 添加一个新行作为输出的一部分
                                        ;;
                                    0)
                                        eco
                                        exit
                                        ;;   
                                    *)
                                        echo "无效输入"
                                        sleep 1
                                        ;;
                                esac
                            done
                            ;;
                        12)
                            while true; do
                            clear
                                echo -e "\033[38;5;208m'ChatGPT-Next-Web' \033[0m"
                                echo "源码：https://github.com/ChatGPTNextWeb/ChatGPT-Next-Web"
                                echo "------------------------"
                                echo "菜单栏："
                                echo "------------------------"
                                echo "1.安装项目     2.删除项目"
                                echo "0.返回主菜单"
                                read -p "请输入你的选择：" user_choice
                                name=ChatGPT-Next-Web
                                port=6600
                                case $user_choice in
                                    1)
                                        install_docker
                                        iptables_open                     
                                        # 检查名为sun-panel的容器是否存在
                                        container_exists=$(docker ps -a --format '{{.Names}}' | grep -w "$name")
                                        if [ "$container_exists" = "$name" ]; then
                                            echo "已安装"
                                        else
                                            
                                            # 初始化端口占用信息变量
                                            ports_to_check=$port
                                            # 使用函数检查定义的端口数组
                                            if ! check_ports "${ports_to_check[@]}"; then
                                                exit 1  # 如果检查失败则退出
                                            else
                                                echo "端口未被占用，可以继续执行"
                                            fi

                                        read -p "请输入OpenAI API Key: " OPENAI_API_KEY
                                        read -p "请输入访问密码Code: " CODE
                                        read -p "请输入接口地址Base URL（留空则默认调用官方接口）: " BASE_URL
                                        read -p "请输入默认模型 (按回车默认gpt-4o): " DEFAULT_MODEL
                                        DEFAULT_MODEL=${DEFAULT_MODEL:-gpt-4o}

                                        docker pull yidadaa/chatgpt-next-web
                                        if [ -z "$BASE_URL" ]
                                        then
                                            docker run -d --restart=always \
                                            -p 6600:3000 \
                                            --name ChatGPT-Next-Web \
                                            -e OPENAI_API_KEY=$OPENAI_API_KEY \
                                            -e CODE=$CODE \
                                            -e DEFAULT_MODEL=$DEFAULT_MODEL \
                                            yidadaa/chatgpt-next-web
                                        else
                                            docker run -d --restart=always \
                                            -p 6600:3000 \
                                            --name ChatGPT-Next-Web \
                                            -e OPENAI_API_KEY=$OPENAI_API_KEY \
                                            -e CODE=$CODE \
                                            -e BASE_URL=$BASE_URL \
                                            yidadaa/chatgpt-next-web
                                        fi


                                        fi

                                        clear
                                        check_ip_address
                                        echo "$name已搭建 "
                                        echo "http://$ip_address:$port"
                                        echo " "
                                        echo "脚本运行完毕"
                                        # 提示用户按任意键继续
                                        read -n 1 -s -r -p "按任意键返回"
                                        echo  # 添加一个新行作为输出的一部分
                                        ;;                   
                                    2)
                                        # 提示用户输入
                                        echo "是否删除宿主机挂载卷 /home/dc/$name? (y/n)"
                                        read answer
                                        # 根据用户输入决定操作
                                        case $answer in
                                        y)
                                            echo "Deleting..."
                                            docker stop $name
                                            docker rm $name
                                            rm -rf /home/dc/$name
                                            echo "Deleted."
                                            ;;
                                        n)
                                            echo "Deleting..."  
                                            docker stop $name
                                            docker rm $name
                                            echo "Docker项目已删除 挂载卷保留."
                                            ;;
                                        *)
                                            echo "Invalid input. Please enter 'y' for yes or 'n' for no."
                                            ;;
                                        esac
                                        read -n 1 -s -r -p "按任意键返回"
                                        echo  # 添加一个新行作为输出的一部分
                                        ;;
                                    0)
                                        eco
                                        exit
                                        ;;   
                                    *)
                                        echo "无效输入"
                                        sleep 1
                                        ;;
                                esac
                            done
                            ;;
                        13)
                            while true; do
                            clear
                                echo -e "\033[38;5;208m'笔记Trilium' \033[0m"
                                echo "源码：https://github.com/zadam/trilium"
                                echo "------------------------"
                                echo "菜单栏："
                                echo "------------------------"
                                echo "1.安装项目     2.删除项目"
                                echo "0.返回主菜单"
                                read -p "请输入你的选择：" user_choice
                                name=trilium
                                port=8080
                                case $user_choice in
                                    1)
                                        install_docker
                                        iptables_open                     
                                        # 检查名为sun-panel的容器是否存在
                                        container_exists=$(docker ps -a --format '{{.Names}}' | grep -w "$name")
                                        if [ "$container_exists" = "$name" ]; then
                                            echo "已安装"
                                        else
                                            
                                            # 初始化端口占用信息变量
                                            ports_to_check=$port
                                            # 使用函数检查定义的端口数组
                                            if ! check_ports "${ports_to_check[@]}"; then
                                                exit 1  # 如果检查失败则退出
                                            else
                                                echo "端口未被占用，可以继续执行"
                                            fi

                                        docker pull nriver/trilium-cn
                                        docker run -d --restart=always \
                                        -p 8080:8080 \
                                        --name trilium \
                                        -v /home/dc/trilium/trilium-data:/root/trilium-data \
                                        -e TRILIUM_DATA_DIR=/root/trilium-data \
                                        --restart always \
                                        nriver/trilium-cn

                                        fi

                                        clear
                                        check_ip_address
                                        echo "$name已搭建 "
                                        echo "http://$ip_address:$port"
                                        echo " "
                                        echo "脚本运行完毕"
                                        # 提示用户按任意键继续
                                        read -n 1 -s -r -p "按任意键返回"
                                        echo  # 添加一个新行作为输出的一部分
                                        ;;                   
                                    2)
                                        # 提示用户输入
                                        echo "是否删除宿主机挂载卷 /home/dc/$name? (y/n)"
                                        read answer
                                        # 根据用户输入决定操作
                                        case $answer in
                                        y)
                                            echo "Deleting..."
                                            docker stop $name
                                            docker rm $name
                                            rm -rf /home/dc/$name
                                            echo "Deleted."
                                            ;;
                                        n)
                                            echo "Deleting..."  
                                            docker stop $name
                                            docker rm $name
                                            echo "Docker项目已删除 挂载卷保留."
                                            ;;
                                        *)
                                            echo "Invalid input. Please enter 'y' for yes or 'n' for no."
                                            ;;
                                        esac
                                        read -n 1 -s -r -p "按任意键返回"
                                        echo  # 添加一个新行作为输出的一部分
                                        ;;
                                    0)
                                        eco
                                        exit
                                        ;;   
                                    *)
                                        echo "无效输入"
                                        sleep 1
                                        ;;
                                esac
                            done
                            ;;
                        模版)
                            while true; do
                            clear
                                echo -e "\033[38;5;208m'项目名称' \033[0m"
                                echo "源码：https://项目地址"
                                echo "------------------------"
                                echo "菜单栏："
                                echo "------------------------"
                                echo "1.安装项目     2.删除项目"
                                echo "0.返回主菜单"
                                read -p "请输入你的选择：" user_choice
                                name=名字！
                                port=端口！
                                case $user_choice in
                                    1)
                                        install_docker
                                        iptables_open                     
                                        # 检查名为sun-panel的容器是否存在
                                        container_exists=$(docker ps -a --format '{{.Names}}' | grep -w "$name")
                                        if [ "$container_exists" = "$name" ]; then
                                            echo "已安装"
                                        else
                                            
                                            # 初始化端口占用信息变量
                                            ports_to_check=$port
                                            # 使用函数检查定义的端口数组
                                            if ! check_ports "${ports_to_check[@]}"; then
                                                exit 1  # 如果检查失败则退出
                                            else
                                                echo "端口未被占用，可以继续执行"
                                            fi

                                        docker pull 镜像名！
                                        docker run 命令！

                                        fi

                                        clear
                                        check_ip_address
                                        echo "$name已搭建 "
                                        echo "http://$ip_address:$port"
                                        echo " "
                                        echo "脚本运行完毕"
                                        # 提示用户按任意键继续
                                        read -n 1 -s -r -p "按任意键返回"
                                        echo  # 添加一个新行作为输出的一部分
                                        ;;                   
                                    2)
                                        # 提示用户输入
                                        echo "是否删除宿主机挂载卷 /home/dc/$name? (y/n)"
                                        read answer
                                        # 根据用户输入决定操作
                                        case $answer in
                                        y)
                                            echo "Deleting..."
                                            docker stop $name
                                            docker rm $name
                                            rm -rf /home/dc/$name
                                            echo "Deleted."
                                            ;;
                                        n)
                                            echo "Deleting..."  
                                            docker stop $name
                                            docker rm $name
                                            echo "Docker项目已删除 挂载卷保留."
                                            ;;
                                        *)
                                            echo "Invalid input. Please enter 'y' for yes or 'n' for no."
                                            ;;
                                        esac
                                        read -n 1 -s -r -p "按任意键返回"
                                        echo  # 添加一个新行作为输出的一部分
                                        ;;
                                    0)
                                        eco
                                        exit
                                        ;;   
                                    *)
                                        echo "无效输入"
                                        sleep 1
                                        ;;
                                esac
                            done
                            ;;
                        0)  
                            eco
                            clear
                            exit
                            ;;
                        *)
                            echo "无效输入"
                            sleep 1                         
                            ;;
                    esac 
                done
                ;;
            2)  
                while true; do
                clear
                echo "此页面脚本均收集自网络 请此行甄别"
                echo "1.Kejilion                 2.IPQuality(xykt)"
                echo "3.可视化路由查询(sjlleo)    4.极光面板       "
                echo "5.融合怪                    6.IPV6管理 "  
                echo "7.地区IP屏蔽                8.nftables工具    "  
                echo "0.返回主菜单   "
                read -p "请输入你的选择：" choice
                    case $choice in          
                        1)
                            bash <(curl -sL kejilion.sh)
                            ;;  
                        2)
                            bash <(curl -sL IP.Check.Place)
                            ;;  
                        3)
                            bash <(curl -Ls https://raw.githubusercontent.com/sjlleo/nexttrace/main/nt_install.sh)
                            ;; 
                        4)
                            bash <(curl -fsSL https://raw.githubusercontent.com/Aurora-Admin-Panel/deploy/main/install.sh)
                            ;; 
                        5)
                            bash <(wget -qO- ecs.0s.hk)
                            ;; 
                        6)
                            bash <(curl -fsSL https://raw.githubusercontent.com/ecouus/Shell/refs/heads/main/ipv6_manager.sh)
                            ;; 
                        7)
                            bash <(curl -fsSL https://raw.githubusercontent.com/ecouus/Shell/refs/heads/main/BlockIP/block-ip.sh)
                            ;; 
                        8)
                            bash <(curl -fsSL https://raw.githubusercontent.com/ecouus/Shell/refs/heads/main/nftool.sh)
                            ;; 
                        0)  
                            eco
                            clear
                            exit
                            ;;   
                        *)
                            echo "无效输入"
                            sleep 1                         
                            ;;
                    esac
                    read -n 1 -s -r -p "按任意键返回"
                    echo  # 添加一个新行作为输出的一部分
                done
                ;;
            3)                  
                clear
                curl -sS -O https://raw.githubusercontent.com/ecouus/Shell/refs/heads/main/nginx.sh && sudo chmod +x nginx.sh && sudo ./nginx.sh
                ;;
            4)                  
                clear
                curl -sS -O https://raw.githubusercontent.com/ecouus/Shell/refs/heads/main/system_manager.sh && sudo chmod +x system_manager.sh && sudo ./system_manager.sh
                ;;
            0)                  
                clear
                exit
                ;;
            88)
                renew
                ;;
            *)
                echo "无效输入"
                sleep 1
                ;;

        esac
done
