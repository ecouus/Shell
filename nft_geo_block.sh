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

# === 构建 IP SET ===
CN_SET="        elements = {\n"
while read -r ip; do
    CN_SET+="            $ip,\n"
done < "$CN_FILE"
CN_SET=${CN_SET%,\\n}
CN_SET+="\n        }"

# === 构建 RULES ===
RULES=""
if [[ "$scope" == "2" ]]; then
    if [[ "$ip_type" == "1" ]]; then
        RULES="ip saddr @cn_ipv4 drop"
    else
        RULES="ip saddr != @cn_ipv4 drop"
    fi
else
    for port in "${PORT_ARR[@]}"; do
        port_trimmed=$(echo "$port" | xargs)
        if [[ "$ip_type" == "1" ]]; then
            RULES+="ip saddr @cn_ipv4 tcp dport $port_trimmed drop\n        "
        else
            RULES+="ip saddr != @cn_ipv4 tcp dport $port_trimmed drop\n        "
        fi
    done
fi

# === 写入 nftables 配置文件 ===
cat > "$NFT_CONF" <<EOF
table inet geo_filter {
    set cn_ipv4 {
        type ipv4_addr
        flags interval
        auto-merge
$CN_SET
    }

    chain input {
        type filter hook input priority 0; policy accept;

        $RULES
    }
}
EOF

# === 应用规则 ===
echo "🚀 应用 nftables 规则..."
nft flush ruleset
nft -f "$NFT_CONF"
echo "✅ 已成功写入并应用规则到 nftables。"
