#!/bin/bash

# === 配置变量 ===
CN_URL="https://raw.githubusercontent.com/gaoyifan/china-operator-ip/ip-lists/china.txt"
CN_FILE="/tmp/china.txt"
PORTS=()

echo "📌 请选择要屏蔽的 IP 类型："
echo "1) 屏蔽中国大陆 IP"
echo "2) 屏蔽非中国 IP"
read -p "输入选项编号: " ip_type

echo "📌 请选择屏蔽范围："
echo "1) 屏蔽指定端口（可用英文逗号分隔多个端口）"
echo "2) 屏蔽全部端口"
read -p "输入选项编号: " scope

if [[ "$scope" == "1" ]]; then
    read -p "请输入要屏蔽的端口号（多个端口用英文逗号分隔）: " PORT_STR
    IFS=',' read -ra PORTS <<< "$PORT_STR"
fi

# === 下载中国 IP ===
echo "📥 正在下载中国大陆 IP 列表..."
curl -sSL "$CN_URL" -o "$CN_FILE"
if [ ! -s "$CN_FILE" ]; then
    echo "❌ 下载失败，退出。"
    exit 1
fi

# === 创建 geo_filter 表及 cn_ipv4 set（如果不存在） ===
nft list table inet geo_filter &>/dev/null || nft add table inet geo_filter
nft list set inet geo_filter cn_ipv4 &>/dev/null || \
    nft add set inet geo_filter cn_ipv4 { type ipv4_addr; flags interval; auto-merge; }

# === 清空原 cn_ipv4 set 并重新添加 ===
nft flush set inet geo_filter cn_ipv4

while read -r ip; do
    nft add element inet geo_filter cn_ipv4 { $ip }
done < "$CN_FILE"

# === 创建 input 链（如果不存在） ===
nft list chain inet geo_filter input &>/dev/null || \
    nft add chain inet geo_filter input { type filter hook input priority 0\; }

# === 添加规则 ===
for port in "${PORTS[@]}"; do
    port_trimmed=$(echo "$port" | xargs)
    if [[ "$ip_type" == "1" ]]; then
        nft add rule inet geo_filter input ip saddr @cn_ipv4 tcp dport "$port_trimmed" drop
    else
        nft add rule inet geo_filter input ip saddr != @cn_ipv4 tcp dport "$port_trimmed" drop
    fi
done

# === 全端口屏蔽 ===
if [[ "$scope" == "2" ]]; then
    if [[ "$ip_type" == "1" ]]; then
        nft add rule inet geo_filter input ip saddr @cn_ipv4 drop
    else
        nft add rule inet geo_filter input ip saddr != @cn_ipv4 drop
    fi
fi

echo "✅ 已完成 geo_filter 规则添加，不影响其他表。"
