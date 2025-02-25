#!/bin/bash

# 配置文件位置
CONFIG_FILE="/root/ecouu/config.ini"
LOG_DIR="/root/ecouu/logs"

# 检查并安装必要的工具
check_dependencies() {
    local missing=""
    
    # 检查bc
    if ! command -v bc &> /dev/null; then
        missing="$missing bc"
    fi
    
    # 如果有缺失的依赖，尝试安装
    if [ -n "$missing" ]; then
        echo "正在安装必要的依赖: $missing"
        apt-get update && apt-get install -y $missing
        
        # 再次检查
        if ! command -v bc &> /dev/null; then
            echo "错误: 无法安装必要的依赖。请手动安装: apt-get install -y bc"
            exit 1
        fi
    fi
    
    # 检查是否为nftables系统
    if iptables -V | grep -q "nf_tables"; then
        echo "检测到nftables后端，将使用nft命令"
        USE_NFT=1
    else
        echo "使用传统iptables"
        USE_NFT=0
    fi
}

# 确保目录存在
mkdir -p $(dirname $CONFIG_FILE)
mkdir -p $LOG_DIR

# 如果配置文件不存在，创建一个默认配置
if [ ! -f "$CONFIG_FILE" ]; then
    cat > $CONFIG_FILE << EOL
# 流量监控配置文件
# 格式: PORT:LIMIT_GB:START_DATE:USER_NAME
# 例如: 22:10:2025-02-25:用户1
# 多个配置用换行分隔

# 添加您的配置在下面（请勿修改上面的注释）
80:9999999:$(date +%Y-%m-%d):Web服务
EOL
    echo "已创建默认配置文件: $CONFIG_FILE"
    echo "请根据需要编辑此文件"
fi

# 全局变量
USE_NFT=0

# 函数: 设置流量监控规则
setup_monitoring() {
    local port=$1
    local table_name="traffic_monitor"
    local chain_name="port_$port"
    
    if [ $USE_NFT -eq 1 ]; then
        # 使用nftables
        
        # 检查表是否存在，如果不存在则创建
        if ! sudo nft list table inet $table_name &>/dev/null; then
            echo "创建nftables表 $table_name"
            sudo nft add table inet $table_name
        fi
        
        # 检查链是否存在，如果不存在则创建
        if ! sudo nft list chain inet $table_name $chain_name &>/dev/null; then
            echo "为端口 $port 创建nftables链"
            
            # 创建计数链
            sudo nft add chain inet $table_name $chain_name
            
            # 添加规则跟踪入站流量
            sudo nft add rule inet $table_name input tcp dport $port counter jump $chain_name
            sudo nft add rule inet $table_name input udp dport $port counter jump $chain_name
            
            # 添加规则跟踪出站流量
            sudo nft add rule inet $table_name output tcp sport $port counter jump $chain_name
            sudo nft add rule inet $table_name output udp sport $port counter jump $chain_name
            
            echo "端口 $port 的nftables规则已设置"
        else
            echo "端口 $port 的nftables规则已存在"
        fi
        
    else
        # 使用传统iptables
        local chain_name="TRACK_PORT_$port"
        
        # 检查链是否已存在，如果不存在则创建
        if ! sudo iptables -L $chain_name >/dev/null 2>&1; then
            echo "为端口 $port 创建新的iptables跟踪链"
            sudo iptables -N $chain_name
            
            # 添加入站规则
            sudo iptables -A INPUT -p tcp --dport $port -j $chain_name
            sudo iptables -A INPUT -p udp --dport $port -j $chain_name
            
            # 添加出站规则
            sudo iptables -A OUTPUT -p tcp --sport $port -j $chain_name
            sudo iptables -A OUTPUT -p udp --sport $port -j $chain_name
            
            # 添加计数规则
            sudo iptables -A $chain_name -j RETURN
            
            echo "端口 $port 的iptables规则已设置"
        else
            echo "端口 $port 的iptables规则已存在"
        fi
    fi
}

# 函数: 重置计数器
reset_counter() {
    local port=$1
    
    if [ $USE_NFT -eq 1 ]; then
        # 使用nftables
        local table_name="traffic_monitor"
        local chain_name="port_$port"
        
        # 重置入站计数器
        sudo nft flush chain inet $table_name input 2>/dev/null
        sudo nft flush chain inet $table_name output 2>/dev/null
        
        # 重新添加规则
        sudo nft add rule inet $table_name input tcp dport $port counter jump $chain_name
        sudo nft add rule inet $table_name input udp dport $port counter jump $chain_name
        sudo nft add rule inet $table_name output tcp sport $port counter jump $chain_name
        sudo nft add rule inet $table_name output udp sport $port counter jump $chain_name
        
    else
        # 使用传统iptables
        local chain_name="TRACK_PORT_$port"
        sudo iptables -Z $chain_name
    fi
    
    echo "端口 $port 的计数器已重置"
}

# 函数: 检查是否需要重置计数器
check_reset_needed() {
    local port=$1
    local start_date=$2
    local reset_flag_file="$LOG_DIR/port${port}_reset_${start_date}"
    
    if [ ! -f "$reset_flag_file" ]; then
        reset_counter $port
        touch $reset_flag_file
        return 0
    fi
    return 1
}

# 函数: 计算两个日期之间的天数
days_between() {
    local start_date=$1
    local end_date=$(date +%Y-%m-%d)
    local days=$(( ($(date -d "$end_date" +%s) - $(date -d "$start_date" +%s)) / 86400 ))
    echo $days
}

# 函数: 获取端口流量统计
get_traffic_stats() {
    local port=$1
    local bytes_in=0
    local bytes_out=0
    
    if [ $USE_NFT -eq 1 ]; then
        # 使用nftables获取流量统计
        local table_name="traffic_monitor"
        
        # 获取入站流量
        local in_tcp=$(sudo nft -a list table inet $table_name | grep "tcp dport $port counter packets" | grep -oP 'bytes \K[0-9]+' || echo 0)
        local in_udp=$(sudo nft -a list table inet $table_name | grep "udp dport $port counter packets" | grep -oP 'bytes \K[0-9]+' || echo 0)
        
        # 获取出站流量
        local out_tcp=$(sudo nft -a list table inet $table_name | grep "tcp sport $port counter packets" | grep -oP 'bytes \K[0-9]+' || echo 0)
        local out_udp=$(sudo nft -a list table inet $table_name | grep "udp sport $port counter packets" | grep -oP 'bytes \K[0-9]+' || echo 0)
        
        bytes_in=$((in_tcp + in_udp))
        bytes_out=$((out_tcp + out_udp))
        
    else
        # 使用传统iptables
        local chain_name="TRACK_PORT_$port"
        
        bytes_in=$(sudo iptables -L INPUT -v -n -x | grep "dport $port" | awk '{sum+=$2} END {print sum}')
        bytes_out=$(sudo iptables -L OUTPUT -v -n -x | grep "sport $port" | awk '{sum+=$2} END {print sum}')
        
        # 如果没有获取到值，设为0
        bytes_in=${bytes_in:-0}
        bytes_out=${bytes_out:-0}
    fi
    
    echo "$bytes_in $bytes_out"
}

# 函数: 检查流量使用情况
check_traffic() {
    local port=$1
    local limit_gb=$2
    local start_date=$3
    local user_name=$4
    local log_file="$LOG_DIR/port${port}_${user_name}.log"
    
    # 确保日志文件存在
    touch $log_file
    
    # 计算自开始日期以来的天数
    local days_running=$(days_between $start_date)
    
    # 获取流量统计
    local stats=$(get_traffic_stats $port)
    local bytes_in=$(echo $stats | cut -d' ' -f1)
    local bytes_out=$(echo $stats | cut -d' ' -f2)
    local total_bytes=$((bytes_in + bytes_out))
    
    # 转换为GB
    local limit_bytes=$((limit_gb * 1024 * 1024 * 1024))
    local total_gb=$(echo "scale=2; $total_bytes/1024/1024/1024" | bc)
    
    # 确保小数点前有0
    if [[ $total_gb =~ ^\. ]]; then
        total_gb="0$total_gb"
    fi
    

    # 计算使用百分比
    local usage_percent=0
    if [ $limit_bytes -gt 0 ]; then
        usage_percent=$(echo "scale=2; $total_bytes*100/$limit_bytes" | bc)
        
        # 确保小数点前有0
        if [[ $usage_percent =~ ^\. ]]; then
            usage_percent="0$usage_percent"
        fi
    fi
    
    # 计算每日平均使用量
    local daily_avg_gb="0"
    if [ $days_running -gt 0 ]; then
        daily_avg_gb=$(echo "scale=2; $total_gb/$days_running" | bc)
        # 确保小数点前有0
        if [[ $daily_avg_gb =~ ^\. ]]; then
            daily_avg_gb="0$daily_avg_gb"
        fi
    fi
    
    # 估计剩余天数
    local remaining_gb=$(echo "scale=2; $limit_gb - $total_gb" | bc)
    local days_left="无限制"
    
    # 检查daily_avg_gb是否大于0
    if [ $(echo "$daily_avg_gb > 0" | bc) -eq 1 ]; then
        days_left=$(echo "scale=0; $remaining_gb/$daily_avg_gb" | bc)
    fi
    
    # 记录使用情况
    echo "$(date '+%Y-%m-%d %H:%M:%S'): 用户: $user_name, 端口: $port, 已用流量: ${total_gb}GB/${limit_gb}GB (${usage_percent}%), 运行天数: ${days_running}, 每日平均: ${daily_avg_gb}GB, 预计可用天数: ${days_left}" >> $log_file
    
    # 显示当前状态
    echo "用户: $user_name"
    echo "端口: $port"
    echo "统计开始日期: $start_date (已运行 $days_running 天)"
    echo "流量使用: ${total_gb}GB / ${limit_gb}GB (${usage_percent}%)"
    echo "每日平均使用: ${daily_avg_gb}GB"
    #echo "按当前使用速率，剩余流量可用天数: ${days_left}"
    
    # 检查是否超出限制
    if [ $(echo "$total_bytes > $limit_bytes" | bc) -eq 1 ]; then
        echo "⚠️ 警告: 流量已超出限制!" | tee -a $log_file
        return 1
    fi
    
    # 检查是否接近限制 (>80%)
    if [ $(echo "$usage_percent > 80" | bc) -eq 1 ]; then
        echo "⚠️ 注意: 流量使用已超过80%!" | tee -a $log_file
    fi
    
    return 0
}

# 函数: 显示所有端口的流量状态
show_all_traffic() {
    echo "===== 流量监控状态报告 ====="
    echo "当前时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "----------------------------------"
    
    # 读取配置文件中的每一行
    while IFS=: read -r port limit_gb start_date user_name || [[ -n "$port" ]]; do
        # 跳过注释和空行
        [[ $port =~ ^#.*$ || -z $port ]] && continue
        
        echo "[监控 $user_name]"
        check_traffic $port $limit_gb $start_date "$user_name"
        echo "----------------------------------"
    done < $CONFIG_FILE
}

# 函数: 添加新的端口监控
add_port_monitor() {
    local port=$1
    local limit_gb=$2
    local start_date=$3
    local user_name=$4
    
    # 验证输入
    if ! [[ $port =~ ^[0-9]+$ ]] || [ $port -lt 1 ] || [ $port -gt 65535 ]; then
        echo "错误: 无效的端口号 (必须是1-65535之间的数字)"
        return 1
    fi
    
    if ! [[ $limit_gb =~ ^[0-9]+$ ]]; then
        echo "错误: 无效的流量限制 (必须是整数GB)"
        return 1
    fi
    
    if ! date -d "$start_date" >/dev/null 2>&1; then
        echo "错误: 无效的日期格式 (应为YYYY-MM-DD)"
        return 1
    fi
    
    # 添加到配置文件
    echo "$port:$limit_gb:$start_date:$user_name" >> $CONFIG_FILE
    echo "已添加新的监控: 端口=$port, 限制=${limit_gb}GB, 开始日期=$start_date, 用户=$user_name"
    
    # 设置监控规则
    setup_monitoring $port
    
    # 重置计数器
    check_reset_needed $port $start_date
}

# 函数: 修改现有端口监控
modify_port_monitor() {
    local port=$1
    local limit_gb=$2
    local start_date=$3
    local user_name=$4
    
    # 创建临时文件
    local temp_file=$(mktemp)
    
    # 标记是否找到匹配项
    local found=0
    
    # 读取原始文件，修改匹配行
    while IFS= read -r line; do
        if [[ $line =~ ^$port: ]]; then
            echo "$port:$limit_gb:$start_date:$user_name" >> $temp_file
            found=1
        else
            echo "$line" >> $temp_file
        fi
    done < $CONFIG_FILE
    
    if [ $found -eq 0 ]; then
        echo "错误: 未找到端口 $port 的监控配置"
        rm $temp_file
        return 1
    fi
    
    # 替换原始文件
    cat $temp_file > $CONFIG_FILE
    rm $temp_file
    
    echo "已修改端口 $port 的配置: 限制=${limit_gb}GB, 开始日期=$start_date, 用户=$user_name"
    
    # 检查是否需要重置计数器
    check_reset_needed $port $start_date
}

# 函数: 删除端口监控
delete_port_monitor() {
    local port=$1
    
    # 创建临时文件
    local temp_file=$(mktemp)
    
    # 标记是否找到匹配项
    local found=0
    
    # 读取原始文件，跳过匹配行
    while IFS= read -r line; do
        if [[ $line =~ ^$port: ]]; then
            found=1
        else
            echo "$line" >> $temp_file
        fi
    done < $CONFIG_FILE
    
    if [ $found -eq 0 ]; then
        echo "错误: 未找到端口 $port 的监控配置"
        rm $temp_file
        return 1
    fi
    
    # 替换原始文件
    cat $temp_file > $CONFIG_FILE
    rm $temp_file
    
    echo "已删除端口 $port 的监控配置"
    
    if [ $USE_NFT -eq 1 ]; then
        # 使用nftables
        local table_name="traffic_monitor"
        local chain_name="port_$port"
        
        # 找到并删除相关规则
        for handle in $(sudo nft -a list table inet $table_name | grep "dport $port" | grep -o "handle [0-9]*" | awk '{print $2}'); do
            sudo nft delete rule inet $table_name input handle $handle 2>/dev/null
        done
        
        for handle in $(sudo nft -a list table inet $table_name | grep "sport $port" | grep -o "handle [0-9]*" | awk '{print $2}'); do
            sudo nft delete rule inet $table_name output handle $handle 2>/dev/null
        done
        
        # 删除链
        sudo nft delete chain inet $table_name $chain_name 2>/dev/null
    else
        # 使用传统iptables
        local chain_name="TRACK_PORT_$port"
        
        # 移除指向链的规则
        sudo iptables -D INPUT -p tcp --dport $port -j $chain_name 2>/dev/null
        sudo iptables -D INPUT -p udp --dport $port -j $chain_name 2>/dev/null
        sudo iptables -D OUTPUT -p tcp --sport $port -j $chain_name 2>/dev/null
        sudo iptables -D OUTPUT -p udp --sport $port -j $chain_name 2>/dev/null
        
        # 清空链
        sudo iptables -F $chain_name 2>/dev/null
        
        # 删除链
        sudo iptables -X $chain_name 2>/dev/null
    fi
    
    echo "已删除端口 $port 的流量监控规则"
}

# 函数: 初始化nftables
initialize_nftables() {
    local table_name="traffic_monitor"
    
    # 检查表是否存在，如果不存在则创建
    if ! sudo nft list table inet $table_name &>/dev/null; then
        echo "创建nftables表"
        sudo nft add table inet $table_name
        
        # 创建基础链
        sudo nft add chain inet $table_name input { type filter hook input priority 0 \; }
        sudo nft add chain inet $table_name output { type filter hook output priority 0 \; }
        
        echo "nftables基础结构已初始化"
    fi
}

# 函数: 重置所有计数器
reset_all_counters() {
    echo "正在重置所有端口的流量计数器..."
    
    if [ $USE_NFT -eq 1 ]; then
        # 使用nftables
        initialize_nftables
    fi
    
    # 读取配置文件中的每一行
    while IFS=: read -r port limit_gb start_date user_name || [[ -n "$port" ]]; do
        # 跳过注释和空行
        [[ $port =~ ^#.*$ || -z $port ]] && continue
        
        # 重置该端口的计数器
        reset_counter $port
        
        # 更新重置标志文件
        local reset_flag_file="$LOG_DIR/port${port}_reset_${start_date}"
        touch $reset_flag_file
        
        echo "端口 $port ($user_name) 的计数器已重置"
    done < $CONFIG_FILE
    
    echo "所有计数器重置完成"
}

# 函数: 设置所有端口的监控
setup_all_monitoring() {
    echo "正在设置所有端口的流量监控..."
    
    if [ $USE_NFT -eq 1 ]; then
        # 使用nftables
        initialize_nftables
    fi
    
    # 读取配置文件中的每一行
    while IFS=: read -r port limit_gb start_date user_name || [[ -n "$port" ]]; do
        # 跳过注释和空行
        [[ $port =~ ^#.*$ || -z $port ]] && continue
        
        setup_monitoring $port
        check_reset_needed $port $start_date
    done < $CONFIG_FILE
    
    echo "所有端口的流量监控已设置"
    
    if [ $USE_NFT -eq 1 ]; then
        echo "提示: 要使nftables规则在重启后仍然生效，请运行: sudo nft list ruleset > /etc/nftables.conf"
    else
        echo "提示: 要使iptables规则在重启后仍然生效，请运行: sudo apt install iptables-persistent && sudo netfilter-persistent save"
    fi
}

# 函数: 显示帮助信息
show_help() {
    echo "流量监控脚本使用方法:"
    echo "  $0                           - 显示所有监控端口的流量状态"
    echo "  $0 status [端口]             - 显示指定端口的流量状态"
    echo "  $0 add 端口 限额GB 开始日期 用户名 - 添加新的端口监控"
    echo "  $0 modify 端口 限额GB 开始日期 用户名 - 修改现有端口监控"
    echo "  $0 delete 端口               - 删除指定端口的监控"
    echo "  $0 reset [端口]              - 重置指定端口或所有端口的计数器"
    echo "  $0 setup                     - 重新设置所有端口的监控规则"
    echo "  $0 help                      - 显示此帮助信息"
    echo ""
    echo "例子:"
    echo "  $0 add 22 10 2025-02-25 ssh用户    - 添加对端口22的监控，限额10GB"
    echo "  $0 status 80                      - 查看端口80的流量状态"
    echo "  $0 reset 443                      - 重置端口443的流量计数器"
}

# 主函数
main() {
    # 检查是否有root权限
    if [ "$(id -u)" -ne 0 ]; then
        echo "错误: 此脚本需要root权限才能运行"
        echo "请使用 'sudo $0' 重新运行"
        exit 1
    fi
    
    # 检查依赖
    check_dependencies
    
    # 默认命令
    local command=${1:-"status"}
    
    case $command in
        status)
            if [ -z "$2" ]; then
                show_all_traffic
            else
                # 查找指定端口的配置
                local found=0
                while IFS=: read -r port limit_gb start_date user_name || [[ -n "$port" ]]; do
                    # 跳过注释和空行
                    [[ $port =~ ^#.*$ || -z $port ]] && continue
                    
                    if [ "$port" == "$2" ]; then
                        check_traffic $port $limit_gb $start_date "$user_name"
                        found=1
                        break
                    fi
                done < $CONFIG_FILE
                
                if [ $found -eq 0 ]; then
                    echo "错误: 未找到端口 $2 的监控配置"
                    exit 1
                fi
            fi
            ;;
        
        add)
            if [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ] || [ -z "$5" ]; then
                echo "错误: 添加端口监控需要指定端口、限额、开始日期和用户名"
                show_help
                exit 1
            fi
            add_port_monitor $2 $3 $4 "$5"
            ;;
        
        modify)
            if [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ] || [ -z "$5" ]; then
                echo "错误: 修改端口监控需要指定端口、限额、开始日期和用户名"
                show_help
                exit 1
            fi
            modify_port_monitor $2 $3 $4 "$5"
            ;;
        
        delete)
            if [ -z "$2" ]; then
                echo "错误: 删除端口监控需要指定端口"
                show_help
                exit 1
            fi
            delete_port_monitor $2
            ;;
        
        reset)
            if [ -z "$2" ]; then
                reset_all_counters
            else
                # 重置指定端口的计数器
                reset_counter $2
                
                # 更新重置标志文件
                # 查找指定端口的配置
                while IFS=: read -r port limit_gb start_date user_name || [[ -n "$port" ]]; do
                    # 跳过注释和空行
                    [[ $port =~ ^#.*$ || -z $port ]] && continue
                    
                    if [ "$port" == "$2" ]; then
                        local reset_flag_file="$LOG_DIR/port${port}_reset_${start_date}"
                        touch $reset_flag_file
                        echo "端口 $port 的计数器已重置"
                        break
                    fi
                done < $CONFIG_FILE
            fi
            ;;
        
        setup)
            setup_all_monitoring
            ;;
        
        help)
            show_help
            ;;
        
        *)
            echo "错误: 未知命令 '$command'"
            show_help
            exit 1
            ;;
    esac
}

# 运行主函数
main "$@"
