#!/bin/bash

set -e

# 检查并安装 nftables
if ! command -v nft &>/dev/null; then
    echo "❗未检测到 nftables，正在安装..."
    apt update && apt install -y nftables
    systemctl enable nftables
    systemctl start nftables
fi

# 保证 NAT 表和链存在
ensure_nat_table_exists() {
  if ! nft list table ip nat >/dev/null 2>&1; then
    echo "✅ 正在创建 NAT 表..."
    nft add table ip nat
  fi

  if ! nft list chain ip nat prerouting >/dev/null 2>&1; then
    echo "✅ 创建 prerouting 链..."
    nft add chain ip nat prerouting { type nat hook prerouting priority 0\; }
  fi

  if ! nft list chain ip nat postrouting >/dev/null 2>&1; then
    echo "✅ 创建 postrouting 链..."
    nft add chain ip nat postrouting { type nat hook postrouting priority 100\; }
  fi
}




# 添加端口转发规则
add_rule() {
    ensure_nat_table_exists
    sleep 0.2 

    read -p "请输入本地监听端口: " LPORT
    read -p "请输入目标 IP: " DIP
    read -p "请输入目标端口: " DPORT

    # ✅ 参数校验
    [[ "$LPORT" =~ ^[0-9]+$ ]] || { echo "❌ 本地端口无效"; return; }
    [[ "$DPORT" =~ ^[0-9]+$ ]] || { echo "❌ 目标端口无效"; return; }
    # 端口范围校验（必须 1~65535）
    if ! [[ "$LPORT" -ge 1 && "$LPORT" -le 65535 ]]; then
        echo "❌ 本地端口必须在 1~65535 范围内"; return;
    fi

    if ! [[ "$DPORT" -ge 1 && "$DPORT" -le 65535 ]]; then
        echo "❌ 目标端口必须在 1~65535 范围内"; return;
    fi
    # ✅ IP 格式检查
    if ! [[ "$DIP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        echo "❌ 目标 IP 格式不正确"; return;
    fi

    # ✅ 检查是否已存在重复规则
    EXIST=$(nft list chain ip nat prerouting | grep "dport $LPORT" | grep "$DIP:$DPORT" || true)
    if [ -n "$EXIST" ]; then
        echo "⚠️ 规则已存在，无需重复添加"
        return
    fi

    echo "🔁 添加 TCP 和 UDP 转发: 本机:$LPORT → $DIP:$DPORT"

    nft add rule ip nat prerouting tcp dport $LPORT dnat to $DIP:$DPORT
    nft add rule ip nat prerouting udp dport $LPORT dnat to $DIP:$DPORT
    nft add rule ip nat postrouting ip daddr $DIP snat to $(hostname -I | awk '{print $1}')

    nft list ruleset > /etc/nftables.conf
    systemctl restart nftables

    echo "✅ 转发规则已添加"
    echo "📁 已保存到 /etc/nftables.conf，重启后仍然生效"
}

# 显示并删除规则
show_and_delete_rules() {
    ensure_nat_table_exists

    RULES=$(nft -a list chain ip nat prerouting | grep dport || true)
    if [ -z "$RULES" ]; then
        echo "（无转发规则）"
        return
    fi

    echo -e "\n📋 当前 NAT 转发规则如下："
    echo -e "编号  协议   本地端口  →  目标地址:端口           规则句柄"
    echo    "-----------------------------------------------------------"
    INDEX=1
    while IFS= read -r line; do
        PROTO=$(echo "$line" | awk '{print $1}')
        LPORT=$(echo "$line" | grep -oP 'dport \K[0-9]+')
        TARGET=$(echo "$line" | grep -oP 'dnat to \K[0-9.:]+')
        HANDLE=$(echo "$line" | grep -oP 'handle \K[0-9]+')
        printf "%-5s %-6s %-10s →  %-25s handle %s\n" "$INDEX" "$PROTO" "$LPORT" "$TARGET" "$HANDLE"
        INDEX=$((INDEX + 1))
    done <<< "$RULES"

    echo
    read -p "请输入要删除的规则编号（留空返回）: " NUM
    [ -z "$NUM" ] && return

    LINE=$(echo "$RULES" | sed -n "${NUM}p")
    HANDLE=$(echo "$LINE" | grep -oP 'handle \K[0-9]+')
    TARGET_IP=$(echo "$LINE" | grep -oP 'dnat to \K[0-9.]+')

    if [ -n "$HANDLE" ]; then
        nft delete rule ip nat prerouting handle $HANDLE
        echo "✅ 已删除 prerouting 第 $NUM 条规则（handle: $HANDLE）"

        # ✅ 自动尝试删除 postrouting 中的 SNAT（如果存在）
        SNAT_HANDLE=$(nft -a list chain ip nat postrouting | grep "$TARGET_IP" | grep snat | grep -oP 'handle \K[0-9]+' | head -n1)
        if [ -n "$SNAT_HANDLE" ]; then
            nft delete rule ip nat postrouting handle $SNAT_HANDLE
            echo "🧹 已自动删除与目标 IP 相关的 SNAT 规则（handle: $SNAT_HANDLE）"
        fi

        nft list ruleset > /etc/nftables.conf
        systemctl restart nftables
    else
        echo "❌ 未找到对应规则或 handle。"
    fi
}

# 主菜单
while true; do
    ensure_nat_table_exists
    echo -e "\n\e[1;36m===== NFT 端口转发管理脚本 =====\e[0m"
    echo -e "\e[1;33m[1]\e[0m 添加转发规则（TCP+UDP）"
    echo -e "\e[1;33m[2]\e[0m 查看并删除现有规则"
    echo -e "\e[1;33m[0]\e[0m 退出"
    read -p $'\n请输入选项编号：' CHOICE

    case $CHOICE in
        1) add_rule ;;
        2) show_and_delete_rules ;;
        0) exit 0 ;;
        *) echo "❌ 无效选项，请重试。" ;;
    esac
done
