#!/bin/bash
set -e

CN_URL="https://raw.githubusercontent.com/gaoyifan/china-operator-ip/ip-lists/china.txt"
CN_FILE="/tmp/china.txt"

echo -e "\n📌 请选择操作类型："
echo "1) 添加屏蔽规则"
echo "2) 查看并解除屏蔽规则"
read -p "输入选项编号: " MODE

# ------------------- 查看并解除规则 -------------------
if [[ "$MODE" == "2" ]]; then
    echo -e "\n📌 请选择解除方式："
    echo "1) 查看并解除所有 geo_filter 屏蔽规则"
    echo "2) 查看并解除指定端口的 geo_filter 屏蔽规则"
    read -p "输入选项编号: " SUBMODE

    if [[ "$SUBMODE" == "1" ]]; then
        echo "📋 当前 geo_filter 所有屏蔽规则如下："
        nft list chain inet geo_filter input || { echo "❌ 无规则或链不存在"; exit 1; }

        read -p "确认是否清除所有规则？(y/n): " CONFIRM
        if [[ "$CONFIRM" == "y" ]]; then
            nft flush chain inet geo_filter input 2>/dev/null || true
            echo "✅ 已清除 geo_filter 所有屏蔽规则"

            read -p "是否同时清除 IP 列表？(y/n): " CLEAR_SET
            if [[ "$CLEAR_SET" == "y" ]]; then
                nft flush set inet geo_filter cn_ipv4 2>/dev/null || true
                echo "✅ 已清空 cn_ipv4 IP 列表"
            fi
        else
            echo "❎ 操作取消"
        fi
        exit 0
    fi

    if [[ "$SUBMODE" == "2" ]]; then
        echo "📋 当前 geo_filter 屏蔽规则如下（含 handle）："
        nft -a list chain inet geo_filter input | grep 'dport' || { echo "❌ 未找到相关规则"; exit 1; }

        read -p "请输入要解除屏蔽的端口号（多个端口用英文逗号分隔）: " PORTS
        IFS=',' read -ra PORT_ARR <<< "$PORTS"

        for port in "${PORT_ARR[@]}"; do
            port_trimmed=$(echo "$port" | xargs)
            HANDLES=$(nft -a list chain inet geo_filter input | grep "dport $port_trimmed" | grep drop | awk -F 'handle ' '{print $2}')
            for h in $HANDLES; do
                echo "❎ 删除规则: dport $port_trimmed handle $h"
                nft delete rule inet geo_filter input handle "$h"
            done
        done
        echo "✅ 指定端口的 geo_filter 屏蔽规则已解除"
        exit 0
    fi

    echo "❌ 无效选项"
    exit 1
fi

# ------------------- 添加屏蔽规则 -------------------
echo -e "\n📌 请选择要屏蔽的 IP 类型："
echo "1) 屏蔽中国大陆 IP"
echo "2) 屏蔽非中国 IP"
read -p "输入选项编号: " ip_type

echo -e "\n📌 请选择屏蔽范围："
echo "1) 屏蔽指定端口（多个端口用英文逗号分隔）"
echo "2) 屏蔽全部端口"
read -p "输入选项编号: " scope

if [[ "$scope" == "1" ]]; then
    read -p "请输入要屏蔽的端口号（多个端口用英文逗号分隔）: " PORTS
    IFS=',' read -ra PORT_ARR <<< "$PORTS"
fi

echo -e "\n📥 正在下载中国大陆 IP 列表..."
curl -sSL "$CN_URL" -o "$CN_FILE"
if [ ! -s "$CN_FILE" ]; then
    echo "❌ 无法获取中国 IP 数据，退出。"
    exit 1
fi
echo "✅ 获取成功，共 $(wc -l < "$CN_FILE") 条 IP 段"

nft list table inet geo_filter &>/dev/null || nft add table inet geo_filter
nft list set inet geo_filter cn_ipv4 &>/dev/null || nft add set inet geo_filter cn_ipv4 { \
    type ipv4_addr; \
    flags interval; \
    auto-merge; \
}

nft flush set inet geo_filter cn_ipv4
while read -r ip; do
    nft add element inet geo_filter cn_ipv4 { $ip }
done < "$CN_FILE"
echo "✅ 已更新 cn_ipv4 列表"

nft list chain inet geo_filter input &>/dev/null || nft add chain inet geo_filter input { \
    type filter hook input priority 0\; policy accept\; }

if [[ "$scope" == "2" ]]; then
    if [[ "$ip_type" == "1" ]]; then
        rule_str="ip saddr @cn_ipv4 drop"
    else
        rule_str="ip saddr != @cn_ipv4 drop"
    fi
    nft list chain inet geo_filter input | grep -q "$rule_str" || nft add rule inet geo_filter input $rule_str
else
    for port in "${PORT_ARR[@]}"; do
        port_trimmed=$(echo "$port" | xargs)
        if [[ "$ip_type" == "1" ]]; then
            rule_str="ip saddr @cn_ipv4 tcp dport $port_trimmed drop"
        else
            rule_str="ip saddr != @cn_ipv4 tcp dport $port_trimmed drop"
        fi
        nft list chain inet geo_filter input | grep -q "$rule_str" || nft add rule inet geo_filter input $rule_str
    done
fi

echo -e "\n✅ 已成功添加 geo_filter 屏蔽规则，不影响原有规则"

echo -e "\n💾 正在保存规则..."
nft list ruleset > /etc/nftables.conf
echo "✅ 规则已保存到 /etc/nftables.conf"
