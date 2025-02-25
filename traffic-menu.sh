#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PLAIN='\033[0m'

# 基础配置
SCRIPT_DIR="/root/ecouu"
MONITOR_SCRIPT="$SCRIPT_DIR/traffic-monitor.sh"
CONFIG_FILE="$SCRIPT_DIR/config.ini"
TELEGRAM_CONFIG="$SCRIPT_DIR/telegram.conf"
GITHUB_URL="https://raw.githubusercontent.com/ecouus/Shell/refs/heads/main/traffic-monitor.sh"

# 检查root权限
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}错误: 此脚本需要root权限才能运行${PLAIN}"
        echo -e "${YELLOW}请使用 'sudo bash $0' 重新运行${PLAIN}"
        exit 1
    fi
}

# 安装依赖
install_dependencies() {
    echo -e "${BLUE}检查并安装必要的依赖...${PLAIN}"
    apt-get update -qq
    apt-get install -y curl bc jq nftables
    echo -e "${GREEN}依赖安装完成!${PLAIN}"
}

# 安装流量监控脚本
install_monitor() {
    echo -e "${BLUE}开始安装流量监控脚本...${PLAIN}"
    
    # 创建目录
    mkdir -p $SCRIPT_DIR/logs
    
    # 下载脚本
    echo -e "${YELLOW}正在下载流量监控脚本...${PLAIN}"
    curl -s -o $MONITOR_SCRIPT $GITHUB_URL
    
    # 设置权限
    chmod +x $MONITOR_SCRIPT
    
    # 创建链接
    ln -sf $MONITOR_SCRIPT /usr/local/bin/traffic-monitor
    
    # 初始化配置
    echo -e "${YELLOW}正在初始化配置文件...${PLAIN}"
    traffic-monitor > /dev/null
    
    # 设置监控规则
    echo -e "${YELLOW}正在设置监控规则...${PLAIN}"
    traffic-monitor setup > /dev/null
    
    # 保存规则
    echo -e "${YELLOW}正在保存nftables规则...${PLAIN}"
    nft list ruleset > /etc/nftables.conf 2>/dev/null
    systemctl enable nftables > /dev/null 2>&1
    
    echo -e "${GREEN}流量监控脚本安装完成!${PLAIN}"
}

# 检查是否已安装
check_installation() {
    if [ ! -f "$MONITOR_SCRIPT" ]; then
        echo -e "${YELLOW}未检测到流量监控脚本，准备安装...${PLAIN}"
        install_dependencies
        install_monitor
        echo -e "${GREEN}初始化完成!${PLAIN}"
    fi
}

# 显示所有端口流量状态
show_all_status() {
    clear
    echo -e "${CYAN}=============================${PLAIN}"
    echo -e "${CYAN}      所有端口流量状态      ${PLAIN}"
    echo -e "${CYAN}=============================${PLAIN}"
    echo
    
    traffic-monitor
    
    echo
    echo -e "${CYAN}=============================${PLAIN}"
    echo
    read -n 1 -s -r -p "按任意键继续..."
}

# 显示端口列表
show_port_list() {
    clear
    echo -e "${CYAN}=============================${PLAIN}"
    echo -e "${CYAN}      当前监控端口列表      ${PLAIN}"
    echo -e "${CYAN}=============================${PLAIN}"
    echo
    
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${YELLOW}配置文件不存在，请先初始化系统。${PLAIN}"
        return
    fi
    
    echo -e "${BLUE}端口\t限额(GB)\t开始日期\t用户名${PLAIN}"
    echo -e "${BLUE}----------------------------------------${PLAIN}"
    
    local count=0
    while IFS=: read -r port limit_gb start_date user_name || [[ -n "$port" ]]; do
        # 跳过注释和空行
        [[ $port =~ ^#.*$ || -z $port ]] && continue
        
        echo -e "${GREEN}$port\t$limit_gb\t\t$start_date\t$user_name${PLAIN}"
        ((count++))
    done < $CONFIG_FILE
    
    if [ $count -eq 0 ]; then
        echo -e "${YELLOW}没有找到已配置的端口监控。${PLAIN}"
    fi
    
    echo
    echo -e "${CYAN}=============================${PLAIN}"
    echo -e "共找到 ${GREEN}$count${PLAIN} 个监控端口"
    echo
}

# 添加端口监控
add_port_monitor() {
    clear
    echo -e "${CYAN}=============================${PLAIN}"
    echo -e "${CYAN}       添加新的端口监控       ${PLAIN}"
    echo -e "${CYAN}=============================${PLAIN}"
    echo
    
    # 获取端口
    local port=""
    while [[ ! $port =~ ^[0-9]+$ ]] || [ $port -lt 1 ] || [ $port -gt 65535 ]; do
        read -p "请输入端口号 (1-65535): " port
        if [[ ! $port =~ ^[0-9]+$ ]] || [ $port -lt 1 ] || [ $port -gt 65535 ]; then
            echo -e "${RED}无效的端口号，请输入1-65535之间的数字。${PLAIN}"
        fi
    done
    
    # 获取限额
    local limit=""
    while [[ ! $limit =~ ^[0-9]+$ ]]; do
        read -p "请输入流量限额 (GB)[输入9999999表示无限制]: " limit
        if [[ ! $limit =~ ^[0-9]+$ ]]; then
            echo -e "${RED}无效的限额，请输入数字。${PLAIN}"
        fi
    done
    
    # 获取用户名
    local user_name=""
    read -p "请输入用户名或服务标识: " user_name
    if [ -z "$user_name" ]; then
        user_name="端口${port}用户"
    fi
    
    # 添加监控
    echo
    echo -e "${YELLOW}正在添加端口 $port 的监控配置...${PLAIN}"
    traffic-monitor add $port $limit $(date +%Y-%m-%d) "$user_name"
    
    # 保存规则
    nft list ruleset > /etc/nftables.conf 2>/dev/null
    
    echo
    echo -e "${CYAN}=============================${PLAIN}"
    echo
    read -n 1 -s -r -p "按任意键继续..."
}

# 删除端口监控
delete_port_monitor() {
    clear
    echo -e "${CYAN}=============================${PLAIN}"
    echo -e "${CYAN}       删除端口监控配置       ${PLAIN}"
    echo -e "${CYAN}=============================${PLAIN}"
    echo
    
    # 显示当前端口
    show_port_list
    
    # 获取端口
    local port=""
    read -p "请输入要删除的端口号: " port
    
    # 确认删除
    read -p "确定要删除端口 $port 的监控配置吗? (y/n): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}操作已取消。${PLAIN}"
        echo
        echo -e "${CYAN}=============================${PLAIN}"
        read -n 1 -s -r -p "按任意键继续..."
        return
    fi
    
    # 删除监控
    echo
    echo -e "${YELLOW}正在删除端口 $port 的监控配置...${PLAIN}"
    traffic-monitor delete $port
    
    # 保存规则
    nft list ruleset > /etc/nftables.conf 2>/dev/null
    
    echo
    echo -e "${CYAN}=============================${PLAIN}"
    echo
    read -n 1 -s -r -p "按任意键继续..."
}

# 重置流量计数器
reset_counter() {
    clear
    echo -e "${CYAN}=============================${PLAIN}"
    echo -e "${CYAN}        重置流量计数器        ${PLAIN}"
    echo -e "${CYAN}=============================${PLAIN}"
    echo
    
    # 显示当前端口
    show_port_list
    
    echo -e "${YELLOW}选项:${PLAIN}"
    echo -e "${GREEN}1.${PLAIN} 重置特定端口的计数器"
    echo -e "${GREEN}2.${PLAIN} 重置所有端口的计数器"
    echo -e "${GREEN}0.${PLAIN} 返回主菜单"
    echo
    
    read -p "请选择 [0-2]: " option
    
    case $option in
        1)
            read -p "请输入要重置的端口号: " port
            echo
            echo -e "${YELLOW}正在重置端口 $port 的流量计数器...${PLAIN}"
            traffic-monitor reset $port
            ;;
        2)
            echo
            echo -e "${YELLOW}正在重置所有端口的流量计数器...${PLAIN}"
            traffic-monitor reset
            ;;
        0)
            return
            ;;
        *)
            echo -e "${RED}无效的选项!${PLAIN}"
            ;;
    esac
    
    echo
    echo -e "${CYAN}=============================${PLAIN}"
    echo
    read -n 1 -s -r -p "按任意键继续..."
}

# 设置Telegram通知
setup_telegram() {
    clear
    echo -e "${CYAN}=============================${PLAIN}"
    echo -e "${CYAN}      设置Telegram通知      ${PLAIN}"
    echo -e "${CYAN}=============================${PLAIN}"
    echo
    
    echo -e "${YELLOW}Telegram通知可以在流量使用接近限额时自动提醒您。${PLAIN}"
    echo -e "${YELLOW}您需要提供一个Telegram Bot Token和Chat ID。${PLAIN}"
    echo
    
    # 检查现有配置
    local current_bot_token=""
    local current_chat_id=""
    local current_threshold="90"
    
    if [ -f "$TELEGRAM_CONFIG" ]; then
        source "$TELEGRAM_CONFIG"
        current_bot_token=$BOT_TOKEN
        current_chat_id=$CHAT_ID
        current_threshold=${THRESHOLD:-90}
        
        echo -e "${GREEN}已检测到现有Telegram配置:${PLAIN}"
        echo -e "${GREEN}Bot Token: ${PLAIN}${current_bot_token:0:6}...${current_bot_token: -4}"
        echo -e "${GREEN}Chat ID: ${PLAIN}$current_chat_id"
        echo -e "${GREEN}警报阈值: ${PLAIN}${current_threshold}%"
        echo
    fi
    
    echo -e "${YELLOW}1.${PLAIN} 配置/修改Telegram通知"
    echo -e "${YELLOW}2.${PLAIN} 测试Telegram通知"
    echo -e "${YELLOW}3.${PLAIN} 禁用Telegram通知"
    echo -e "${YELLOW}0.${PLAIN} 返回主菜单"
    echo
    
    read -p "请选择 [0-3]: " option
    
    case $option in
        1)
            echo
            read -p "请输入Bot Token [直接回车保持不变]: " bot_token
            if [ -z "$bot_token" ]; then
                bot_token=$current_bot_token
            fi
            
            read -p "请输入Chat ID [直接回车保持不变]: " chat_id
            if [ -z "$chat_id" ]; then
                chat_id=$current_chat_id
            fi
            
            local threshold=""
            while [[ ! $threshold =~ ^[0-9]+$ ]] || [ $threshold -lt 1 ] || [ $threshold -gt 100 ]; do
                read -p "请输入警报阈值 (百分比，1-100) [直接回车默认90]: " threshold
                if [ -z "$threshold" ]; then
                    threshold=${current_threshold:-90}
                    break
                fi
                
                if [[ ! $threshold =~ ^[0-9]+$ ]] || [ $threshold -lt 1 ] || [ $threshold -gt 100 ]; then
                    echo -e "${RED}无效的阈值，请输入1-100之间的数字。${PLAIN}"
                fi
            done
            
            # 保存配置
            cat > $TELEGRAM_CONFIG << EOF
BOT_TOKEN="$bot_token"
CHAT_ID="$chat_id"
THRESHOLD="$threshold"
EOF
            
            # 创建警报脚本
            cat > $SCRIPT_DIR/traffic-alert.sh << 'EOF'
#!/bin/bash

# 配置文件
CONFIG_FILE="/root/ecouu/telegram.conf"
MONITOR_SCRIPT="/root/ecouu/traffic-monitor.sh"

# 加载配置
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "错误: 配置文件不存在"
    exit 1
fi

# 发送Telegram消息
send_telegram() {
    local message="$1"
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d chat_id="${CHAT_ID}" \
        -d text="${message}" \
        -d parse_mode="HTML" > /dev/null
}

# 检查流量状态
check_traffic() {
    local output=$($MONITOR_SCRIPT)
    local alerts=""
    local current_user=""
    local current_port=""
    
    # 解析输出，查找流量使用情况
    while IFS= read -r line; do
        # 提取用户名
        if [[ $line =~ \[监控\ (.*)\] ]]; then
            current_user="${BASH_REMATCH[1]}"
        fi
        
        # 提取端口号
        if [[ $line =~ 端口:\ ([0-9]+) ]]; then
            current_port="${BASH_REMATCH[1]}"
        fi
        
        # 提取流量使用情况
        if [[ $line =~ 流量使用:\ ([0-9.]+)GB\ /\ ([0-9.]+)GB\ \(([0-9.]+)%\) ]]; then
            local used="${BASH_REMATCH[1]}"
            local limit="${BASH_REMATCH[2]}"
            local percent="${BASH_REMATCH[3]}"
            
            # 检查是否超过阈值
            if (( $(echo "$percent >= $THRESHOLD" | bc -l) )); then
                alerts="${alerts}⚠️ <b>流量警报</b>: 用户 <b>${current_user}</b> (端口 ${current_port}) 已使用 <b>${percent}%</b> 的流量限额 (${used}GB/${limit}GB)\n\n"
            fi
        fi
    done <<< "$output"
    
    # 如果有警报则发送通知
    if [ -n "$alerts" ]; then
        local report="🚨 <b>流量使用警报</b>\n\n${alerts}流量阈值警报设置为 ${THRESHOLD}%"
        send_telegram "$report"
    fi
}

check_traffic
EOF
            
            chmod +x $SCRIPT_DIR/traffic-alert.sh
            
            # 添加定时任务
            (crontab -l 2>/dev/null | grep -v "traffic-alert.sh" ; echo "0 * * * * $SCRIPT_DIR/traffic-alert.sh > /dev/null 2>&1") | crontab -
            
            echo -e "${GREEN}Telegram通知配置已保存!${PLAIN}"
            echo -e "${GREEN}已添加每小时自动检查流量的定时任务。${PLAIN}"
            ;;
        
        2)
            if [ ! -f "$TELEGRAM_CONFIG" ]; then
                echo -e "${RED}错误: 请先配置Telegram通知。${PLAIN}"
                read -n 1 -s -r -p "按任意键继续..."
                return
            fi
            
            echo -e "${YELLOW}正在发送测试消息...${PLAIN}"
            
            source $TELEGRAM_CONFIG
            local test_message="🔍 <b>流量监控测试</b>\n\n这是一条测试消息，表明您的Telegram通知设置正确。\n\n⚙️ 当前设置:\n- 警报阈值: ${THRESHOLD}%\n- 时间: $(date '+%Y-%m-%d %H:%M:%S')"
            
            local response=$(curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
                -d chat_id="${CHAT_ID}" \
                -d text="${test_message}" \
                -d parse_mode="HTML")
            
            if [[ "$response" =~ "\"ok\":true" ]]; then
                echo -e "${GREEN}测试消息已成功发送!${PLAIN}"
            else
                echo -e "${RED}发送测试消息失败。请检查您的Bot Token和Chat ID。${PLAIN}"
                echo -e "${RED}错误: ${response}${PLAIN}"
            fi
            ;;
        
        3)
            if [ ! -f "$TELEGRAM_CONFIG" ]; then
                echo -e "${YELLOW}Telegram通知未配置。${PLAIN}"
                read -n 1 -s -r -p "按任意键继续..."
                return
            fi
            
            read -p "确定要禁用Telegram通知? (y/n): " confirm
            if [[ ! $confirm =~ ^[Yy]$ ]]; then
                echo -e "${YELLOW}操作已取消。${PLAIN}"
                read -n 1 -s -r -p "按任意键继续..."
                return
            fi
            
            # 删除配置和脚本
            rm -f $TELEGRAM_CONFIG
            rm -f $SCRIPT_DIR/traffic-alert.sh
            
            # 删除定时任务
            crontab -l 2>/dev/null | grep -v "traffic-alert.sh" | crontab -
            
            echo -e "${GREEN}Telegram通知已禁用!${PLAIN}"
            ;;
        
        0)
            return
            ;;
        
        *)
            echo -e "${RED}无效的选项!${PLAIN}"
            ;;
    esac
    
    echo
    echo -e "${CYAN}=============================${PLAIN}"
    echo
    read -n 1 -s -r -p "按任意键继续..."
}

# 端口管理菜单
port_management() {
    while true; do
        clear
        echo -e "${CYAN}=============================${PLAIN}"
        echo -e "${CYAN}        端口管理菜单        ${PLAIN}"
        echo -e "${CYAN}=============================${PLAIN}"
        echo
        echo -e "${GREEN}1.${PLAIN} 查看端口列表"
        echo -e "${GREEN}2.${PLAIN} 添加新的端口监控"
        echo -e "${GREEN}3.${PLAIN} 删除端口监控"
        echo -e "${GREEN}4.${PLAIN} 重置流量计数器"
        echo -e "${GREEN}0.${PLAIN} 返回主菜单"
        echo
        echo -e "${CYAN}=============================${PLAIN}"
        echo
        
        read -p "请选择 [0-4]: " option
        
        case $option in
            1) show_port_list; read -n 1 -s -r -p "按任意键继续..." ;;
            2) add_port_monitor ;;
            3) delete_port_monitor ;;
            4) reset_counter ;;
            0) return ;;
            *) echo -e "${RED}无效的选项!${PLAIN}"; read -n 1 -s -r -p "按任意键继续..." ;;
        esac
    done
}

# 主菜单
show_menu() {
    clear
    echo -e "${CYAN}=============================${PLAIN}"
    echo -e "${CYAN}    端口流量监控系统 v1.0    ${PLAIN}"
    echo -e "${CYAN}=============================${PLAIN}"
    echo
    echo -e "${GREEN}1.${PLAIN} 查看所有端口流量状态"
    echo -e "${GREEN}2.${PLAIN} 端口管理"
    echo -e "${GREEN}3.${PLAIN} 设置Telegram通知"
    echo -e "${GREEN}4.${PLAIN} 重新安装/更新监控脚本"
    echo -e "${RED}9.${PLAIN} 卸载监控系统"
    echo -e "${YELLOW}0.${PLAIN} 退出脚本"
    echo
    echo -e "${CYAN}=============================${PLAIN}"
    echo
}

# 卸载系统
uninstall_system() {
    clear
    echo -e "${CYAN}=============================${PLAIN}"
    echo -e "${CYAN}      卸载流量监控系统      ${PLAIN}"
    echo -e "${CYAN}=============================${PLAIN}"
    echo
    
    echo -e "${RED}警告: 此操作将完全卸载流量监控系统，包括所有配置和日志！${PLAIN}"
    read -p "确定要继续吗? (y/n): " confirm
    
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}操作已取消。${PLAIN}"
        echo
        echo -e "${CYAN}=============================${PLAIN}"
        read -n 1 -s -r -p "按任意键继续..."
        return
    fi
    
    echo
    echo -e "${YELLOW}正在卸载流量监控系统...${PLAIN}"
    
    # 清除nftables规则
    if nft list table inet traffic_monitor &>/dev/null; then
        echo -e "${YELLOW}清除nftables规则...${PLAIN}"
        nft flush table inet traffic_monitor
        nft delete table inet traffic_monitor
    fi
    
    # 删除定时任务
    echo -e "${YELLOW}删除定时任务...${PLAIN}"
    crontab -l 2>/dev/null | grep -v "traffic-" | crontab -
    
    # 删除文件
    echo -e "${YELLOW}删除脚本和配置文件...${PLAIN}"
    rm -f /usr/local/bin/traffic-monitor
    rm -rf $SCRIPT_DIR
    
    echo -e "${GREEN}流量监控系统已成功卸载!${PLAIN}"
    
    echo
    echo -e "${CYAN}=============================${PLAIN}"
    echo
    read -n 1 -s -r -p "按任意键继续..."
}

# 主函数
main() {
    check_root
    check_installation
    
    while true; do
        show_menu
        read -p "请选择 [0-9]: " option
        
        case $option in
            1) show_all_status ;;
            2) port_management ;;
            3) setup_telegram ;;
            4) install_monitor; echo -e "${GREEN}监控脚本已更新!${PLAIN}"; read -n 1 -s -r -p "按任意键继续..." ;;
            9) uninstall_system ;;
            0) 
                clear
                echo -e "${GREEN}感谢使用，再见!${PLAIN}"
                exit 0
                ;;
            *) echo -e "${RED}无效的选项!${PLAIN}"; read -n 1 -s -r -p "按任意键继续..." ;;
        esac
    done
}

# 开始执行
main
