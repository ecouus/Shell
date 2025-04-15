#!/bin/bash
Green="\033[32m"
Font="\033[0m"

#root权限
root_need(){
    if [[ $EUID -ne 0 ]]; then
        echo "Error:This script must be run as root!" 1>&2
        exit 1
    fi
}

#封禁ip
block_ipset(){
check_ipset
#添加ipset规则
echo -e "${Green}请输入需要封禁的国家代码，如cn(中国)，注意字母为小写！${Font}"
read -p "请输入国家代码:" GEOIP
echo -e "${Green}正在下载IPs data...${Font}"
wget -P /tmp http://www.ipdeny.com/ipblocks/data/countries/$GEOIP.zone 2> /dev/null
#检查下载是否成功
    if [ -f "/tmp/"$GEOIP".zone" ]; then
	 echo -e "${Green}IPs data下载成功！${Font}"
    else
	 echo -e "${Green}下载失败，请检查你的输入！${Font}"
	 echo -e "${Green}代码查看地址：http://www.ipdeny.com/ipblocks/data/countries/${Font}"
    exit 1
    fi
#创建规则
ipset -N $GEOIP hash:net
for i in $(cat /tmp/$GEOIP.zone ); do
ipset -A $GEOIP $i;
done
rm -f /tmp/$GEOIP.zone
echo -e "${Green}规则添加成功，即将开始封禁ip！${Font}"
#开始封禁
iptables -I INPUT -p tcp -m set --match-set "$GEOIP" src -j DROP
iptables -I INPUT -p udp -m set --match-set "$GEOIP" src -j DROP
echo -e "${Green}所指定国家($GEOIP)的ip封禁成功！${Font}"
}

#解封ip
unblock_ipset(){
echo -e "${Green}请输入需要解封的国家代码，如cn(中国)，注意字母为小写！${Font}"
read -p "请输入国家代码:" GEOIP
#判断是否有此国家的规则
lookuplist=`ipset list | grep "Name:" | grep "$GEOIP"`
    if [ -n "$lookuplist" ]; then
        iptables -D INPUT -p tcp -m set --match-set "$GEOIP" src -j DROP
	iptables -D INPUT -p udp -m set --match-set "$GEOIP" src -j DROP
        # 检查是否有ICMP规则，如果有则删除
        icmp_rule_exists=$(iptables -L INPUT | grep "icmp" | grep "$GEOIP")
        if [ -n "$icmp_rule_exists" ]; then
            iptables -D INPUT -p icmp -m set --match-set "$GEOIP" src -j DROP
        fi
	ipset destroy $GEOIP
	echo -e "${Green}所指定国家($GEOIP)的ip解封成功，并删除其对应的规则！${Font}"
    else
	echo -e "${Green}解封失败，请确认你所输入的国家是否在封禁列表内！${Font}"
	exit 1
    fi
}

#查看封禁列表
block_list(){
	iptables -L | grep match-set
}

#禁用特定国家的ICMP（禁止ping）
block_icmp(){
check_ipset
echo -e "${Green}请输入需要禁用ICMP的国家代码，如cn(中国)，注意字母为小写！${Font}"
read -p "请输入国家代码:" GEOIP
# 检查该国家是否已存在规则集
lookuplist=`ipset list | grep "Name:" | grep "$GEOIP"`
if [ -z "$lookuplist" ]; then
    # 如果规则集不存在，需要创建
    echo -e "${Green}未发现该国家的规则集，正在创建...${Font}"
    echo -e "${Green}正在下载IPs data...${Font}"
    wget -P /tmp http://www.ipdeny.com/ipblocks/data/countries/$GEOIP.zone 2> /dev/null
    # 检查下载是否成功
    if [ -f "/tmp/"$GEOIP".zone" ]; then
        echo -e "${Green}IPs data下载成功！${Font}"
    else
        echo -e "${Green}下载失败，请检查你的输入！${Font}"
        echo -e "${Green}代码查看地址：http://www.ipdeny.com/ipblocks/data/countries/${Font}"
        exit 1
    fi
    # 创建规则
    ipset -N $GEOIP hash:net
    for i in $(cat /tmp/$GEOIP.zone ); do
        ipset -A $GEOIP $i;
    done
    rm -f /tmp/$GEOIP.zone
    echo -e "${Green}规则添加成功！${Font}"
fi

# 检查是否已经有此国家的ICMP禁用规则
icmp_rule_exists=$(iptables -L INPUT | grep "icmp" | grep "$GEOIP")
if [ -n "$icmp_rule_exists" ]; then
    echo -e "${Green}该国家($GEOIP)的ICMP协议已被禁用，无需重复操作！${Font}"
else
    iptables -I INPUT -p icmp -m set --match-set "$GEOIP" src -j DROP
    echo -e "${Green}所指定国家($GEOIP)的ICMP协议（ping请求）已成功禁用！${Font}"
fi
}

#解除特定国家的ICMP禁用（允许ping）
unblock_icmp(){
echo -e "${Green}请输入需要解除ICMP禁用的国家代码，如cn(中国)，注意字母为小写！${Font}"
read -p "请输入国家代码:" GEOIP
# 检查是否有此国家的ICMP规则
icmp_rule_exists=$(iptables -L INPUT | grep "icmp" | grep "$GEOIP")
if [ -n "$icmp_rule_exists" ]; then
    iptables -D INPUT -p icmp -m set --match-set "$GEOIP" src -j DROP
    echo -e "${Green}所指定国家($GEOIP)的ICMP协议（ping请求）已解除禁用！${Font}"
else
    echo -e "${Green}未发现该国家($GEOIP)的ICMP禁用规则，无需解除！${Font}"
fi
}

#检查系统版本
check_release(){
    if [ -f /etc/redhat-release ]; then
        release="centos"
    elif cat /etc/issue | grep -Eqi "debian"; then
        release="debian"
    elif cat /etc/issue | grep -Eqi "ubuntu"; then
        release="ubuntu"
    elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
        release="centos"
    elif cat /proc/version | grep -Eqi "debian"; then
        release="debian"
    elif cat /proc/version | grep -Eqi "ubuntu"; then
        release="ubuntu"
    elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
        release="centos"
    fi
}

#检查ipset是否安装
check_ipset(){
    if [ -f /sbin/ipset ]; then
        echo -e "${Green}检测到ipset已存在，并跳过安装步骤！${Font}"
    elif [ "${release}" == "centos" ]; then
        yum -y install ipset
    else
        apt-get -y install ipset
    fi
}

#开始菜单
main(){
root_need
check_release
clear
echo -e "———————————————————————————————————————"
echo -e "${Green}Linux VPS一键屏蔽指定国家所有的IP访问${Font}"
echo -e "${Green}1、封禁TCP/UDP${Font}"
echo -e "${Green}2、解封TCP/UDP/ICMP${Font}"
echo -e "${Green}3、查看封禁列表${Font}"
echo -e "${Green}4、封禁ICMP${Font}"
echo -e "${Green}5、解除ICMP禁用${Font}"
echo -e "———————————————————————————————————————"
read -p "请输入数字 [1-5]:" num
case "$num" in
    1)
    block_ipset
    ;;
    2)
    unblock_ipset
    ;;
    3)
    block_list
    ;;
    4)
    block_icmp
    ;;
    5)
    unblock_icmp
    ;;
    *)
    clear
    echo -e "${Green}请输入正确数字 [1-5]${Font}"
    sleep 2s
    main
    ;;
    esac
}

main
