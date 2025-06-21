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

# 保证 filter 表存在（用于本机限制）
ensure_filter_table_exists() {
  if ! nft list table inet filter >/dev/null 2>&1; then
    echo "✅ 正在创建 filter 表..."
    nft add table inet filter
  fi

  if ! nft list chain inet filter input >/dev/null 2>&1; then
    echo "✅ 创建 filter input 链..."
    nft add chain inet filter input { type filter hook input priority 0\; }
  fi
}

# 添加端口转发规则
add_rule() {
    ensure_nat_table_exists
    sleep 0.2

    read -p "请输入本地监听端口: " LPORT
    read -p "请输入目标 IP: " DIP
    read -p "请输入目标端口: " DPORT

    [[ "$LPORT" =~ ^[0-9]+$ ]] || { echo "❌ 本地端口无效"; return; }
    [[ "$DPORT" =~ ^[0-9]+$ ]] || { echo "❌ 目标端口无效"; return; }
    if ! [[ "$LPORT" -ge 1 && "$LPORT" -le 65535 ]]; then
        echo "❌ 本地端口必须在 1~65535 范围内"; return;
    fi
    if ! [[ "$DPORT" -ge 1 && "$DPORT" -le 65535 ]]; then
        echo "❌ 目标端口必须在 1~65535 范围内"; return;
    fi
    if ! [[ "$DIP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        echo "❌ 目标 IP 格式不正确"; return;
    fi

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

# 查看并删除转发规则
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

# 限制端口仅允许本机访问
limit_port_local_only() {
    ensure_filter_table_exists
    read -p "请输入要限制的端口号（如 8080）: " PORT

    if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
        echo "❌ 端口号无效"; return
    fi

    echo "✅ 添加规则：端口 $PORT 仅允许 127.0.0.1 访问"

    nft add rule inet filter input ip saddr 127.0.0.1 tcp dport $PORT accept
    nft add rule inet filter input tcp dport $PORT drop

    nft list ruleset > /etc/nftables.conf
    systemctl restart nftables
    echo "✅ 已保存限制规则，重启后仍然生效"
}

# 查看并删除本机访问限制规则
remove_limit_port_local() {
    ensure_filter_table_exists

    RULES=$(nft -a list chain inet filter input | grep "tcp dport" | grep -E '127\.0\.0\.1|drop' || true)
    if [ -z "$RULES" ]; then
        echo "📭 没有发现“仅本机访问限制”的相关规则。"
        return
    fi

    echo -e "\n📋 当前限制端口访问的规则如下："
    echo -e "编号  描述                                    规则句柄"
    echo    "-----------------------------------------------------------"
    INDEX=1
    while IFS= read -r line; do
        HANDLE=$(echo "$line" | grep -oP 'handle \K[0-9]+')
        DESC=$(echo "$line" | sed 's/handle.*//' | xargs)
        printf "%-5s %-40s handle %s\n" "$INDEX" "$DESC" "$HANDLE"
        INDEX=$((INDEX + 1))
    done <<< "$RULES"

    echo
    read -p "请输入要删除的规则编号（留空返回）: " NUM
    [ -z "$NUM" ] && return

    LINE=$(echo "$RULES" | sed -n "${NUM}p")
    HANDLE=$(echo "$LINE" | grep -oP 'handle \K[0-9]+')

    if [ -n "$HANDLE" ]; then
        nft delete rule inet filter input handle $HANDLE
        echo "✅ 已删除本机访问限制规则（handle: $HANDLE）"
        nft list ruleset > /etc/nftables.conf
        systemctl restart nftables
    else
        echo "❌ 找不到指定规则。"
    fi
}

# 主菜单
while true; do
    ensure_nat_table_exists
    echo -e "\n\e[1;36m===== NFT 端口转发管理脚本 =====\e[0m"
    echo -e "\e[1;33m[1]\e[0m 添加转发规则（TCP+UDP）"
    echo -e "\e[1;33m[2]\e[0m 查看并删除现有转发规则"
    echo -e "\e[1;33m[3]\e[0m 限制某端口仅允许本机访问"
    echo -e "\e[1;33m[4]\e[0m 查看并删除现有限制规则（本机访问限制）"
    echo -e "\e[1;33m[0]\e[0m 退出"
    read -p $'\n请输入选项编号：' CHOICE

    case $CHOICE in
        1) add_rule ;;
        2) show_and_delete_rules ;;
        3) limit_port_local_only ;;
        4) remove_limit_port_local ;;
        0) exit 0 ;;
        *) echo "❌ 无效选项，请重试。" ;;
    esac
done
