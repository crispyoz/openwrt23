#!/bin/ash
#
# Check open ports on each active host
#
set -x
ip_src=$(echo "$2" | cut -d. -f1-3)
nmap -sn $2/$3 | grep -i "report for" | awk -F" " '{ print $5 }' | grep -i $(echo "$2" | cut -d. -f1-3)  | xargs nmap -v -n | grep -i "discovered open port" | awk -F" " '{ print $6 " " $4 }' | sort -n >> $4
echo "------------------------------------" >> $4
