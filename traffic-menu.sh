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

# 修改setup_telegram函数，添加Telegram Bot功能
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
    echo -e "${YELLOW}3.${PLAIN} 配置Telegram Bot命令"
    echo -e "${YELLOW}4.${PLAIN} 禁用Telegram通知"
    echo -e "${YELLOW}0.${PLAIN} 返回主菜单"
    echo
    
    read -p "请选择 [0-4]: " option
    
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
                echo -e "${RED}错误: 请先配置Telegram通知。${PLAIN}"
                read -n 1 -s -r -p "按任意键继续..."
                return
            fi
            
            source $TELEGRAM_CONFIG
            
            echo -e "${YELLOW}正在配置Telegram Bot命令...${PLAIN}"
            echo -e "${YELLOW}这将允许您通过Telegram Bot主动查询流量、添加/删除端口监控等。${PLAIN}"
            echo
            
            # 创建机器人脚本
            cat > $SCRIPT_DIR/tg_bot.sh << 'EOF'
#!/bin/bash

# Telegram Bot脚本
CONFIG_FILE="/root/ecouu/telegram.conf"
MONITOR_SCRIPT="/root/ecouu/traffic-monitor.sh"
OFFSET_FILE="/root/ecouu/telegram_offset.txt"

# 加载配置
if [ ! -f "$CONFIG_FILE" ]; then
    echo "错误: 配置文件不存在"
    exit 1
fi

source "$CONFIG_FILE"

# 获取最后处理的update_id
LAST_UPDATE_ID=0
if [ -f "$OFFSET_FILE" ]; then
    LAST_UPDATE_ID=$(cat "$OFFSET_FILE")
fi

# 发送消息
send_message() {
    local chat_id="$1"
    local text="$2"
    
    # 直接发送纯文本
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d chat_id="${chat_id}" \
        -d text="${text}" > /dev/null
}

# 处理 /status 命令
handle_status() {
    local chat_id="$1"
    local port="$2"
    
    if [ -z "$port" ]; then
        # 查询所有端口
        local output=$(${MONITOR_SCRIPT})
        send_message "$chat_id" "${output}"
    else
        # 查询特定端口
        local output=$(${MONITOR_SCRIPT} status $port 2>&1)
        send_message "$chat_id" "${output}"
    fi
}

# 处理 /add 命令
handle_add() {
    local chat_id="$1"
    local port="$2"
    
    if [ -z "$port" ]; then
        send_message "$chat_id" "❌ 端口号不能为空\n\n用法: /add 端口号 [限额GB] [用户名]\n示例: /add 8080 100 Web服务"
        return
    fi
    
    # 默认值
    local limit="100"
    local username="端口${port}用户"
    
    # 解析参数
    if [ $# -gt 2 ]; then
        limit="$3"
    fi
    
    if [ $# -gt 3 ]; then
        username="${*:4}"
    fi
    
    # 添加端口监控
    local output=$(${MONITOR_SCRIPT} add $port $limit $(date +%Y-%m-%d) "$username" 2>&1)
    
    if [[ "$output" == *"已添加新的监控"* ]]; then
        send_message "$chat_id" "✅ 成功添加端口监控\n\n端口: $port\n限额: ${limit}GB\n用户: $username\n开始日期: $(date +%Y-%m-%d)"
    else
        send_message "$chat_id" "❌ 添加失败\n\n${output}"
    fi
}

# 处理 /rm 命令
handle_rm() {
    local chat_id="$1"
    local port="$2"
    
    if [ -z "$port" ]; then
        send_message "$chat_id" "❌ 请指定要删除的端口\n\n用法: /rm 端口号\n示例: /rm 8080"
        return
    fi
    
    # 删除端口监控
    local output=$(${MONITOR_SCRIPT} delete $port 2>&1)
    
    if [[ "$output" == *"已删除端口"* ]]; then
        send_message "$chat_id" "✅ 成功删除端口 $port 的监控配置"
    else
        send_message "$chat_id" "❌ 删除失败\n\n${output}"
    fi
}

# 处理 /reset 命令
handle_reset() {
    local chat_id="$1"
    local port="$2"
    
    if [ -z "$port" ]; then
        send_message "$chat_id" "❌ 请指定要重置的端口\n\n用法: /reset 端口号\n示例: /reset 8080\n使用 /reset_all 可重置所有端口"
        return
    fi
    
    # 重置端口流量计数器
    local output=$(${MONITOR_SCRIPT} reset $port 2>&1)
    
    if [[ "$output" == *"计数器已重置"* ]]; then
        send_message "$chat_id" "✅ 成功重置端口 $port 的流量计数器"
    else
        send_message "$chat_id" "❌ 重置失败\n\n${output}"
    fi
}

# 处理 /reset_all 命令
handle_reset_all() {
    local chat_id="$1"
    
    # 重置所有端口流量计数器
    local output=$(${MONITOR_SCRIPT} reset 2>&1)
    
    if [[ "$output" == *"所有计数器重置完成"* ]]; then
        send_message "$chat_id" "✅ 成功重置所有端口的流量计数器"
    else
        send_message "$chat_id" "❌ 重置失败\n\n${output}"
    fi
}

# 显示帮助信息
show_help() {
    local chat_id="$1"
    local help_message="📋 <b>流量监控Bot命令列表</b>\n\n"
    help_message+="/status - 查看所有端口流量状态\n"
    help_message+="/status [端口] - 查看特定端口流量状态\n"
    help_message+="/add [端口] [限额GB] [用户名] - 添加新的端口监控\n"
    help_message+="/rm [端口] - 删除端口监控\n"
    help_message+="/reset [端口] - 重置特定端口的流量计数器\n"
    help_message+="/reset_all - 重置所有端口的流量计数器\n"
    help_message+="/help - 显示此帮助信息"
    
    send_message "$chat_id" "$help_message"
}

# 处理命令
process_command() {
    local chat_id="$1"
    local command="$2"
    shift 2
    local args=("$@")
    
    # 只处理来自授权聊天的命令
    if [ "$chat_id" != "$CHAT_ID" ]; then
        send_message "$chat_id" "⛔ 未授权的请求。您的Chat ID: $chat_id"
        return
    fi
    
    case $command in
        "/start" | "/help")
            show_help "$chat_id"
            ;;
        "/status")
            handle_status "$chat_id" "${args[0]}"
            ;;
        "/add")
            handle_add "$chat_id" "${args[@]}"
            ;;
        "/rm")
            handle_rm "$chat_id" "${args[0]}"
            ;;
        "/reset")
            handle_reset "$chat_id" "${args[0]}"
            ;;
        "/reset_all")
            handle_reset_all "$chat_id"
            ;;
        *)
            send_message "$chat_id" "❓ 未知命令。使用 /help 查看可用命令。"
            ;;
    esac
}

echo "Telegram Bot已启动，正在等待命令..."

# 主循环
while true; do
    # 获取更新
    UPDATES=$(curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getUpdates?offset=${LAST_UPDATE_ID}&timeout=60")
    
    # 提取更新ID，检查是否有新消息
    UPDATE_IDS=$(echo "$UPDATES" | grep -o '"update_id":[0-9]*' | grep -o '[0-9]*')
    
    for id in $UPDATE_IDS; do
        if [ "$id" -gt "$LAST_UPDATE_ID" ]; then
            LAST_UPDATE_ID=$id
            
            # 提取消息文本和聊天ID
            MESSAGE_TEXT=$(echo "$UPDATES" | grep -A10 "\"update_id\":$id" | grep -o '"text":"[^"]*"' | sed 's/"text":"//g' | sed 's/"//g' | head -1)
            CHAT_ID=$(echo "$UPDATES" | grep -A10 "\"update_id\":$id" | grep -o '"chat":{"id":[^,]*' | grep -o '[0-9-]*' | head -1)
            
            if [ -n "$MESSAGE_TEXT" ] && [ -n "$CHAT_ID" ]; then
                # 检查是否是命令（以/开头）
                if [[ "$MESSAGE_TEXT" == /* ]]; then
                    # 提取命令和参数
                    COMMAND=$(echo "$MESSAGE_TEXT" | cut -d' ' -f1)
                    ARGS=$(echo "$MESSAGE_TEXT" | cut -d' ' -f2-)
                    
                    # 直接调用处理函数，根据命令类型
                    case "$COMMAND" in
                        "/status")
                            handle_status "$CHAT_ID" "$ARGS"
                            ;;
                        "/add")
                            handle_add "$CHAT_ID" $ARGS
                            ;;
                        "/rm")
                            handle_rm "$CHAT_ID" "$ARGS"
                            ;;
                        "/reset")
                            handle_reset "$CHAT_ID" "$ARGS"
                            ;;
                        "/reset_all")
                            handle_reset_all "$CHAT_ID"
                            ;;
                        "/start"|"/help")
                            show_help "$CHAT_ID"
                            ;;
                        *)
                            send_message "$CHAT_ID" "未知命令。使用 /help 查看可用命令。"
                            ;;
                    esac
                fi
            fi
        fi
    done
    
    # 更新offset
    echo $((LAST_UPDATE_ID + 1)) > "$OFFSET_FILE"
    
    # 间隔
    sleep 2
done
EOF
            
            chmod +x $SCRIPT_DIR/tg_bot.sh
            
            # 停止已存在的Bot进程
            if pgrep -f "$SCRIPT_DIR/tg_bot.sh" > /dev/null; then
                echo -e "${YELLOW}停止现有Bot进程...${PLAIN}"
                pkill -f "$SCRIPT_DIR/tg_bot.sh"
                sleep 1
            fi
            
            # 创建并启动服务
            cat > /etc/systemd/system/traffic-bot.service << EOF
[Unit]
Description=Traffic Monitor Telegram Bot
After=network.target

[Service]
ExecStart=/bin/bash $SCRIPT_DIR/tg_bot.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
            
            # 启动服务
            systemctl daemon-reload
            systemctl enable traffic-bot.service
            systemctl restart traffic-bot.service
            
            # 设置命令
            curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/setMyCommands" \
                -H "Content-Type: application/json" \
                -d '{
                "commands": [
                    {"command": "status", "description": "查看流量状态"},
                    {"command": "add", "description": "添加端口监控"},
                    {"command": "rm", "description": "删除端口监控"},
                    {"command": "reset", "description": "重置流量计数器"},
                    {"command": "reset_all", "description": "重置所有计数器"},
                    {"command": "help", "description": "显示帮助信息"}
                ]
            }'
            
            echo -e "${GREEN}Telegram Bot命令已配置!${PLAIN}"
            echo -e "${GREEN}您现在可以通过以下命令管理流量监控:${PLAIN}"
            echo -e "${GREEN}/status${PLAIN} - 查看所有端口流量状态"
            echo -e "${GREEN}/status 端口${PLAIN} - 查看特定端口流量状态"
            echo -e "${GREEN}/add 端口 [限额GB] [用户名]${PLAIN} - 添加新的端口监控"
            echo -e "${GREEN}/rm 端口${PLAIN} - 删除端口监控"
            echo -e "${GREEN}/reset 端口${PLAIN} - 重置特定端口的流量计数器"
            echo -e "${GREEN}/reset_all${PLAIN} - 重置所有端口的流量计数器"
            ;;
            
        4)
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
            
            # 停止服务
            systemctl stop traffic-bot.service 2>/dev/null
            systemctl disable traffic-bot.service 2>/dev/null
            rm -f /etc/systemd/system/traffic-bot.service
            systemctl daemon-reload
            
            # 杀死相关进程
            pkill -f "$SCRIPT_DIR/tg_bot.sh" 2>/dev/null
            
            # 删除配置和脚本
            rm -f $TELEGRAM_CONFIG
            rm -f $SCRIPT_DIR/traffic-alert.sh
            rm -f $SCRIPT_DIR/tg_bot.sh
            rm -f $SCRIPT_DIR/telegram_offset.txt
            
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

# 添加流量阻断配置函数
setup_block_option() {
    clear
    echo -e "${CYAN}=============================${PLAIN}"
    echo -e "${CYAN}    流量超限阻断功能设置    ${PLAIN}"
    echo -e "${CYAN}=============================${PLAIN}"
    echo
    
    local block_config="$SCRIPT_DIR/block_config.ini"
    local current_status="已禁用"
    local current_type="nftables"
    local current_action="reject"
    
    # 检查现有配置
    if [ -f "$block_config" ]; then
        source "$block_config"
        [ "$BLOCK_ENABLED" = "true" ] && current_status="已启用"
        [ -n "$BLOCK_TYPE" ] && current_type="$BLOCK_TYPE"
        [ -n "$BLOCK_ACTION" ] && current_action="$BLOCK_ACTION"
    fi
    
    echo -e "${YELLOW}流量超限阻断功能可以在端口流量超过限额时自动采取措施。${PLAIN}"
    echo -e "${YELLOW}当前状态: ${current_status}${PLAIN}"
    echo -e "${YELLOW}阻断方式: ${current_type}${PLAIN}"
    echo -e "${YELLOW}阻断行为: ${current_action}${PLAIN}"
    echo
    
    echo -e "${GREEN}1.${PLAIN} 启用/禁用阻断功能"
    echo -e "${GREEN}2.${PLAIN} 设置阻断方式(nftables/iptables)"
    echo -e "${GREEN}3.${PLAIN} 设置阻断行为(reject/drop)"
    echo -e "${GREEN}0.${PLAIN} 返回主菜单"
    echo
    
    read -p "请选择 [0-3]: " option
    
    case $option in
        1)
            if [ "$current_status" = "已启用" ]; then
                read -p "确定要禁用阻断功能吗? (y/n): " confirm
                if [[ $confirm =~ ^[Yy]$ ]]; then
                    echo "BLOCK_ENABLED=false" > $block_config
                    [ -n "$current_type" ] && echo "BLOCK_TYPE=$current_type" >> $block_config
                    [ -n "$current_action" ] && echo "BLOCK_ACTION=$current_action" >> $block_config
                    echo -e "${GREEN}阻断功能已禁用!${PLAIN}"
                fi
            else
                read -p "确定要启用阻断功能吗? (y/n): " confirm
                if [[ $confirm =~ ^[Yy]$ ]]; then
                    echo "BLOCK_ENABLED=true" > $block_config
                    [ -n "$current_type" ] && echo "BLOCK_TYPE=$current_type" >> $block_config
                    [ -n "$current_action" ] && echo "BLOCK_ACTION=$current_action" >> $block_config
                    echo -e "${GREEN}阻断功能已启用!${PLAIN}"
                    
                    # 创建或更新阻断脚本
                    create_block_script
                fi
            fi
            ;;
        
        2)
            echo
            echo -e "${YELLOW}请选择阻断方式:${PLAIN}"
            echo -e "${GREEN}1.${PLAIN} nftables (推荐)"
            echo -e "${GREEN}2.${PLAIN} iptables"
            echo
            
            read -p "请选择 [1-2]: " block_type_option
            
            case $block_type_option in
                1) current_type="nftables" ;;
                2) current_type="iptables" ;;
                *) echo -e "${RED}无效的选项，保持原有设置。${PLAIN}"; read -n 1 -s -r -p "按任意键继续..."; return ;;
            esac
            
            # 更新配置
            if [ -f "$block_config" ]; then
                source "$block_config"
                echo "BLOCK_ENABLED=$BLOCK_ENABLED" > $block_config
            else
                echo "BLOCK_ENABLED=false" > $block_config
            fi
            
            echo "BLOCK_TYPE=$current_type" >> $block_config
            [ -n "$current_action" ] && echo "BLOCK_ACTION=$current_action" >> $block_config
            
            echo -e "${GREEN}阻断方式已更新为 $current_type!${PLAIN}"
            
            # 创建或更新阻断脚本
            create_block_script
            ;;
        
        3)
            echo
            echo -e "${YELLOW}请选择阻断行为:${PLAIN}"
            echo -e "${GREEN}1.${PLAIN} reject (向客户端发送拒绝连接消息)"
            echo -e "${GREEN}2.${PLAIN} drop (直接丢弃数据包，不回应客户端)"
            echo
            
            read -p "请选择 [1-2]: " block_action_option
            
            case $block_action_option in
                1) current_action="reject" ;;
                2) current_action="drop" ;;
                *) echo -e "${RED}无效的选项，保持原有设置。${PLAIN}"; read -n 1 -s -r -p "按任意键继续..."; return ;;
            esac
            
            # 更新配置
            if [ -f "$block_config" ]; then
                source "$block_config"
                echo "BLOCK_ENABLED=$BLOCK_ENABLED" > $block_config
            else
                echo "BLOCK_ENABLED=false" > $block_config
            fi
            
            [ -n "$current_type" ] && echo "BLOCK_TYPE=$current_type" >> $block_config
            echo "BLOCK_ACTION=$current_action" >> $block_config
            
            echo -e "${GREEN}阻断行为已更新为 $current_action!${PLAIN}"
            
            # 创建或更新阻断脚本
            create_block_script
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

# 创建阻断脚本
create_block_script() {
    local block_script="$SCRIPT_DIR/traffic-block.sh"
    
    cat > $block_script << 'EOF'
#!/bin/bash

# 阻断脚本配置
SCRIPT_DIR="/root/ecouu"
BLOCK_CONFIG="$SCRIPT_DIR/block_config.ini"
MONITOR_SCRIPT="$SCRIPT_DIR/traffic-monitor.sh"
CONFIG_FILE="$SCRIPT_DIR/config.ini"
BLOCK_LOG="$SCRIPT_DIR/logs/block.log"

# 加载阻断配置
if [ ! -f "$BLOCK_CONFIG" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 错误: 阻断配置文件不存在" >> $BLOCK_LOG
    exit 1
fi

source "$BLOCK_CONFIG"

# 检查阻断功能是否启用
if [ "$BLOCK_ENABLED" != "true" ]; then
    exit 0
fi

# 确保日志目录存在
mkdir -p "$(dirname "$BLOCK_LOG")"

# 使用nftables阻断端口
block_port_nftables() {
    local port="$1"
    local action="${2:-$BLOCK_ACTION}"
    
    # 检查nftables表是否存在
    if ! nft list table inet traffic_blocker &>/dev/null; then
        nft add table inet traffic_blocker
        nft add chain inet traffic_blocker input { type filter hook input priority 0 \; }
        nft add chain inet traffic_blocker output { type filter hook output priority 0 \; }
    fi
    
    # 检查该端口是否已经被阻断
    if nft list table inet traffic_blocker | grep -q "tcp dport $port"; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 端口 $port 已经被阻断" >> $BLOCK_LOG
        return
    fi
    
    # 添加阻断规则
    nft add rule inet traffic_blocker input tcp dport $port $action
    nft add rule inet traffic_blocker output tcp sport $port $action
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 已使用nftables阻断端口 $port (行为: $action)" >> $BLOCK_LOG
}

# 使用iptables阻断端口
block_port_iptables() {
    local port="$1"
    local action="${2:-$BLOCK_ACTION}"
    
    # 映射动作
    local iptables_action="REJECT"
    [ "$action" = "drop" ] && iptables_action="DROP"
    
    # 检查该端口是否已经被阻断
    if iptables -C INPUT -p tcp --dport $port -j $iptables_action &>/dev/null; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 端口 $port 已经被阻断" >> $BLOCK_LOG
        return
    fi
    
    # 添加阻断规则
    iptables -A INPUT -p tcp --dport $port -j $iptables_action
    iptables -A OUTPUT -p tcp --sport $port -j $iptables_action
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 已使用iptables阻断端口 $port (行为: $action)" >> $BLOCK_LOG
}

# 解除端口阻断
unblock_port() {
    local port="$1"
    
    if [ "$BLOCK_TYPE" = "nftables" ]; then
        # 删除nftables规则
        if nft list table inet traffic_blocker &>/dev/null; then
            nft delete rule inet traffic_blocker input handle $(nft -a list table inet traffic_blocker | grep "tcp dport $port" | grep -o 'handle [0-9]*' | awk '{print $2}') 2>/dev/null
            nft delete rule inet traffic_blocker output handle $(nft -a list table inet traffic_blocker | grep "tcp sport $port" | grep -o 'handle [0-9]*' | awk '{print $2}') 2>/dev/null
        fi
    else
        # 删除iptables规则
        local iptables_action="REJECT"
        [ "$BLOCK_ACTION" = "drop" ] && iptables_action="DROP"
        
        iptables -D INPUT -p tcp --dport $port -j $iptables_action 2>/dev/null
        iptables -D OUTPUT -p tcp --sport $port -j $iptables_action 2>/dev/null
    fi
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 已解除端口 $port 的阻断" >> $BLOCK_LOG
}

# 检查并阻断超限端口
check_and_block() {
    local output=$($MONITOR_SCRIPT)
    local current_port=""
    local current_user=""
    local block_status="unblocked"  # 用于跟踪阻断状态
    
    # 解析输出，查找超限的端口
    while IFS= read -r line; do
        # 提取端口号
        if [[ $line =~ 端口:\ ([0-9]+) ]]; then
            current_port="${BASH_REMATCH[1]}"
            block_status="unblocked"  # 重置阻断状态
        fi
        
        # 提取用户名
        if [[ $line =~ \[监控\ (.*)\] ]]; then
            current_user="${BASH_REMATCH[1]}"
        fi
        
        # 检查流量限制状态
        if [[ $line =~ 流量使用:\ ([0-9.]+)GB\ /\ ([0-9.]+)GB\ \(([0-9.]+)%\) ]]; then
            local used="${BASH_REMATCH[1]}"
            local limit="${BASH_REMATCH[2]}"
            local percent="${BASH_REMATCH[3]}"
            
            # 检查是否超过限额
            if (( $(echo "$percent >= 100" | bc -l) )); then
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 端口 $current_port ($current_user) 流量已超限: ${used}GB/${limit}GB" >> $BLOCK_LOG
                
                # 根据配置选择阻断方法
                if [ "$BLOCK_TYPE" = "nftables" ]; then
                    block_port_nftables $current_port
                else
                    block_port_iptables $current_port
                fi
                
                block_status="blocked"
            fi
        fi
        
        # 检查流量状态行
        if [[ $line =~ 状态:\ (.*) && "$block_status" != "blocked" ]]; then
            local status="${BASH_REMATCH[1]}"
            # 如果已标记为超限但流量实际未超，则解除阻断
            if [[ "$status" =~ "正常" ]]; then
                unblock_port $current_port
            fi
        fi
    done <<< "$output"
}

# 保存永久规则
save_rules() {
    if [ "$BLOCK_TYPE" = "nftables" ]; then
        nft list ruleset > /etc/nftables.conf 2>/dev/null
    else
        if command -v iptables-save &>/dev/null; then
            iptables-save > /etc/iptables/rules.v4 2>/dev/null || iptables-save > /etc/iptables.rules 2>/dev/null
        fi
    fi
}

# 主函数
main() {
    check_and_block
    save_rules
}

main
EOF
    
    chmod +x $block_script
    
    # 添加定时任务，每5分钟执行一次
    if ! crontab -l 2>/dev/null | grep -q "traffic-block.sh"; then
        (crontab -l 2>/dev/null; echo "*/5 * * * * $block_script > /dev/null 2>&1") | crontab -
        echo -e "${GREEN}已添加定时任务，每5分钟检查一次流量限额并执行阻断策略。${PLAIN}"
    fi
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
    echo -e "${CYAN}   Linux流量监控与限制系统   ${PLAIN}"
    echo -e "${CYAN}=============================${PLAIN}"
    echo
    echo -e "${GREEN}1.${PLAIN} 显示所有端口流量状态"
    echo -e "${GREEN}2.${PLAIN} 查看端口监控列表"
    echo -e "${GREEN}3.${PLAIN} 添加端口监控"
    echo -e "${GREEN}4.${PLAIN} 删除端口监控"
    echo -e "${GREEN}5.${PLAIN} 重置流量计数器"
    echo -e "${GREEN}6.${PLAIN} 设置Telegram通知"
    # 在这里添加新的菜单选项
    echo -e "${GREEN}7.${PLAIN} 流量超限阻断设置"
    echo -e "${RED}9.${PLAIN} 卸载监控系统"
    echo -e "${GREEN}0.${PLAIN} 退出脚本"
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
check_root
check_installation

while true; do
    show_menu
    read -p "请选择一个选项 [0-7]: " choice
    
    case $choice in
        1)
            show_all_status
            ;;
        2)
            show_port_list
            read -n 1 -s -r -p "按任意键继续..."
            ;;
        3)
            add_port_monitor
            ;;
        4)
            delete_port_monitor
            ;;
        5)
            reset_counter
            ;;
        6)
            setup_telegram
            ;;
        7)
            setup_block_option
            ;;
        9)
            uninstall_system
            ;;       
        0)
            echo
            echo -e "${GREEN}感谢使用，再见!${PLAIN}"
            exit 0
            ;;
        *)
            echo -e "${RED}错误: 请输入有效的选项 [0-7]${PLAIN}"
            sleep 1
            ;;
    esac
done
