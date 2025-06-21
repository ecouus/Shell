#!/bin/bash

echo "========== 本机端口访问控制 =========="
echo "1. 限制指定端口仅允许本机访问"
echo "2. 取消限制（允许所有来源访问端口）"
read -p "请选择操作 [1/2]: " ACTION

read -p "请输入要操作的端口号（如 7688）: " PORT

# 安装 iptables-persistent（如未安装）
if ! dpkg -l | grep -q iptables-persistent; then
    echo "🔧 正在安装 iptables-persistent..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent
fi

if [ "$ACTION" == "1" ]; then
    echo "✅ 添加规则：只允许 127.0.0.1 访问端口 $PORT..."
    iptables -D INPUT -p tcp --dport "$PORT" -j ACCEPT 2>/dev/null
    iptables -A INPUT -p tcp -s 127.0.0.1 --dport "$PORT" -j ACCEPT
    iptables -A INPUT -p tcp --dport "$PORT" -j DROP
    echo "💾 正在保存规则..."
    netfilter-persistent save
    echo "✅ 设置完成：端口 $PORT 现在只能被本机访问。"

elif [ "$ACTION" == "2" ]; then
    echo "🗑️  删除规则：恢复端口 $PORT 对所有来源开放..."
    iptables -D INPUT -p tcp -s 127.0.0.1 --dport "$PORT" -j ACCEPT 2>/dev/null
    iptables -D INPUT -p tcp --dport "$PORT" -j DROP 2>/dev/null
    iptables -A INPUT -p tcp --dport "$PORT" -j ACCEPT
    echo "💾 正在保存规则..."
    netfilter-persistent save
    echo "✅ 已恢复端口 $PORT 的公网访问权限。"

else
    echo "❌ 无效选项，请输入 1 或 2"
fi
