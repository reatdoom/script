#!/bin/sh

#------------------------------
# 设置变量
#------------------------------

while true;
do
    read -p "Server eip(e.g. 1.1.1.1): " EIP
    if [ -z $EIP ]; then
        echo "please set server's eip." 
    else
        break
    fi
done

read -p "1-IPSec Key (defaut: vpn): " VPN_IPSEC_PSK
read -p "2-IPSec Network (default: 172.32.0.0/24): " IPSEC_CIDR
read -p "3-L2TP Network (default: 172.31.0.0/24): " L2TP_CIDR
read -p "4-L2TP Gateway (default: 172.31.0.1): " L2TP_GW
read -p "5-L2TP DHCP From (default: 172.31.0.2): " L2TP_FROM
read -p "6-L2TP DHCP To (default: 172.31.0.254)" L2TP_TO

read -p "7-Setting physical gateway (y/n): " yn

case $yn in
    [Yy]* )
        read -p "8-Physical Gateway (default: 172.20.0.254): " GW
        if [ -z $GW ]; then
            GW=172.20.0.254
        fi
        break;;
    [Nn]* )
        break;;
        * )
        break;;
esac


if [ -z $VPN_IPSEC_PSK ]; then
    VPN_IPSEC_PSK='vpn'
fi

if [ -z $IPSEC_CIDR ]; then
    IPSEC_CIDR=172.32.0.0/24
fi

if [ -z $L2TP_CIDR ]; then
    L2TP_CIDR=172.31.0.0/24
fi

if [ -z $L2TP_GW ]; then
    L2TP_GW=172.31.0.1
fi

if [ -z $L2TP_FROM ]; then
    L2TP_FROM=172.31.0.2
fi

if [ -z $L2TP_TO ]; then
    L2TP_TO=172.31.0.254
fi

#------------------------------
# 安装
#------------------------------

yum -y install strongswan xl2tpd

#------------------------------
# 系统设置
#------------------------------

echo "net.ipv4.ip_forward=1" > /etc/sysctl.conf

for vpn in /proc/sys/net/ipv4/conf/*;
do
  echo 0 > $vpn/accept_redirects;
  echo 0 > $vpn/send_redirects;
done

sysctl -w net.ipv4.ip_forward=1

#------------------------------
# 配置
#------------------------------

cat > /etc/strongswan/ipsec.conf << EOF
config setup
  uniqueids = no
  charondebug="cfg 2, dmn 2, ike 2, net 0"
    
conn %default
  keyexchange=ikev1
  ike=aes128-sha256-ecp256,aes256-sha384-ecp384,aes128-sha256-modp2048,aes128-sha1-modp2048,aes256-sha384-modp4096,aes256-sha256-modp4096,aes256-sha1-modp4096,aes128-sha256-modp1536,aes128-sha1-modp1536,aes256-sha384-modp2048,aes256-sha256-modp2048,aes256-sha1-modp2048,aes128-sha256-modp1024,aes128-sha1-modp1024,aes256-sha384-modp1536,aes256-sha256-modp1536,aes256-sha1-modp1536,aes256-sha384-modp1024,aes256-sha256-modp1024,aes256-sha1-modp1024!
  esp=aes128gcm16-ecp256,aes256gcm16-ecp384,aes128-sha256-ecp256,aes256-sha384-ecp384,aes128-sha256-modp2048,aes128-sha1-modp2048,aes256-sha384-modp4096,aes256-sha256-modp4096,aes256-sha1-modp4096,aes128-sha256-modp1536,aes128-sha1-modp1536,aes256-sha384-modp2048,aes256-sha256-modp2048,aes256-sha1-modp2048,aes128-sha256-modp1024,aes128-sha1-modp1024,aes256-sha384-modp1536,aes256-sha256-modp1536,aes256-sha1-modp1536,aes256-sha384-modp1024,aes256-sha256-modp1024,aes256-sha1-modp1024,aes128gcm16,aes256gcm16,aes128-sha256,aes128-sha1,aes256-sha384,aes256-sha256,aes256-sha1!

  left=%any
  leftsubnet=0.0.0.0/0
  dpdaction=clear
  dpddelay=300s

conn CiscoIPSec
  keyexchange=ikev1
  fragmentation=yes
  
  leftauth=psk
  
  right=%any
  rightauth=psk
  rightauth2=xauth
  rightdns=8.8.8.8,8.8.4.4
  rightsourceip=$IPSEC_CIDR
  
  auto=add

#conn L2TP-PSK-NAT
  #rightsubnet=%any
  #also=L2TP-PSK-noNAT
    
conn L2TP-PSK-noNAT
  keyexchange=ikev1
  type=transport
  authby=secret
  rekey=no
  auto=add
  
  left=$EIP
  leftsubnet=0.0.0.0/0
  leftprotoport=17/1701
  leftfirewall=no
  
  right=%any
  rightprotoport=17/%any
EOF

#------------------------------
# /etc/strongswan/strongswan.conf
#------------------------------

cat > /etc/strongswan/strongswan.conf << EOF
charon {
  dns1 = 8.8.8.8
  dns2 = 8.8.4.4
  load_modular = yes
  plugins {
    include strongswan.d/charon/*.conf
  }
}

include strongswan.d/*.conf
EOF

#------------------------------
# /etc/strongswan/ipsec.secrets
#------------------------------

cat > /etc/strongswan/ipsec.secrets << EOF
: PSK "$VPN_IPSEC_PSK"
EOF

#------------------------------
# /etc/xl2tpd/xl2tpd.conf
#------------------------------

cat > /etc/xl2tpd/xl2tpd.conf << EOF
[global]
listen-addr = $EIP

[lns default]
ip range = $L2TP_FROM-$L2TP_TO
local ip = $L2TP_GW
assign ip = yes
require chap = yes
require authentication = yes
name = xl2tpd
ppp debug = yes
pppoptfile = /etc/ppp/options.xl2tpd
length bit = yes
EOF

#------------------------------
# /etc/ppp/options.xl2tpd
#------------------------------

cat > /etc/ppp/options.xl2tpd << EOF
ipcp-accept-local
ipcp-accept-remote
ms-dns 8.8.8.8
ms-dns 8.8.4.4
noccp
auth
idle 18000
mtu 1460
mru 1460
nodefaultroute
debug
proxyarp
connect-delay 5000
EOF

#------------------------------
# /etc/ppp/chap-secrets
#------------------------------

cat >> /etc/ppp/chap-secrets << EOF
test xl2tpd test * 5
EOF

#------------------------------
# 防火墙 - NAT
#------------------------------

iptables -A INPUT -p udp --dport 500 -j ACCEPT
iptables -A INPUT -p tcp --dport 4500 -j ACCEPT
iptables -A INPUT -p udp --dport 4500 -j ACCEPT

# IPSEC VPN
iptables -t nat -A POSTROUTING -s $IPSEC_CIDR -j MASQUERADE
iptables -A FORWARD -s $IPSEC_CIDR -j ACCEPT

# L2TP VPN
iptables -t nat -A POSTROUTING -s $L2TP_CIDR -j MASQUERADE
iptables -A FORWARD -s $L2TP_CIDR -j ACCEPT

# 保存配置
service iptables save

#------------------------------
# 路由
#------------------------------

if [ $GW ]
then
    ip route add default via $GW table 102
    ip route add 8.8.8.8 via $GW
cat > /etc/rc.local << EOF
ip route add default via $GW table 102
ip route add 8.8.8.8 via $GW
EOF
else
    echo > /etc/rc.local
fi

ip rule add to $L2TP_CIDR lookup main
ip rule add from $L2TP_CIDR pref 102 lookup 102

cat > /etc/rc.local << EOF
ip rule add to $L2TP_CIDR lookup main
ip rule add from $L2TP_CIDR pref 102 lookup 102
EOF

chmod +x /etc/rc.local

#------------------------------
# 启动
#------------------------------

systemctl enable strongswan
systemctl enable xl2tpd

systemctl start strongswan
systemctl start xl2tpd
