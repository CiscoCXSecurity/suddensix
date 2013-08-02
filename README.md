suddensix
=========

**Overview**

Sudden Six is an automation script for conducting the SLAAC attack outlined in Alec Water's [blog post](http://resources.infosecinstitute.com/slaac-attack/).  
This attack can be used to build an IPv6 overlay network on an IPv4 infrastructure to perform man-in-the-middle attacks.

The script installs and configures the following packages:

* sipcalc
* tayga
* radvd
* wide-dhcpv6-server 
* bind9

**Requirements**
This script has been tested on Ubuntu 12.04 LTS and Kali Linux 1.0.x.  We suggest using [Wireshark](http://http://www.wireshark.org/) to view the intercepted traffic.

**Usage**

Execute the `suddensix.sh` script as the root user.  The script will prompt you for the interface to conduct the attack from as well as ask you to specify a free IP address on the local IPv4 network you are attacking.  
After the script is running, run Wireshark to view the intercepted traffic.  

*Note:*  The script is not persistent, the attack host will not intercept traffic after a reboot.  The script will not work on fully configured IPv6 networks.  

For more information check out the [Neohapsis Blog](http://labs.neohapsis.com/2013/07/30/picking-up-the-slaac-with-sudden-six/)

**TODO**

We need help getting the following finished:

* A way to specify MITM target scope
* Automate basic network reconnaissance
* Detect IPv6 countermeasures
* Configure IPv6 tunneling
* Leverage THC-IPv6 tools
* More platforms

If you are intersted in helping, fork the project and submit a pull request with your additions!
