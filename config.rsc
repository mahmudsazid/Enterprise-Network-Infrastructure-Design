# LAN & WAN bridge
 /interface bridge
 add name=LAN
 add name=WAN

# Physical port গুলোকে meaningful নামে rename
/interface ethernet
set [ find default-name=ether1 ] name=ether1-Race-Primary
set [ find default-name=ether5 ] name="ether5_UCM (103.190.199.154)"
set [ find default-name=ether7 ] name=ether7_LAN_SW1
set [ find default-name=ether8 ] name=ether8_LAN_SW2
set [ find default-name=ether9 ] name=ether9_LAN_SW3
set [ find default-name=ether10 ] name=ether10_LAN_SW4
set [ find default-name=ether12 ] name="ether12 WAN (103.190.199.155)"
set [ find default-name=ether13 ] name="ether13 WAN"
set [ find default-name=ether14 ] name="ether14 WAN"
set [ find default-name=ether15 ] name="ether15 WAN"

# Secondary uplink
set [ find default-name=sfp-sfpplus1 ] name=sfp-sfpplus1-Race-Secondary


# LAN ports bridge এ add
/interface bridge port
add bridge=LAN interface=ether7_LAN_SW1
add bridge=LAN interface=ether8_LAN_SW2
add bridge=LAN interface=ether9_LAN_SW3
add bridge=LAN interface=ether10_LAN_SW4
add bridge=LAN interface=ether11
add bridge=LAN interface=sfp-sfpplus2

# WAN ports bridge এ add
add bridge=WAN interface="ether5_UCM (103.190.199.154)"
add bridge=WAN interface="ether12 WAN (103.190.199.155)"
add bridge=WAN interface="ether13 WAN"
add bridge=WAN interface="ether14 WAN"
add bridge=WAN interface="ether15 WAN"


# LAN networks
/ip address
add address=192.168.10.1/24 interface=LAN network=192.168.10.0
add address=192.168.11.1/24 interface=LAN network=192.168.11.0
add address=192.168.20.1/22 interface=LAN network=192.168.20.0

# WAN / Upstream
add address=172.16.133.202/30 interface=ether1-Race-Primary network=\
    172.16.133.200
add address=172.16.133.206/30 interface=sfp-sfpplus1-Race-Secondary network=\
    172.16.133.204
add address=103.190.199.153/29 interface=WAN network=103.190.199.152


# IP Pool
/ip pool
add name=dhcp_pool0 ranges=192.168.20.2-192.168.23.254
add name=vpn-pool ranges=10.10.1.5-10.10.1.55

# DHCP Server
/ip dhcp-server
add name=dhcp1 interface=LAN address-pool=dhcp_pool0 lease-time=1w

# Network
/ip dhcp-server network
add address=192.168.20.0/22 gateway=192.168.20.1 dns-server=8.8.8.8,1.1.1.1

/ip dns
set servers=8.8.8.8,1.1.1.1

/routing bgp template
set default as=65061 disabled=no routing-table=main

/system logging action
set 0 memory-lines=10000


# Layer7 website block
/ip firewall layer7-protocol
add name=Block_Facebook regexp="^.+(facebook.com).*\$"
add name=Block_YouTube regexp="^.+(youtube.com).*\$"
add name=Block_Stock regexp="^.+(dsebd.org|cse.com.bd|amarstock.com|stocknow.com.bd|lankabd.com|dse.com.bd).*\$"

# Filter rules
/ip firewall filter

/ip firewall address-list
add address=192.168.10.0/24 disabled=yes list=LAN
add address=192.168.11.0/24 disabled=yes list=LAN
add address=192.168.20.0/22 disabled=yes list=LAN
add address=103.190.199.152/29 list=Public_Prefix
add address=74.125.24.109 disabled=yes list=Housekeeping
add address=182.16.156.246 disabled=yes list=Housekeeping
add address=133.243.238.163 disabled=yes list=Housekeeping
add address=172.16.133.200/30 list=No-NAT
add address=172.16.133.204/30 list=No-NAT
add address=103.190.199.152/29 list=No-NAT

# Block specific sites
add chain=forward action=drop layer7-protocol=Block_Stock comment="Block Stock Sites"
add chain=forward action=drop layer7-protocol=Block_Facebook comment="Facebook"
add chain=forward action=drop layer7-protocol=Block_YouTube comment="Youtube"

# Allow VPN
add chain=input action=accept protocol=tcp dst-port=1723 comment="Allow PPTP"
add chain=input action=accept protocol=gre comment="Allow GRE"

# Basic LAN ↔ VPN communication
add chain=forward action=accept comment="LAN to VPN"

# Public IP NAT
/ip firewall nat
add action=src-nat chain=srcnat out-interface=ether1-Race-Primary \
    src-address-list=!No-NAT to-addresses=103.190.199.153

add action=src-nat chain=srcnat out-interface=sfp-sfpplus1-Race-Secondary \
    src-address-list=!No-NAT to-addresses=103.190.199.153

# VPN NAT
add action=masquerade chain=srcnat comment="NAT for PPTP Clients" \
    src-address=192.168.10.0/24


# Enable VPN Servers
/interface pptp-server server
set authentication=pap,chap,mschap1,mschap2 enabled=yes

/interface l2tp-server server
set enabled=yes use-ipsec=yes

# User accounts
/ppp secret
add local-address=103.190.199.153 name=RPAEL profile=default-encryption \
    service=pptp
add local-address=103.190.199.153 name=HITACHI profile=default-encryption \
    service=pptp
add local-address=103.190.199.153 name=REVERIE profile=default-encryption \
    service=l2tp

/ppp profile
set *FFFFFFFE dns-server=8.8.8.8,1.1.1.1 local-address=vpn-pool \
    remote-address=vpn-pool


/ip route
add check-gateway=ping disabled=no distance=1 dst-address=182.160.100.154/32 \
    gateway=172.30.111.157 routing-table=main suppress-hw-offload=no
add check-gateway=ping disabled=no distance=2 dst-address=182.160.100.154/32 \
    gateway=172.30.27.33 pref-src="" routing-table=main scope=30 \
    suppress-hw-offload=no target-scope=10



# Routing

# Primary BGP
/routing bgp connection
add name=Race-Primary remote.address=172.16.133.201 \
    local.address=172.16.133.202 as=65061 remote.as=65116

# Secondary BGP
add name=Race-Secondary remote.address=172.16.133.205 \
    local.address=172.16.133.206 as=65061 remote.as=64815

/routing bgp connection
add as=65061 connect=yes disabled=no input.filter=RACE-PRI-IN listen=yes \
    local.address=172.16.133.202 .role=ebgp name=Race-Primary \
    output.default-originate=never .filter-chain=OUT .network=Public_Prefix \
    remote.address=172.16.133.201/32 .as=65116 routing-table=main templates=\
    default
add as=65061 connect=yes disabled=no input.filter=RACE-SEC-IN listen=yes \
    local.address=172.16.133.206 .role=ebgp name=Race-secondary \
    output.default-originate=never .filter-chain=OUT .network=Public_Prefix \
    remote.address=172.16.133.205/32 .as=64815 routing-table=main templates=\
    default


/routing filter rule
add chain=RACE-PRI-IN disabled=no rule=\
    "if (dst == 0.0.0.0/0 ) { set bgp-local-pref 1000; accept;}"
add chain=RACE-PRI-IN disabled=no rule=\
    "if (dst in 0.0.0.0/0 && dst-len in 0-32) {reject}"
add chain=RACE-SEC-IN disabled=no rule=\
    "if (dst == 0.0.0.0/0 ) { set bgp-local-pref 100; accept;}"
add chain=RACE-SEC-IN disabled=no rule=\
    "if (dst in 0.0.0.0/0 && dst-len in 0-32) {reject}"
add chain=OUT disabled=no rule="if (dst==103.190.199.152/29) {accept;}"
add chain=OUT disabled=no rule=\
    " if (dst in 0.0.0.0/0 && dst-len in 0-32) {reject}"



# Unused services disable
/ip service
set telnet disabled=yes
set ftp disabled=yes
set www disabled=yes
set ssh disabled=yes
set api disabled=yes

# Winbox restricted access
set winbox address="103.49.114.197/32,59.152.100.146/32,59.152.100.205/32,103.\
    190.199.153/32,192.168.20.0/22" port=9900


/system clock
set time-zone-name=Asia/Dhaka

/system identity
set name="Reverie HO"

# NTP
/system ntp client
set enabled=yes

/system ntp client servers
add address=182.16.156.246
add address=133.243.238.163

/system routerboard settings
set enter-setup-on=delete-key



