#!/bin/sh

#------------------------------
# 设置变量
#------------------------------

while true;
do
    read -p "CIDR(e.g. 172.20.0.0/24): " CIDR
    if [ -z $CIDR ]; then
        echo "please set cidr." 
    else
        break
    fi
done

#------------------------------
# 系统设置
#------------------------------

echo "net.ipv4.ip_forward=1" > /etc/sysctl.conf
sysctl -w net.ipv4.ip_forward=1

#------------------------------
# NAT
#------------------------------

iptables -t nat -A POSTROUTING -s $CIDR -j MASQUERADE
iptables -A FORWARD -s $CIDR -j ACCEPT

# 保存配置
service iptables save
