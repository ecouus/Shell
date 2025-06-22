#!/bin/bash

set -e

# 初始化 nftables 基础结构，并自动放行 SSH 端口
init_nft_structure() {
    if ! nft list table inet filter &>/dev/null; then
        echo "🧱 创建表：inet filter"
        nft add table inet filter
    fi

    if ! nft list chain inet filter input &>/dev/null; then
        echo "🧱 创建链：inet filter input"
        nft add chain inet filter input { type filter hook input priority 0\; policy accept\; }
        nft add rule inet filter input iif lo accept
        nft add rule inet filter input ct state established,related accept
        echo "✅ 已初始化 input 链规则"
    fi

    ensure_ssh_rule
}

# 每次运行都确保 SSH 端口被放行
ensure_ssh_rule() {
    SSH_PORT=$(grep -Ei '^Port ' /etc/ssh/sshd_config | awk '{print $2}' | head -n1)
    [[ -z "$SSH_PORT" ]] && SSH_PORT=22

    if ! nft list chain inet filter input 2>/dev/null | grep -q "tcp dport $SSH_PORT accept"; then
        echo "🔓 检测到 SSH 端口（$SSH_PORT）未放行，正在添加规则..."
        nft add rule inet filter input tcp dport "$SSH_PORT" accept
        echo "✅ SSH 端口已放行：$SSH_PORT"
    else
        echo "🔐 SSH 端口 $SSH_PORT 已放行，无需重复添加"
    fi
}

# 查看当前 input 链的默认策略
show_policy() {
    local policy
    policy=$(nft list chain inet filter input | grep "policy" | awk '{print $NF}')
    echo "📋 当前 input 链默认策略为：$policy"
}

# 修改默认策略
modify_policy() {
    show_policy
    echo -e "\n⚠️ 修改默认策略前请确保你已放行 SSH 端口，否则可能被锁！"
    echo -e "例如：nft add rule inet filter input tcp dport 22 accept\n"

    read -rp "请选择默认策略（accept/drop）: " NEWPOLICY
    if [[ "$NEWPOLICY" != "accept" && "$NEWPOLICY" != "drop" ]]; then
        echo "❌ 无效策略"
        exit 1
    fi

    nft 'chain inet filter input { policy '"$NEWPOLICY"'; }'
    echo "✅ 默认策略已修改为：$NEWPOLICY"
}


# 添加规则
add_rule() {
    read -rp "请输入端口号（多个端口用英文逗号分隔，范围1~65535）: " PORT_STR
    IFS=',' read -ra PORTS <<< "$PORT_STR"
    for port in "${PORTS[@]}"; do
        [[ "$port" =~ ^[0-9]+$ ]] && ((port >= 1 && port <= 65535)) || {
            echo "❌ 端口无效: $port"
            return 1
        }
    done

    echo -e "\n📡 选择协议类型(默认3):"
    echo "1) TCP"
    echo "2) UDP"
    echo "3) TCP 和 UDP"
    read -rp "协议选项 [1-3]: " PROTO_OPT
    PROTO_OPT=${PROTO_OPT:-3}
    case "$PROTO_OPT" in
        1) PROTOS=("tcp") ;;
        2) PROTOS=("udp") ;;
        3) PROTOS=("tcp" "udp") ;;
        *) echo "❌ 无效选择"; return 1 ;;
    esac

    echo -e "\n🚦 选择规则类型："
    echo "1) accept(放行)"
    echo "2) drop(拒绝)"
    read -rp "规则选项 [1-2]: " ACTION_OPT
    case "$ACTION_OPT" in
        1) ACTION="accept" ;;
        2) ACTION="drop" ;;
        *) echo "❌ 无效选择"; return 1 ;;
    esac

    SRC_PART=""
    if [ "$ACTION" == "accept" ]; then
        echo -e "\n🌐 是否只允许某个 IP 访问？(默认1)"
        echo "1) 是"
        echo "2) 否（所有 IP 都可访问）"
        read -rp "选项 [1/2]: " IP_LIMIT
        IP_LIMIT=${IP_LIMIT:-1}
        if [ "$IP_LIMIT" == "1" ]; then
            read -rp "请输入允许访问的源 IP（默认127.0.0.1）: " SRCIP
            SRCIP=${SRCIP:-127.0.0.1}
            [[ "$SRCIP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || { echo "❌ IP 格式不合法"; return 1; }
            SRC_PART="ip saddr $SRCIP"
        fi
    else
        echo -e "\n🌐 是否只拒绝某个 IP？(默认2)"
        echo "1) 是（只拦截特定 IP）"
        echo "2) 否（所有 IP 都拒绝）"
        read -rp "选项 [1/2]: " IP_LIMIT
        IP_LIMIT=${IP_LIMIT:-2}
        if [ "$IP_LIMIT" == "1" ]; then
            read -rp "请输入要拒绝的源 IP（默认127.0.0.1）: " SRCIP
            SRCIP=${SRCIP:-127.0.0.1}
            [[ "$SRCIP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || { echo "❌ IP 格式不合法"; return 1; }
            SRC_PART="ip saddr $SRCIP"
        fi
    fi

    for port in "${PORTS[@]}"; do
        port_trimmed=$(echo "$port" | xargs)
        for PROTO in "${PROTOS[@]}"; do
            echo "➕ 添加规则: $SRC_PART $PROTO dport $port_trimmed $ACTION"
            nft add rule inet filter input $SRC_PART $PROTO dport $port_trimmed $ACTION
        done
    done
}

# 查看并删除规则
list_and_delete_rule() {
    while true; do
        echo -e "\n📋 当前 inet filter input 链规则列表："
        RULES=$(nft -a list chain inet filter input | grep ' dport ' || true)

        if [ -z "$RULES" ]; then
            echo "（无规则）"
            return
        fi

        INDEX=1
        declare -A HANDLE_MAP
        while IFS= read -r line; do
            HANDLE=$(echo "$line" | grep -oP 'handle \K[0-9]+')
            DESC=$(echo "$line" | sed 's/ handle.*//' | xargs)
            HANDLE_MAP[$INDEX]=$HANDLE
            printf "%-4s %-60s handle %s\n" "$INDEX" "$DESC" "$HANDLE"
            INDEX=$((INDEX + 1))
        done <<< "$RULES"

        echo
        read -rp "请输入要删除的规则编号（留空返回主菜单）: " NUM
        [ -z "$NUM" ] && return

        HANDLE=${HANDLE_MAP[$NUM]}
        if [ -n "$HANDLE" ]; then
            nft delete rule inet filter input handle "$HANDLE"
            echo "✅ 已删除规则 handle: $HANDLE"
        else
            echo "❌ 编号无效"
        fi
    done
}

# 主菜单
init_nft_structure

while true; do
    echo -e "\n\033[1;36m=====  NFTables 端口规则管理 =====\033[0m"
    echo -e "\033[1;33m[1]\033[0m 查看/修改默认策略（accept/drop）"
    echo -e "\033[1;33m[2]\033[0m 添加新规则（支持端口、协议、IP限制）"
    echo -e "\033[1;33m[3]\033[0m 查看并删除已有规则"
    echo -e "\033[1;33m[4]\033[0m 进入端口转发管理模块（TCP/UDP 端口转发）"
    echo -e "\033[1;33m[5]\033[0m 屏蔽国内/海外IP"
    echo -e "\033[1;33m[0]\033[0m 退出脚本"
    echo "-------------------------------------------"
    read -rp "🎯 请输入选项编号 [0-4]: " CHOICE

    case "$CHOICE" in
        1) modify_policy ;;
        2) add_rule ;;
        3) list_and_delete_rule ;;
        4) bash <(curl -fsSL https://raw.githubusercontent.com/ecouus/Shell/refs/heads/main/nft_forward.sh) ;;
        5) bash <(curl -fsSL https://raw.githubusercontent.com/ecouus/Shell/refs/heads/main/nft_geo_block.sh) ;;
        0) echo -e "👋 退出脚本，再见！"; break ;;
        *) echo -e "\033[1;31m❌ 无效选项，请重新输入。\033[0m" ;;
    esac

    echo -e "\n💾 \033[1;32m保存规则并重启防火墙服务...\033[0m"
    nft list ruleset > /etc/nftables.conf
    systemctl restart nftables
done
