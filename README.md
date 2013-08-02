suddensix
=========

**Overview**

Sudden Six is an automation script for conducting the SLAAC attack outlined in Alec Water's [blog post](http://resources.infosecinstitute.com/slaac-attack/).  
This attack can be used to build an IPv6 overlay network on an IPv4 infastructre to perform man-in-the-middle attacks.

The script installs and configures the following packages:

* sipcalc
* tayga
* radvd
* wide-dhcpv6-server 
* bind9

**Requirements**

This script has been tested on Ubuntu 12.4 LTS and Kali Linux 1.0.x

**Usage**

Execute the `suddensix.sh` script as the root user.  The script will prompt you for the interface to conduct the attack from as well as ask you to specificy a free IP address on the local network you are attacking.  

*Note:* 

The script is not persistent.  The script will not work on fully configured IPv6 networks.  

For more information check out the [Neohapsis Blog}(http://labs.neohapsis.com/2013/07/30/picking-up-the-slaac-with-sudden-six/)
