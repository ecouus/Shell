#!/bin/bash

# === 配置变量 ===
CN_URL="https://raw.githubusercontent.com/gaoyifan/china-operator-ip/ip-lists/china.txt"
CN_FILE="/tmp/china.txt"
NFT_CONF="/etc/nftables.geo.conf"

echo "📌 请选择要屏蔽的 IP 类型："
echo "1) 屏蔽中国大陆 IP"
echo "2) 屏蔽非中国 IP"
read -p "输入选项编号: " ip_type

echo "📌 请选择屏蔽范围："
echo "1) 屏蔽指定端口（可用英文逗号分隔多个端口）"
echo "2) 屏蔽全部端口"
read -p "输入选项编号: " scope

if [[ "$scope" == "1" ]]; then
    read -p "请输入要屏蔽的端口号（多个端口用英文逗号分隔）: " PORTS
    IFS=',' read -ra PORT_ARR <<< "$PORTS"
fi

# === 下载中国 IP ===
echo "📥 正在下载中国大陆 IP 列表..."
curl -sSL "$CN_URL" -o "$CN_FILE"
if [ ! -s "$CN_FILE" ]; then
    echo "❌ 无法获取中国 IP 数据，退出。"
    exit 1
fi
echo "✅ 获取成功，共 $(wc -l < "$CN_FILE") 条 IP 段"

# === 写入 nftables 配置文件 ===
echo "table inet geo_filter {" > "$NFT_CONF"
echo "    set cn_ipv4 {" >> "$NFT_CONF"
echo "        type ipv4_addr" >> "$NFT_CONF"
echo "        flags interval" >> "$NFT_CONF"
echo "        auto-merge" >> "$NFT_CONF"
echo "        elements = {" >> "$NFT_CONF"
while read -r ip; do
    echo "            $ip," >> "$NFT_CONF"
done < "$CN_FILE"
# 删除最后一行的逗号
sed -i '$ s/,$//' "$NFT_CONF"
echo "        }" >> "$NFT_CONF"
echo "    }" >> "$NFT_CONF"

# === 写入规则 chain ===
echo "" >> "$NFT_CONF"
echo "    chain input {" >> "$NFT_CONF"
echo "        type filter hook input priority 0; policy accept;" >> "$NFT_CONF"

if [[ "$scope" == "2" ]]; then
    if [[ "$ip_type" == "1" ]]; then
        echo "        ip saddr @cn_ipv4 drop" >> "$NFT_CONF"
    else
        echo "        ip saddr != @cn_ipv4 drop" >> "$NFT_CONF"
    fi
else
    for port in "${PORT_ARR[@]}"; do
        port_trimmed=$(echo "$port" | xargs)
        if [[ "$ip_type" == "1" ]]; then
            echo "        ip saddr @cn_ipv4 tcp dport $port_trimmed drop" >> "$NFT_CONF"
        else
            echo "        ip saddr != @cn_ipv4 tcp dport $port_trimmed drop" >> "$NFT_CONF"
        fi
    done
fi

echo "    }" >> "$NFT_CONF"
echo "}" >> "$NFT_CONF"

# === 应用规则 ===
echo "🚀 应用 nftables 规则..."
nft flush ruleset
nft -f "$NFT_CONF"
echo "✅ 已成功写入并应用规则到 nftables。"
