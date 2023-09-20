# Apple Server Guide
Last updated **15-01-2018** for Mac OS X High Sierra</br>
How to set up a new Apple server with macOS Server and Profile Manager.

</br>

## **Overview**
---
<!-- Add 'Prerequisites'? (AppleVPP Account, iTunes Account, ect...) -->
### MacOS
- OS X Installation Media

### EduProxy
- Access Control List
- Direct Forwarding Policy
- HTTP Access Policy

### Netspace
- Exclusions

### DNS
- Apple Cache Record
- Reverse Lookup Zones
- Stale Records
- Aging & Scavenging
- Clear Cache

### DHCP
- Reservation
- Dynamically Update DNS

### Server
- Hostname
- Reboot
- Remote Access
- Push Diagnostics
- Apple Configurator 2
- macOS Server
- Caching
- Open Directory
- Service Accounts
- Profile Manager

### Profile Manager
-

### Apple Configurator 2
- Blueprints
- Prepare & Enroll Devices
---


</br>


## **MacOS**
---
### OS X Installation Media
Follow Apple's guide to [Create bootable installation media for macOS](https://support.apple.com/en-au/HT201372).


</br>


## **EduProxy**
---
### Access Control List
- Log in to [EduProxy](http://eduproxy/)
- Navigate to _'Cache Management' > 'Access Control List' > 'Destination IP List'_
- Select _'Destination IP List'_ from ACL Type drop down menu
- Select _'Create New ACL'_ and enter the following details: </br>
Title: _Apple Direct IP Range_ </br>
Tag: _Apple_Direct_IP_Range_ </br>
ACL Data: _17.0.0.0/8_
- Select _'Create Destination IP List ACL'_

### Direct Forwarding Policy
- Log in to [EduProxy](http://eduproxy/)
- Navigate to _'Cache Management' > 'Policy Manager'_
- Select _'Direct Forwarding Policy'_ and enter the following details: </br>
Title: _Forward Traffic Direct to IP Range_ </br>
Rule Action: _Permit_ </br>
Conditions: _Apple Direct IP Range_
- Select _'Create Cache Policy Rule'_

### HTTP Access Policy
- Log in to [EduProxy](http://eduproxy/)
- Navigate to _'Cache Management' > 'Policy Manager'_
- Select _'HTTP Access Policy'_ and enter the following details: </br>
Title: _Allow Apple IP Range Without Authentication_ </br>
Rule Action: _Permit_ </br>
Condition: _Apple Direct IP Range_
- Select _'Create Cache Policy Rule'_


</br>


## **Netspace**
---
### Exclusions
- Log in to [Netspace](http://admin.education.netspace.net.au)
- White list the following domains for staff and students: </br>
`*verisign.com*` </br>
`*.apple.com*` </br>
`*.akamai.com*` </br>
`*.akadns.net*` </br>
`*.icloud.com*` </br>
`*.itunes.com*` </br>
`*.mac.com*` </br>
`*.me.com*` </br>
`*.mzstatic.com*` </br>
`*.akamaiedge.net*` </br>
`*.akamaihd.net*` </br>
`*.gcsp.cddbp.net*` </br>
`*.edgesuite.net*` </br>
`*windows.net*` </br>
`*gs.apple.com.akadns.net*` </br>
`*itunes.apple.com*` </br>
`*phobos.apple.com*` </br>


</br>


## **DNS**
---
### Apple Cache Record
DNSCMD . /recordadd curric.congupna-ps.wan _aaplcache._tcp 259200 TXT "prs=10.149.248.1-10.149.249.255"

### Reverse Lookup Zones

### Stale Records

### Aging & Scavenging

### Clear Cache


</br>


## **DHCP**
---
### Reservation

### Dynamically Update DNS


</br>


## **Server Apps**
---
### Hostname
Server App > Edit Host Name > Next > Internet
Computer Name: miniserv
Hostname: miniserv.curric.congupna-ps.wan
</br>
Add entry to local host file:
10.149.248.77 miniserv.local
[How to edit host file on Mac](https://www.imore.com/how-edit-your-macs-hosts-file-and-why-you-would-want)

### Reboot

### Push Diagnostics

### Apple Configurator 2

### macOS Server

### Caching
[Set up content caching](https://support.apple.com/en-au/guide/mac-help/set-up-content-caching-mchl3b6c3720/mac)

### Open Directory

### Service Accounts

### Profile Manager
If required, follow Apple's guide to [Reset Profile Manager to its original state](https://support.apple.com/en-au/HT202523).


</br>


## **Profile Manager**
---
-
Add service account for wireless under PEAP in Common Settings Device Group -> Network Settings;
Don't need to add wireless certificate separately.


</br>


## **Apple Configurator 2**
---
### Blueprints

### Prepare & Enroll Devices