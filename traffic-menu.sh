#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
PLAIN='\033[0m'

# 基础配置
SCRIPT_DIR="/root/ecouu"
MONITOR_SCRIPT="$SCRIPT_DIR/traffic-monitor.sh"
CONFIG_FILE="$SCRIPT_DIR/config.ini"
GITHUB_URL="https://raw.githubusercontent.com/ecouus/Shell/refs/heads/main/traffic-monitor.sh"

# 检查是否为root用户
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}错误: 此脚本需要root权限才能运行${PLAIN}"
        echo -e "${YELLOW}请使用 'sudo bash $0' 重新运行${PLAIN}"
        exit 1
    fi
}

# 安装依赖
install_deps() {
    echo -e "${BLUE}检查并安装必要的依赖...${PLAIN}"
    apt-get update -qq
    apt-get install -y curl bc wget nftables
    echo -e "${GREEN}依赖安装完成!${PLAIN}"
}

# 安装流量监控脚本
install_traffic_monitor() {
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
    $MONITOR_SCRIPT > /dev/null
    
    # 设置监控规则
    echo -e "${YELLOW}正在设置监控规则...${PLAIN}"
    $MONITOR_SCRIPT setup > /dev/null
    
    echo -e "${GREEN}流量监控脚本安装完成!${PLAIN}"
}

# 检查监控脚本是否已安装
check_installation() {
    if [ ! -f "$MONITOR_SCRIPT" ]; then
        echo -e "${YELLOW}未检测到流量监控脚本，准备安装...${PLAIN}"
        install_deps
        install_traffic_monitor
        
        # 保存规则
        nft list ruleset > /etc/nftables.conf 2>/dev/null
        systemctl enable nftables > /dev/null 2>&1
        
        echo -e "${GREEN}初始化完成!${PLAIN}"
    fi
}

# 显示所有监控端口
show_monitored_ports() {
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

# 显示特定端口的监控状态
show_port_status() {
    local port=$1
    
    if [ -z "$port" ]; then
        read -p "请输入要查看的端口: " port
    fi
    
    clear
    echo -e "${CYAN}=============================${PLAIN}"
    echo -e "${CYAN}    端口 $port 流量监控状态    ${PLAIN}"
    echo -e "${CYAN}=============================${PLAIN}"
    echo
    
    traffic-monitor status $port
    
    echo
    echo -e "${CYAN}=============================${PLAIN}"
    echo
}

# 显示所有端口的监控状态
show_all_status() {
    clear
    echo -e "${CYAN}=============================${PLAIN}"
    echo -e "${CYAN}      所有端口流量状态      ${PLAIN}"
    echo -e "${CYAN}=============================${PLAIN}"
    echo
    
    traffic-monitor
    
    echo -e "${CYAN}=============================${PLAIN}"
    echo
}

# 添加新的端口监控
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
    
    # 获取开始日期
    local date_pattern="^[0-9]{4}-[0-9]{2}-[0-9]{2}$"
    local start_date=""
    local default_date=$(date +%Y-%m-%d)
    
    read -p "请输入开始日期 (YYYY-MM-DD)[直接回车使用今天 $default_date]: " start_date
    
    if [ -z "$start_date" ]; then
        start_date=$default_date
    fi
    
    while [[ ! $start_date =~ $date_pattern ]]; do
        echo -e "${RED}无效的日期格式，请使用YYYY-MM-DD格式。${PLAIN}"
        read -p "请输入开始日期 (YYYY-MM-DD)[直接回车使用今天 $default_date]: " start_date
        if [ -z "$start_date" ]; then
            start_date=$default_date
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
    traffic-monitor add $port $limit $start_date "$user_name"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}端口 $port 的监控配置已成功添加!${PLAIN}"
        
        # 保存规则
        echo -e "${YELLOW}正在保存防火墙规则...${PLAIN}"
        nft list ruleset > /etc/nftables.conf 2>/dev/null
        echo -e "${GREEN}规则已保存，系统重启后将自动加载。${PLAIN}"
    else
        echo -e "${RED}添加监控配置失败，请检查错误信息。${PLAIN}"
    fi
    
    echo
    echo -e "${CYAN}=============================${PLAIN}"
    echo
}

# 修改现有端口监控
modify_port_monitor() {
    clear
    echo -e "${CYAN}=============================${PLAIN}"
    echo -e "${CYAN}     修改现有端口监控配置     ${PLAIN}"
    echo -e "${CYAN}=============================${PLAIN}"
    echo
    
    # 显示当前端口
    show_monitored_ports
    
    # 获取端口
    local port=""
    read -p "请输入要修改的端口号: " port
    
    # 检查端口是否存在
    local found=0
    local limit_gb=""
    local start_date=""
    local user_name=""
    
    while IFS=: read -r config_port config_limit_gb config_start_date config_user_name || [[ -n "$config_port" ]]; do
        # 跳过注释和空行
        [[ $config_port =~ ^#.*$ || -z $config_port ]] && continue
        
        if [ "$config_port" == "$port" ]; then
            found=1
            limit_gb=$config_limit_gb
            start_date=$config_start_date
            user_name=$config_user_name
            
            echo -e "${GREEN}已找到端口 $port 的配置:${PLAIN}"
            echo -e "${GREEN}限额: ${PLAIN}$limit_gb GB"
            echo -e "${GREEN}开始日期: ${PLAIN}$start_date"
            echo -e "${GREEN}用户名: ${PLAIN}$user_name"
            break
        fi
    done < $CONFIG_FILE
    
    if [ $found -eq 0 ]; then
        echo -e "${RED}未找到端口 $port 的配置，请先添加。${PLAIN}"
        echo
        echo -e "${CYAN}=============================${PLAIN}"
        read -n 1 -s -r -p "按任意键继续..."
        return
    fi
    
    # 获取新的限额
    local new_limit=""
    read -p "请输入新的流量限额 (GB)[直接回车保持不变]: " new_limit
    if [ -z "$new_limit" ]; then
        new_limit=$limit_gb
    fi
    
    while [[ ! $new_limit =~ ^[0-9]+$ ]]; do
        echo -e "${RED}无效的限额，请输入数字。${PLAIN}"
        read -p "请输入新的流量限额 (GB)[直接回车保持不变]: " new_limit
        if [ -z "$new_limit" ]; then
            new_limit=$limit_gb
        fi
    done
    
    # 获取新的开始日期
    local date_pattern="^[0-9]{4}-[0-9]{2}-[0-9]{2}$"
    local new_date=""
    
    read -p "请输入新的开始日期 (YYYY-MM-DD)[直接回车保持不变]: " new_date
    if [ -z "$new_date" ]; then
        new_date=$start_date
    fi
    
    while [[ ! $new_date =~ $date_pattern ]]; do
        echo -e "${RED}无效的日期格式，请使用YYYY-MM-DD格式。${PLAIN}"
        read -p "请输入新的开始日期 (YYYY-MM-DD)[直接回车保持不变]: " new_date
        if [ -z "$new_date" ]; then
            new_date=$start_date
        fi
    done
    
    # 获取新的用户名
    local new_user=""
    read -p "请输入新的用户名或服务标识[直接回车保持不变]: " new_user
    if [ -z "$new_user" ]; then
        new_user=$user_name
    fi
    
    # 修改监控
    echo
    echo -e "${YELLOW}正在修改端口 $port 的监控配置...${PLAIN}"
    traffic-monitor modify $port $new_limit $new_date "$new_user"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}端口 $port 的监控配置已成功修改!${PLAIN}"
        
        # 保存规则
        echo -e "${YELLOW}正在保存防火墙规则...${PLAIN}"
        nft list ruleset > /etc/nftables.conf 2>/dev/null
        echo -e "${GREEN}规则已保存，系统重启后将自动加载。${PLAIN}"
    else
        echo -e "${RED}修改监控配置失败，请检查错误信息。${PLAIN}"
    fi
    
    echo
    echo -e "${CYAN}=============================${PLAIN}"
    echo
}

# 删除端口监控
delete_port_monitor() {
    clear
    echo -e "${CYAN}=============================${PLAIN}"
    echo -e "${CYAN}       删除端口监控配置       ${PLAIN}"
    echo -e "${CYAN}=============================${PLAIN}"
    echo
    
    # 显示当前端口
    show_monitored_ports
    
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
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}端口 $port 的监控配置已成功删除!${PLAIN}"
        
        # 保存规则
        echo -e "${YELLOW}正在保存防火墙规则...${PLAIN}"
        nft list ruleset > /etc/nftables.conf 2>/dev/null
        echo -e "${GREEN}规则已保存，系统重启后将自动加载。${PLAIN}"
    else
        echo -e "${RED}删除监控配置失败，请检查端口号是否正确。${PLAIN}"
    fi
    
    echo
    echo -e "${CYAN}=============================${PLAIN}"
    echo
}

# 重置流量计数器
reset_counter() {
    clear
    echo -e "${CYAN}=============================${PLAIN}"
    echo -e "${CYAN}        重置流量计数器        ${PLAIN}"
    echo -e "${CYAN}=============================${PLAIN}"
    echo
    
    # 显示当前端口
    show_monitored_ports
    
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
            
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}端口 $port 的流量计数器已成功重置!${PLAIN}"
            else
                echo -e "${RED}重置流量计数器失败，请检查端口号是否正确。${PLAIN}"
            fi
            ;;
        2)
            echo
            echo -e "${YELLOW}正在重置所有端口的流量计数器...${PLAIN}"
            traffic-monitor reset
            
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}所有端口的流量计数器已成功重置!${PLAIN}"
            else
                echo -e "${RED}重置流量计数器失败。${PLAIN}"
            fi
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
}

# 设置定时任务
setup_cron() {
    clear
    echo -e "${CYAN}=============================${PLAIN}"
    echo -e "${CYAN}         设置定时任务         ${PLAIN}"
    echo -e "${CYAN}=============================${PLAIN}"
    echo
    
    echo -e "${YELLOW}定时任务选项:${PLAIN}"
    echo -e "${GREEN}1.${PLAIN} 设置每小时检查流量"
    echo -e "${GREEN}2.${PLAIN} 设置每天生成流量报告"
    echo -e "${GREEN}3.${PLAIN} 设置每月1日重置流量计数器"
    echo -e "${GREEN}4.${PLAIN} 查看当前定时任务"
    echo -e "${GREEN}5.${PLAIN} 删除所有流量监控定时任务"
    echo -e "${GREEN}0.${PLAIN} 返回主菜单"
    echo
    
    read -p "请选择 [0-5]: " option
    
    case $option in
        1)
            echo -e "${YELLOW}设置每小时检查流量...${PLAIN}"
            (crontab -l 2>/dev/null | grep -v "traffic-monitor.*>.*null" ; echo "0 * * * * $MONITOR_SCRIPT > /dev/null 2>&1") | crontab -
            echo -e "${GREEN}定时任务已设置!${PLAIN}"
            ;;
        2)
            echo -e "${YELLOW}设置每天生成流量报告...${PLAIN}"
            (crontab -l 2>/dev/null | grep -v "traffic-monitor.*|.*logger" ; echo "0 0 * * * $MONITOR_SCRIPT | logger -t traffic-monitor") | crontab -
            echo -e "${GREEN}定时任务已设置!${PLAIN}"
            ;;
        3)
            echo -e "${YELLOW}设置每月1日重置流量计数器...${PLAIN}"
            (crontab -l 2>/dev/null | grep -v "traffic-monitor reset" ; echo "0 0 1 * * $MONITOR_SCRIPT reset > /dev/null 2>&1") | crontab -
            echo -e "${GREEN}定时任务已设置!${PLAIN}"
            ;;
        4)
            echo -e "${YELLOW}当前定时任务:${PLAIN}"
            crontab -l | grep traffic-monitor
            if [ $? -ne 0 ]; then
                echo -e "${YELLOW}未找到流量监控相关的定时任务。${PLAIN}"
            fi
            ;;
        5)
            echo -e "${YELLOW}删除所有流量监控定时任务...${PLAIN}"
            crontab -l 2>/dev/null | grep -v "traffic-monitor" | crontab -
            echo -e "${GREEN}所有流量监控定时任务已删除!${PLAIN}"
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
}

# 查看日志
view_logs() {
    clear
    echo -e "${CYAN}=============================${PLAIN}"
    echo -e "${CYAN}          查看流量日志          ${PLAIN}"
    echo -e "${CYAN}=============================${PLAIN}"
    echo
    
    if [ ! -d "$SCRIPT_DIR/logs" ]; then
        echo -e "${YELLOW}日志目录不存在。${PLAIN}"
        echo
        echo -e "${CYAN}=============================${PLAIN}"
        read -n 1 -s -r -p "按任意键继续..."
        return
    fi
    
    # 列出所有日志文件
    echo -e "${YELLOW}可用的日志文件:${PLAIN}"
    local count=1
    local logs=()
    
    for log_file in "$SCRIPT_DIR/logs/"*; do
        if [ -f "$log_file" ]; then
            base_name=$(basename "$log_file")
            logs+=("$log_file")
            echo -e "${GREEN}$count.${PLAIN} $base_name"
            ((count++))
        fi
    done
    
    if [ ${#logs[@]} -eq 0 ]; then
        echo -e "${YELLOW}未找到日志文件。${PLAIN}"
        echo
        echo -e "${CYAN}=============================${PLAIN}"
        read -n 1 -s -r -p "按任意键继续..."
        return
    fi
    
    echo -e "${GREEN}0.${PLAIN} 返回主菜单"
    echo
    
    read -p "请选择要查看的日志 [0-$((count-1))]: " log_option
    
    if [ "$log_option" == "0" ]; then
        return
    fi
    
    if [[ $log_option =~ ^[0-9]+$ ]] && [ $log_option -ge 1 ] && [ $log_option -lt $count ]; then
        selected_log=${logs[$log_option-1]}
        
        echo
        echo -e "${CYAN}日志文件: $(basename "$selected_log")${PLAIN}"
        echo -e "${CYAN}-----------------------------${PLAIN}"
        
        # 显示日志内容
        cat "$selected_log" | less
    else
        echo -e "${RED}无效的选项!${PLAIN}"
    fi
    
    echo
    echo -e "${CYAN}=============================${PLAIN}"
    echo
}

# 设置系统启动时自动加载
# 设置系统启动时自动加载
setup_autostart() {
    clear
    echo -e "${CYAN}=============================${PLAIN}"
    echo -e "${CYAN}      设置系统启动自动加载      ${PLAIN}"
    echo -e "${CYAN}=============================${PLAIN}"
    echo
    
    echo -e "${YELLOW}正在配置系统启动自动加载...${PLAIN}"
    
    # 保存nftables规则
    echo -e "${YELLOW}保存nftables规则...${PLAIN}"
    nft list ruleset > /etc/nftables.conf 2>/dev/null
    
    # 启用nftables服务
    echo -e "${YELLOW}启用nftables服务...${PLAIN}"
    systemctl enable nftables > /dev/null 2>&1
    
    # 创建自启动服务
    echo -e "${YELLOW}创建自启动服务...${PLAIN}"
    cat > /etc/systemd/system/traffic-monitor.service << EOF
[Unit]
Description=Traffic Monitor Service
After=network.target

[Service]
Type=oneshot
ExecStart=$MONITOR_SCRIPT setup
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    
    # 启用服务
    echo -e "${YELLOW}启用traffic-monitor服务...${PLAIN}"
    systemctl daemon-reload
    systemctl enable traffic-monitor.service
    
    # 创建流量告警通知脚本
    echo -e "${YELLOW}创建流量告警通知脚本...${PLAIN}"
    cat > "$SCRIPT_DIR/traffic-alert.sh" << 'SCRIPT_EOF'
#!/bin/bash

# 加载配置
SCRIPT_DIR="/root/ecouu"
CONFIG_FILE="$SCRIPT_DIR/config.ini"
ALERT_CONFIG_FILE="$SCRIPT_DIR/alert_config.ini"

# 加载告警配置
source $ALERT_CONFIG_FILE 2>/dev/null

# 检查配置是否完整
if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ] || [ -z "$ALERT_THRESHOLD" ]; then
    exit 0
fi

# 发送Telegram通知
send_telegram_alert() {
    local message="$1"
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
         -d "chat_id=$TELEGRAM_CHAT_ID" \
         -d "text=$message" > /dev/null
}

# 从流量监控脚本获取详细信息
while IFS=: read -r port limit_gb start_date user_name || [[ -n "$port" ]]; do
    # 跳过注释和空行
    [[ $port =~ ^#.*$ || -z $port ]] && continue
    
    # 获取流量状态
    status=$(traffic-monitor status $port)
    
    # 解析流量使用百分比
    usage_percent=$(echo "$status" | grep "流量使用:" | grep -oP '\(\K[^%]+')
    
    # 检查是否超过阈值
    if (( $(echo "$usage_percent >= $ALERT_THRESHOLD" | bc -l) )); then
        message="⚠️ 流量告警 ⚠️
端口: $port
用户: $user_name
已使用流量: $usage_percent%
限额: $limit_gb GB
开始日期: $start_date"
        
        send_telegram_alert "$message"
    fi
done < $CONFIG_FILE
SCRIPT_EOF

    # 设置脚本权限
    chmod +x "$SCRIPT_DIR/traffic-alert.sh"

    # 创建每小时检查的定时任务
    (crontab -l 2>/dev/null | grep -v "traffic-alert.sh" ; echo "0 * * * * $SCRIPT_DIR/traffic-alert.sh > /dev/null 2>&1") | crontab -
    
    echo -e "${GREEN}系统启动自动加载配置完成!${PLAIN}"
    echo -e "${GREEN}服务已启用，将在系统重启后自动加载监控规则和流量告警。${PLAIN}"
    
    echo
    echo -e "${CYAN}=============================${PLAIN}"
    echo
}

# 卸载流量监控系统
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
    
    # 删除服务
    if [ -f "/etc/systemd/system/traffic-monitor.service" ]; then
        echo -e "${YELLOW}删除系统服务...${PLAIN}"
        systemctl disable traffic-monitor.service
        rm -f /etc/systemd/system/traffic-monitor.service
        systemctl daemon-reload
    fi
    
    # 删除定时任务
    echo -e "${YELLOW}删除定时任务...${PLAIN}"
    crontab -l 2>/dev/null | grep -v "traffic-monitor" | crontab -
    
    # 删除文件
    echo -e "${YELLOW}删除脚本和配置文件...${PLAIN}"
    rm -f /usr/local/bin/traffic-monitor
    rm -rf $SCRIPT_DIR
    
    echo -e "${GREEN}流量监控系统已成功卸载!${PLAIN}"
    
    echo
    echo -e "${CYAN}=============================${PLAIN}"
    echo
    
    exit 0
}
# 设置Telegram流量告警
setup_traffic_alert() {
    clear
    echo -e "${CYAN}=============================${PLAIN}"
    echo -e "${CYAN}       流量报警设置       ${PLAIN}"
    echo -e "${CYAN}=============================${PLAIN}"
    echo
    
    echo -e "${YELLOW}流量报警设置选项:${PLAIN}"
    echo -e "${GREEN}1.${PLAIN} 设置Telegram Bot通知"
    echo -e "${GREEN}2.${PLAIN} 配置流量报警阈值"
    echo -e "${GREEN}3.${PLAIN} 查看当前报警配置"
    echo -e "${GREEN}0.${PLAIN} 返回主菜单"
    echo
    
    read -p "请选择 [0-3]: " option
    
    case $option in
        1)
            read -p "请输入Telegram Bot Token: " bot_token
            read -p "请输入Telegram Chat ID: " chat_id
            
            # 创建或更新警报配置文件
            mkdir -p $SCRIPT_DIR
            cat > $ALERT_CONFIG_FILE << EOF
TELEGRAM_BOT_TOKEN=$bot_token
TELEGRAM_CHAT_ID=$chat_id
EOF
            echo -e "${GREEN}Telegram Bot配置已保存!${PLAIN}"
            ;;
        2)
            read -p "请输入流量报警阈值 (百分比, 默认90): " alert_threshold
            
            # 默认90%
            if [ -z "$alert_threshold" ]; then
                alert_threshold=90
            fi
            
            # 追加或更新阈值配置
            if grep -q "ALERT_THRESHOLD" $ALERT_CONFIG_FILE 2>/dev/null; then
                sed -i "s/ALERT_THRESHOLD=.*/ALERT_THRESHOLD=$alert_threshold/" $ALERT_CONFIG_FILE
            else
                echo "ALERT_THRESHOLD=$alert_threshold" >> $ALERT_CONFIG_FILE
            fi
            
            echo -e "${GREEN}流量报警阈值已设置为 $alert_threshold%!${PLAIN}"
            ;;
        3)
            echo -e "${YELLOW}当前报警配置:${PLAIN}"
            if [ -f "$ALERT_CONFIG_FILE" ]; then
                cat $ALERT_CONFIG_FILE
            else
                echo -e "${YELLOW}尚未配置报警设置。${PLAIN}"
            fi
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
    read -n 1 -s -r -p "按任意键继续..."
    echo
}

# 主菜单
show_menu() {
    clear
    echo -e "${CYAN}=============================${PLAIN}"
    echo -e "${CYAN}    端口流量监控系统 v1.1    ${PLAIN}"
    echo -e "${CYAN}=============================${PLAIN}"
    echo
    echo -e "${GREEN}  1.${PLAIN} 查看所有端口流量状态"
    echo -e "${GREEN}  2.${PLAIN} 查看特定端口流量状态"
    echo -e "${GREEN}  3.${PLAIN} 显示监控端口列表"
    echo -e "${GREEN}  4.${PLAIN} 添加新的端口监控"
    echo -e "${GREEN}  5.${PLAIN} 修改端口监控配置"
    echo -e "${GREEN}  6.${PLAIN} 删除端口监控配置"
    echo -e "${GREEN}  7.${PLAIN} 重置流量计数器"
    echo -e "${GREEN}  8.${PLAIN} 设置定时任务"
    echo -e "${GREEN}  9.${PLAIN} 查看流量日志"
    echo -e "${GREEN} 10.${PLAIN} 设置系统启动自动加载"
    echo -e "${GREEN} 11.${PLAIN} 重新安装/更新流量监控脚本"
    echo -e "${GREEN} 12.${PLAIN} 流量报警设置"
    echo -e "${RED} 99.${PLAIN} 卸载流量监控系统"
    echo -e "${YELLOW}  0.${PLAIN} 退出脚本"
    echo
    echo -e "${CYAN}=============================${PLAIN}"
    echo
}

# 主函数
main() {
    check_root
    check_installation
    
    while true; do
        show_menu
        read -p "请选择 [0-12,99]: " option
        
        case $option in
            1) show_all_status; read -n 1 -s -r -p "按任意键继续..." ;;
            2) show_port_status; read -n 1 -s -r -p "按任意键继续..." ;;
            3) show_monitored_ports; read -n 1 -s -r -p "按任意键继续..." ;;
            4) add_port_monitor; read -n 1 -s -r -p "按任意键继续..." ;;
            5) modify_port_monitor; read -n 1 -s -r -p "按任意键继续..." ;;
            6) delete_port_monitor; read -n 1 -s -r -p "按任意键继续..." ;;
            7) reset_counter; read -n 1 -s -r -p "按任意键继续..." ;;
            8) setup_cron; read -n 1 -s -r -p "按任意键继续..." ;;
            9) view_logs ;;
            10) setup_autostart; read -n 1 -s -r -p "按任意键继续..." ;;
            11) install_traffic_monitor; read -n 1 -s -r -p "按任意键继续..." ;;
            12) setup_traffic_alert; read -n 1 -s -r -p "按任意键继续..." ;;
            99) uninstall_system ;;
            0) 
                echo -e "${GREEN}感谢使用，再见!${PLAIN}"
                exit 0 
                ;;
            *)
                echo -e "${RED}无效的选项!${PLAIN}"
                read -n 1 -s -r -p "按任意键继续..."
                ;;
        esac
    done
}

# 执行主函数
main
