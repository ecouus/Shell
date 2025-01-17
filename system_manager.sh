#!/bin/bash

# 颜色变量
GREEN="\033[32m"
RED="\033[31m"
YELLOW="\033[33m"
RESET="\033[0m"

# 主菜单函数
show_main_menu() {
    clear
    echo -e "${GREEN}=== 系统管理工具 ===${RESET}"
    echo "1. 更改 SSH 端口"
    echo "2. Fail2Ban 管理"
    echo "3. Bark 通知管理"
    echo "4. 退出"
    echo -n "请选择操作 [1-4]: "
}

# SSH端口修改函数
change_ssh_port() {
    echo -n "请输入新的 SSH 端口号: "
    read new_port
    
    if [[ ! "$new_port" =~ ^[0-9]+$ ]] || [ "$new_port" -lt 1 ] || [ "$new_port" -gt 65535 ]; then
        echo -e "${RED}无效的端口号！${RESET}"
        return 1
    fi
    
    # 修改 SSH 配置
    sed -i "s/^#Port 22/Port $new_port/" /etc/ssh/sshd_config
    sed -i "s/^Port [0-9]*/Port $new_port/" /etc/ssh/sshd_config
    
    # 检测防火墙工具并配置规则
    if command -v ufw > /dev/null; then
        echo "检测到 UFW，正在配置防火墙规则..."
        ufw allow $new_port/tcp
        ufw enable
        echo "UFW 配置完成。"
    elif command -v firewall-cmd > /dev/null; then
        echo "检测到 firewalld，正在配置防火墙规则..."
        firewall-cmd --zone=public --add-port=$new_port/tcp --permanent
        firewall-cmd --reload
        echo "firewalld 配置完成。"
    elif command -v iptables > /dev/null; then
        echo "检测到 iptables，正在配置防火墙规则..."
        iptables -A INPUT -p tcp --dport $new_port -j ACCEPT
        iptables-save > /etc/iptables/rules.v4
        echo "iptables 配置完成。"
    elif command -v nft > /dev/null; then
        echo "检测到 nftables，正在配置防火墙规则..."
        nft add rule ip filter input tcp dport $new_port accept
        nft list ruleset > /etc/nftables.conf
        echo "nftables 配置完成。"
    else
        echo "未检测到已知的防火墙工具，请手动配置防火墙规则以放行端口 $new_port。"
        exit 1
    fi

    # 输出完成提示
    echo "防火墙规则已更新，端口 $new_port 已放行。"
    # 重启 SSH 服务
    systemctl restart sshd
    
    echo -e "${YELLOW}警告: 不要关闭当前连接！请新开终端测试新端口连接：${RESET}"
    echo -e "使用命令: ${GREEN}ssh user@ip -p $new_port${RESET}"
    echo -e "确认能成功连接后再关闭此会话！"
}

# Fail2Ban 管理菜单
fail2ban_menu() {
    while true; do
        clear
        echo -e "${GREEN}=== Fail2Ban 管理 ===${RESET}"
        echo "1. 安装 Fail2Ban"
        echo "2. 卸载 Fail2Ban"
        echo "3. 返回主菜单"
        echo -n "请选择操作 [1-3]: "
        read choice
        
        case $choice in
            1)
                # 安装 Fail2Ban
                apt update && apt upgrade -y
                apt install fail2ban rsyslog -y
                
                systemctl enable --now fail2ban
                systemctl enable --now rsyslog
                
                # 提示用户输入 SSH 端口号，默认为 ssh
                echo -e "${YELLOW}请输入要保护的 SSH 端口号（默认为 'ssh'）：${RESET}"
                read -p "SSH 端口号: " ssh_port
                ssh_port=${ssh_port:-ssh} # 如果用户未输入，使用默认值 'ssh'
                
                # 创建默认配置
                cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
# 白名单设置（请修改为你的IP）
ignoreip = 127.0.0.1/8 ::1

[sshd]
enabled = true
port = $ssh_port
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
findtime = 600
EOF
                
                systemctl restart fail2ban
                
                echo -e "${GREEN}Fail2Ban 安装完成！${RESET}"
                echo -e "${YELLOW}当前保护的 SSH 端口号为: ${GREEN}$ssh_port${RESET}"
                echo -e "${YELLOW}请使用以下命令编辑配置文件，设置白名单IP及其他参数：${RESET}"
                echo -e "${GREEN}nano /etc/fail2ban/jail.local${RESET}"
                echo -e "${YELLOW}编辑完成后输入以下命令重启 Fail2Ban:${RESET}"
                echo -e "${GREEN}sudo systemctl restart fail2ban${RESET}"
                read -p "按回车键继续..."
                ;;
            2)
                # 卸载 Fail2Ban
                systemctl stop fail2ban
                systemctl disable fail2ban
                apt remove --purge fail2ban -y
                rm -rf /etc/fail2ban
                echo -e "${GREEN}Fail2Ban 已卸载！${RESET}"
                read -p "按回车键继续..."
                ;;
            3)
                return
                ;;
            *)
                echo -e "${RED}无效的选择！${RESET}"
                read -p "按回车键继续..."
                ;;
        esac
    done
}


# Bark通知管理菜单
bark_menu() {
    while true; do
        clear
        echo -e "${GREEN}=== Bark 通知管理 ===${RESET}"
        echo -e "${YELLOW}使用此功能前请先安装fail2ban${RESET}"
        echo "1. 安装 Bark 通知"
        echo "2. 卸载 Bark 通知"
        echo "3. 返回主菜单"
        echo -n "请选择操作 [1-3]: "
        read choice
        
        case $choice in
            1)
                echo -e "${GREEN}开始安装 SSH 登录通知服务...${RESET}"
                
                # 获取用户输入
                echo -n "请输入Bark服务器地址(例如: https://api.day.app): "
                read bark_url
                echo -n "请输入Bark Token: "
                read bark_token
                echo -n "请输入服务器名称: "
                read server_name
                
                # 创建目录和脚本文件
                mkdir -p /root/ecouu/
                cat > /root/ecouu/ssh_notify.sh << EOF
#!/bin/bash
BARK_URL="$bark_url/push"
DEVICE_KEY="$bark_token"
SERVER_NAME="$server_name"
icon_url="https://i.miji.bid/2025/01/17/6f93b0af0524337c5fc67cff8a1d8a4c.png"

tail -Fn0 /var/log/auth.log | while read line ; do
    if echo "\$line" | grep -q "Accepted \(password\|publickey\) for"; then
        user=\$(echo "\$line" | grep -o "for [^ ]* from" | sed 's/for \(.*\) from/\1/')
        ip=\$(echo "\$line" | grep -o "from [0-9.]*" | cut -d' ' -f2)
        port=\$(echo "\$line" | grep -o "port [0-9]*" | cut -d' ' -f2)
        auth_type=\$(echo "\$line" | grep -o "Accepted [^ ]*" | cut -d' ' -f2)
        
        if [ ! -z "\$user" ] && [ ! -z "\$ip" ] && [ ! -z "\$port" ]; then
            message="服务器：\${SERVER_NAME}\\n用户: \${user}\\nIP地址: \${ip}\\n端口: \${port}\\n认证方式: \${auth_type}\\n时间: \$(date '+%Y-%m-%d %H:%M:%S')"
            json_data="{\"title\":\"SSH登录提醒\",\"device_key\":\"\$DEVICE_KEY\",\"body\":\"\$message\",\"group\":\"ssh_login\",\"icon\":\"\$icon_url\"}"
            curl -s -X POST "\$BARK_URL" \\
                -H "Content-Type: application/json" \\
                -d "\$json_data" > /dev/null
        fi
    fi
done
EOF

                # 创建服务文件
                cat > /etc/systemd/system/ssh-notify.service << 'EOF'
[Unit]
Description=SSH Login Notify
After=network.target

[Service]
Type=simple
ExecStart=/root/ecouu/ssh_notify.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOF

                chmod +x /root/ecouu/ssh_notify.sh
                systemctl daemon-reload
                systemctl enable ssh-notify
                systemctl start ssh-notify
                
                echo -e "${GREEN}Bark 通知服务安装完成！${RESET}"
                read -p "按回车键继续..."
                ;;
            2)
                systemctl stop ssh-notify
                systemctl disable ssh-notify
                rm -f /etc/systemd/system/ssh-notify.service
                rm -rf /root/ecouu
                systemctl daemon-reload
                echo -e "${GREEN}Bark 通知服务已卸载！${RESET}"
                read -p "按回车键继续..."
                ;;
            3)
                return
                ;;
            *)
                echo -e "${RED}无效的选择！${RESET}"
                read -p "按回车键继续..."
                ;;
        esac
    done
}

# 主程序循环
while true; do
    show_main_menu
    read choice
    
    case $choice in
        1)
            change_ssh_port
            read -p "按回车键继续..."
            ;;
        2)
            fail2ban_menu
            ;;
        3)
            bark_menu
            ;;
        4)
            echo -e "${GREEN}感谢使用，再见！${RESET}"
            exit 0
            ;;
        *)
            echo -e "${RED}无效的选择！${RESET}"
            read -p "按回车键继续..."
            ;;
    esac
done
