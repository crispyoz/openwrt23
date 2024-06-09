#!/bin/sh
#
# 
#set -x


#iw $3 scan | grep -i -e "ssid" -e  "primary channel" >> $2
#echo "----" >> $2
iwinfo $3 scan | grep -i -e "Address" -e  "Mode" -e "ESSID" -e  "Encryption" >> $2
echo "--------------------------------------" >> $2

