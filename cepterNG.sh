#!/bin/env bash

#   Intercepter-NG helper

usage (){
printf -- "Usage: $main [parameters]
a\tAdd target manually
l\tList targets
rm\tRemove target
c\tRemove all targets
h\tAdd hosts automatically
t\tAdd targets automatically
b\tBackup iptables
r\tRestore iptables
"
}

root_dir=~/root_dir
cepter_root='/sdcard/Android/media/su.sniff.cepter'
cepter_data='/data/data/su.sniff.cepter/files'
#cepter_data='/data_mirror/data_ce/null/0/su.sniff.cepter/files'
mkdir -p "$cepter_root"
main="$(printf "$0" | tr '/' '\n' | tail -n 1)"

check_len (){
  ip_len="$(printf "$gateway_ip" | tr "." "\n" | wc -l)"
  gateway_mac="$(printf "$gateway_mac" | tr -d "[ ]" | tr "-" ":")"
  mac_len="$(printf "$gateway_mac" | tr ":" "\n" | wc -l)"
# if [ "$ip_len" = "3" ] && [ "$mac_len" = "5" ]; then
if [ "$ip_len" != "3" ]; then
  printf -- "- [$main] Error incorrect IP lengh [$ip_len] ! ..\n"
  exit 1
 elif [ "$mac_len" != "5" ]; then
  printf -- "- [$main]  Error incorrect MAC lengh [$mac_len] ! ..\n"
  exit 1
 fi
}

copy_targets (){
if [ -s "$root_dir/logs/bwcepterng.log" ]; then
  printf -- "- [$main] Adding $(cat  "$root_dir/logs/bwcepterng.log" | grep '[^\n]' | wc -l) targets ! ..\n"
 if [ "$(ls "$cepter_data/cepter")" != '' ]; then
  cat  "$root_dir/logs/bwcepterng.log" | tr ':' '-' | tr '\t' ':' | grep '[^\n]'>"$cepter_data/targets"
  owner="$(ls -l "$cepter_data/cepter" | awk '{print $3}')"
  chown $owner:$owner "$cepter_data/targets"; chmod 660 "$cepter_data/targets"
 else
  printf -- "- [$main] Error Intercepter-NG app is not installed !\n"
 fi
else
  printf -- "- [$main] Error file missing: '$root_dir/logs/bwcepterng.log'\n"
  exit 1
fi
}

if [ "$1" = "a" ]; then
 printf -- "- [$main] Adding new entry ..\n"
 read -p "- [$main] IP address: " gateway_ip
 read -p "- [$main] MAC address: " gateway_mac
 check_len
 gateway_mac="$(printf "$gateway_mac" | tr ":" "-")"
 printf -- "$gateway_ip:$gateway_mac\n">>"$cepter_data/targets"
elif [ "$1" = "rm" ]; then
 read -p "- [$main] Enter IP/MAC to remove: " entry
 sed -i -z "s/$entry\n//" "$cepter_data/targets"
elif [ "$1" = "c" ]; then
 printf -- "- [$main] Cleaning all entries ..\n"
 printf ''>"$cepter_data/targets"
elif [ "$1" = "l" ]; then
 printf -- "- [$main] Listing all entries ..\n"
 printf -- "- [$main] Current entries:\n"
 cat "$cepter_data/targets"
elif [ "$1" = "b" ]; then
 printf -- "- [$main] Backing-up iptables ..\n"
 iptables-save>"$cepter_root/iptables.cfg"
elif [ "$1" = "r" ]; then
 printf -- "- [$main] Restoring iptables ..\n"
 iptables -F
 iptables-restore "$cepter_root/iptables.cfg"
elif [ "$1" = "h" ]; then
  gateway_ip="$(ip route | grep -vF 'default' | awk '{printf $1}' | sed 's#./..#1#' | sed 's#./.#1#')"
  gateway_mac="$(ip neigh | grep -F "$gateway_ip" | grep -o '..:..:..:..:..:..' | sed -n 1p)"
  check_len
  printf -- "- [$main] Adding gateway to hostlist:\n"
  printf "\tGatewayIP: $gateway_ip\tGatewayMAC: $gateway_mac\n"
  printf "$gateway_ip:$gateway_mac\n">"$cepter_data/hostlist"
  mac2="$(printf "$gateway_mac" | tr ':' '-' | tr '[:lower:]' '[:upper:]')"
  printf "$gateway_ip (-)\nUnix }: Unknown [$mac2]\n">"$cepter_data/lasthosts.$gateway_mac"
  owner="$(ls -l "$cepter_data/cepter" | awk '{print $3}')"
  chown $owner:$owner "$cepter_data/hostlist"; chown $owner:$owner "$cepter_data/lasthosts.$gateway_mac"; chmod 660 "$cepter_data/hostlist"; chmod 660 "$cepter_data/lasthosts.$gateway_mac"
elif [ "$1" = "t" ]; then
  copy_targets
else
  usage
  printf -- "- [$main] Incorrect parameter\n"
  exit 1
fi

   printf -- "- [$main] Completed!\n"