#!/bin/bash
#set -x

ips=(1 3 8 9 11 12 102 201 202 203)
addr=$(echo $2 | cut -d. -f1-3)

for ip in "${ips[@]}"
do
        nmap -v -n $addr.$ip  >> $4
done
echo "------------------------------------" >> $4

