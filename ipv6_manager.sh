#!/bin/bash

# IPv6管理脚本
# 功能：显示当前IPv6状态，禁用/启用IPv6，设置IPv4优先

# 设置颜色
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
NC="\033[0m" # 恢复默认颜色

# 确保以root权限运行
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}错误：请以root权限运行此脚本${NC}"
    echo "使用: sudo $0"
    exit 1
fi

# 检查必要的命令是否存在
check_commands() {
    for cmd in ip sysctl grep sed; do
        if ! command -v $cmd &> /dev/null; then
            echo -e "${RED}错误：命令 '$cmd' 未找到。请安装必要的软件包。${NC}"
            exit 1
        fi
    done
    
    # 检查可选命令
    if ! command -v curl &> /dev/null; then
        echo -e "${YELLOW}提示: 未安装curl，某些功能将受限。建议安装: apt install curl${NC}"
        sleep 2
    fi
}

# 显示当前状态和IP地址
show_status() {
    echo -e "${BLUE}========== 系统IPv6状态 ==========${NC}"
    
    # 检查IPv6是否被禁用
    if [ "$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6 2>/dev/null)" -eq 1 ] 2>/dev/null; then
        echo -e "当前状态: ${RED}IPv6 已禁用${NC}"
    else
        echo -e "当前状态: ${GREEN}IPv6 已启用${NC}"
    fi
    
    # 检查IPv4是否优先
    if grep -q "precedence ::ffff:0:0/96  100" /etc/gai.conf 2>/dev/null; then
        echo -e "优先级设置: ${YELLOW}IPv4 优先${NC}"
    else
        echo -e "优先级设置: ${BLUE}默认设置（通常IPv6优先）${NC}"
    fi
    
    # 检查是否安装了curl
    if command -v curl &> /dev/null; then
        echo -e "\n${YELLOW}----- 公网IP地址 -----${NC}"
        echo -n "IPv4公网地址: "
        IPv4=$(curl -s -4 -m 5 ifconfig.me 2>/dev/null || curl -s -4 -m 5 api.ipify.org 2>/dev/null || curl -s -4 -m 5 ip.sb 2>/dev/null || echo "获取失败")
        echo "$IPv4"
        
        # 如果IPv6未禁用，尝试获取IPv6公网地址
        if [ "$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6 2>/dev/null)" != "1" ] 2>/dev/null; then
            echo -n "IPv6公网地址: "
            IPv6=$(curl -s -6 -m 5 ifconfig.me 2>/dev/null || curl -s -6 -m 5 api.ipify.org 2>/dev/null || curl -s -6 -m 5 ip.sb 2>/dev/null || echo "获取失败")
            echo "$IPv6"
        fi
    else
        echo -e "\n${YELLOW}提示: 安装curl可获取公网IP地址 (apt install curl)${NC}"
    fi
    
    echo -e "\n${YELLOW}----- 本地IP地址 -----${NC}"
    echo -e "${GREEN}IPv4地址:${NC}"
    ip -4 addr | grep -w inet | awk '{print "  " $2 " (" $NF ")"}'
    
    # 如果IPv6未禁用，显示IPv6地址
    if [ "$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6 2>/dev/null)" != "1" ] 2>/dev/null; then
        echo -e "\n${GREEN}IPv6地址:${NC}"
        ip -6 addr | grep -w inet6 | awk '{print "  " $2 " (" $NF ")"}'
    fi
    
    echo -e "\n${BLUE}================================${NC}"
}

# 禁用IPv6
disable_ipv6() {
    echo -e "${YELLOW}正在禁用IPv6...${NC}"
    
    # 临时禁用
    sysctl -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null 2>&1
    sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null 2>&1
    sysctl -w net.ipv6.conf.lo.disable_ipv6=1 >/dev/null 2>&1
    
    # 永久禁用
    mkdir -p /etc/sysctl.d
    cat > /etc/sysctl.d/99-disable-ipv6.conf << EOF
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
    
    # 应用设置
    sysctl -p /etc/sysctl.d/99-disable-ipv6.conf >/dev/null 2>&1
    
    echo -e "${GREEN}IPv6 已禁用${NC}"
}

# 启用IPv6
enable_ipv6() {
    echo -e "${YELLOW}正在启用IPv6...${NC}"
    
    # 临时启用
    sysctl -w net.ipv6.conf.all.disable_ipv6=0 >/dev/null 2>&1
    sysctl -w net.ipv6.conf.default.disable_ipv6=0 >/dev/null 2>&1
    sysctl -w net.ipv6.conf.lo.disable_ipv6=0 >/dev/null 2>&1
    
    # 移除禁用配置
    if [ -f /etc/sysctl.d/99-disable-ipv6.conf ]; then
        rm -f /etc/sysctl.d/99-disable-ipv6.conf
    fi
    
    # 应用设置
    sysctl -p >/dev/null 2>&1
    
    echo -e "${GREEN}IPv6 已启用${NC}"
}

# 设置IPv4优先
set_ipv4_priority() {
    echo -e "${YELLOW}正在设置IPv4优先...${NC}"
    
    # 确保gai.conf存在
    mkdir -p /etc
    touch /etc/gai.conf
    
    # 备份原文件
    cp /etc/gai.conf /etc/gai.conf.bak.$(date +%Y%m%d%H%M%S)
    
    # 设置IPv4优先
    if ! grep -q "precedence ::ffff:0:0/96  100" /etc/gai.conf; then
        echo "# 设置IPv4地址优先于IPv6地址" >> /etc/gai.conf
        echo "precedence ::ffff:0:0/96  100" >> /etc/gai.conf
    fi
    
    echo -e "${GREEN}IPv4优先已设置${NC}"
}

# 关闭IPv4优先
disable_ipv4_priority() {
    echo -e "${YELLOW}正在关闭IPv4优先设置...${NC}"
    
    # 检查gai.conf是否存在
    if [ -f /etc/gai.conf ]; then
        # 备份原文件
        cp /etc/gai.conf /etc/gai.conf.bak.$(date +%Y%m%d%H%M%S)
        
        # 移除IPv4优先设置
        sed -i '/precedence ::ffff:0:0\/96  100/d' /etc/gai.conf
        sed -i '/# 设置IPv4地址优先于IPv6地址/d' /etc/gai.conf
    fi
    
    echo -e "${GREEN}IPv4优先设置已关闭，系统将使用默认优先级（通常IPv6优先）${NC}"
}

# 显示网络测试
network_test() {
    echo -e "${BLUE}========== 网络连接测试 ==========${NC}"
    
    echo -e "\n${YELLOW}测试IPv4连接...${NC}"
    if ping -c 3 -4 www.google.com > /dev/null 2>&1; then
        echo -e "${GREEN}IPv4连接正常${NC}"
        
        # 获取IPv4延迟
        echo -e "\n${YELLOW}IPv4延迟测试:${NC}"
        ping -c 3 -4 www.google.com | grep -oP 'time=\K[0-9.]+'
        
        # 显示IPv4路由
        echo -e "\n${YELLOW}IPv4默认路由:${NC}"
        ip -4 route | grep default
    else
        echo -e "${RED}IPv4连接失败${NC}"
    fi
    
    # 如果IPv6已启用，测试IPv6连接
    if [ "$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6 2>/dev/null)" != "1" ] 2>/dev/null; then
        echo -e "\n${YELLOW}测试IPv6连接...${NC}"
        if ping -c 3 -6 ipv6.google.com > /dev/null 2>&1; then
            echo -e "${GREEN}IPv6连接正常${NC}"
            
            # 获取IPv6延迟
            echo -e "\n${YELLOW}IPv6延迟测试:${NC}"
            ping -c 3 -6 ipv6.google.com | grep -oP 'time=\K[0-9.]+'
            
            # 显示IPv6路由
            echo -e "\n${YELLOW}IPv6默认路由:${NC}"
            ip -6 route | grep default
        else
            echo -e "${RED}IPv6连接失败${NC}"
        fi
    fi
    
    # 检查DNS解析
    echo -e "\n${YELLOW}DNS解析测试:${NC}"
    if command -v dig &> /dev/null; then
        echo -e "使用dig测试..."
        dig +short www.google.com
    elif command -v nslookup &> /dev/null; then
        echo -e "使用nslookup测试..."
        nslookup www.google.com | grep -A2 'Name:'
    else
        echo -e "${RED}未安装DNS测试工具 (dig 或 nslookup)${NC}"
        echo -e "可通过 ${GREEN}apt install dnsutils${NC} 安装"
    fi
    
    echo -e "\n${BLUE}================================${NC}"
    read -p "按Enter键继续..."
}

# 主菜单
menu() {
    clear
    show_status
    echo -e "\n${YELLOW}请选择操作:${NC}"
    echo "1. 一键禁用IPv6"
    echo "2. 一键启用IPv6"
    echo "3. 设置IPv4优先"
    echo "4. 关闭IPv4优先"
    echo "5. 网络连接测试"
    echo "0. 退出脚本"
    
    read -p "请输入选项 [0-5]: " choice
    
    case $choice in
        1) disable_ipv6; sleep 2; menu ;;
        2) enable_ipv6; sleep 2; menu ;;
        3) set_ipv4_priority; sleep 2; menu ;;
        4) disable_ipv4_priority; sleep 2; menu ;;
        5) network_test; menu ;;
        0) echo -e "${GREEN}感谢使用，再见！${NC}"; exit 0 ;;
        *) echo -e "${RED}无效选项，请重新选择${NC}"; sleep 2; menu ;;
    esac
}

# 检查必要的命令
check_commands

# 启动脚本
menu

# 启动脚本
menu
