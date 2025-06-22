#!/bin/bash
set -e

# ---------- 一级菜单 ----------
echo -e "\n📌 请选择操作类型："
echo "1) 添加屏蔽规则"
echo "2) 查看并解除屏蔽规则"
read -p "输入选项编号: " MODE

# ---------- 二级菜单：查看并解除 ----------
if [[ "$MODE" == "2" ]]; then
    echo -e "\n📌 请选择解除方式："
    echo "1) 查看并解除所有 geo_filter 屏蔽规则"
    echo "2) 查看并解除指定端口的 geo_filter 屏蔽规则"
    read -p "输入选项编号: " SUBMODE

    # === 模式 1：全部解除 ===
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

    # === 模式 2：解除指定端口 ===
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
