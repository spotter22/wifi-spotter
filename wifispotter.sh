#!/bin/env bash



_usage()
{

	echo "\
  Usage: wifispotter [parameters]
  Connect mode:
     -c[x|xx|g]
        x = Connect to Wi-Fi network.
        g = Connec as ghost.
        xx = Connect with survival mode.
        bf = Connect with bruteforcing the requests.
  Extra option:
     -x[x|t|r|:|MAC|a|c|i|e|s]
        x = Extract and store PSK.
        t = Perform eligibility test.
        r = Reset Wi-Fi settings.
        : = Sets random MAC to the device.
        MAC = Sets passed MAC to device.
               allowed format: xx:xx:xx:xx:xx:xx
        a = Process entire available requests.
        c = Check total available requests.
        i = Import requests from the temporary file.
        e = Export requests to the temporary file.
        s = Simulate serving.
   Mointor option:
     -m[e|m]
        e = Extender mode.
        m = Monitor mode.
  Advanced options:
      -t[n] Set max tries to n(max: 200) (default: 10).
      -r[n] Set max requests to n(1|2|3) (default: 1).
      -g[n] Set max ghosts to n(max: 9) (disable: 0) (default: 1).
      -v, verbose mode."

exit 0

}

_config()
{

	[ -z "$1" ] && _usage
	local mode more_options
	root_dir=/sdcard/Android/media/wifispotter
	verbose='no'
	simulate='no'
	entire_req='no'
while getopts c:x:t:r:g:m:v option
	do
		case "$option"
	in
		m) monitor_option="${OPTARG}";;
		x) more_options="${OPTARG}";;
		g) max_ghosts="${OPTARG}";;
		t) max_tries="${OPTARG}";;
		r) max_reqs="${OPTARG}";;
		v) verbose='yes';;
		c) mode="${OPTARG}";;
		?) _usage
	esac
done

	[ "$max_reqs" -le "3" ] 2>/dev/null && : || max_reqs="1"; [ "$max_reqs" -ge "4" ] && max_reqs="3"
	[ "$max_tries" -le "200" ] 2>/dev/null && : || max_tries="10"; [ "$max_tries" -ge "201" ] && max_tries="200"
	[ "$max_ghosts" -le "1000" ] 2>/dev/null && : || max_ghosts="1"; [ "$max_ghosts" -ge "1001" ] && max_ghosts="1000"


	if [ "$monitor_option" = "e" ]; then
		monitor_option="1"
	elif [ "$monitor_option" = "m" ]; then
		monitor_option="2"
	else
		monitor_option="0"
	fi


	if [ "$more_options" = "x" ]; then
		_xwifipsk
	elif [ "$more_options" = "t" ]; then
		test='0'; _select
	elif [ "$more_options" = "r" ]; then
		sudo wifispotter -xx; sudo cmd wifi settings-reset
		echo "- Reseting Wi-Fi settings finished!"
	elif [ "$more_options" = ":" ]; then
		_xset "::"
	elif [[ "$more_options" = *":"* ]]; then
		_xset "$more_options"
	elif [ "$more_options" = "s" ]; then
		simulate="yes"
	elif [ "$more_options" = "a" ]; then
		entire_req="yes"
	elif [ "$more_options" = "c" ]; then
		check_reqs="0"; test='0'; _select; _get_reqs
	elif [ "$more_options" = "i" ]; then
		check_reqs="1"; test='0'; _select; _serve
	elif [ "$more_options" = "e" ]; then
		check_reqs="2"; test='0'; _select; _get_reqs
	fi


	if [ "$mode" = "x" ]; then
		_select; _connect
	elif [ "$mode" = "xx" ]; then
		_survival_connect
	elif [ "$mode" = "bf" ]; then
		test='0'; _select; _serve
	elif [ "$mode" = "g" ]; then
		test='0'; _select; while true; do _ghost_serve; done
	fi
		exit 0

}


_xwifipsk()
{

		local f
		f="$root_dir/resources/discovered_psks.log"
	if [ -n "$wifisec" ] && [ "$wifisec" != "open" ]; then
		psk="$(grep -F "${ssid:1:-1}" "$f" | awk '{print $2}')" && psk="${psk:1:-1}"
		[ -z "$psk" ] && echo "- Error: Wi-Fi PSK is not found !" && exit 1
		return
	elif [ "$wifisec" = "open" ]; then
		return 0
	fi

		__xentry()
	{
					y="$(echo -n "$y" | sed 's/psk=//g' | tr -d '"\t')"
				if grep -F "'$x'" "$f" >/dev/null 2>&1; then
					if ! grep -F "'$x'" "$f" | grep -Fsco "'$y'" >/dev/null 2>&1; then echo "'$x'" "'$y'" dpsk >>"$f"; fi
				elif grep -F "'$y'" "$f" >/dev/null 2>&1; then
					if ! grep -F "'$y'" "$f" | grep -Fsco "'$x'" >/dev/null 2>&1; then echo "'$x'" "'$y'" dssid >>"$f"; fi
				else
					echo "'$x'" "'$y'" >>"$f"
				fi
	}

		f1="/data/misc/apexdata/com.android.wifi/WifiConfigStore.xml"
		f2="/data/misc/wifi/wpa_supplicant.conf"
		if [ -f "$f1" ] && [ -r "$f1" ]; then
			grep -FB1 '<string name="PreSharedKey">' "$f1" | sed 's/&quot;//g; s/<string name=".*">//g; s/<\/string>//g; /--/d' | while read y; do
				if [ -z "$x" ]; then
					x="$y"
				else
					__xentry
					x=""
				fi
			done
		elif [ -f "$f2" ] && [ -r "$f2" ]; then
			grep -A1 'ssid=' "$f2" | grep -Ev 'bssid=|scan_ssid=' | sed 's/ssid=//g; s/"//g; /--/d' | while read y; do
				if [ -z "$x" ]; then
					x="$y"
					continue
				else
						if [[ "$y" = *"psk="* ]]; then
							__xentry
						else
							y="$(grep -A3 "$x" "$f2" | sed -n 3p)"
								[[ "$y" = *"psk="* ]] && __xentry
									y="$(grep -A4 "$x" "$f2" | sed -n 4p)"
										[[ "$y" = *"psk="* ]] && __xentry
						fi
				fi
				x=""
			done
		fi
		exit 0

}


_xset()
{

			m="${1,,}"
	if [ "$simulate" = "no" ]; then
			[ "$m" != "::" ] && _status 1
		if [ "$m" = ":" ] || [ "$m" = "::" ]; then
			x=($(macchanger -r wlan0 | grep -E 'Current|New' | awk '{print $3}'))
			_echo "- Requesting for ghost: ${x[1]}"
		else
			x=($(macchanger -m "$m" wlan0 | grep -E 'Current|New' | awk '{print $3}'))
			_echo "- Requesting for client: ${x[1]}"
		fi
	else
		_echo "- Simulating: $m"
	fi

}

wifiscan()
{
devname="$1"

echo -e "$(iw $devname scan | sed -e 's#(on wlan# (on wlan#g' | awk '
BEGIN {
  printf("[\n")
}
NF > 0 {
  if ($1 == "BSS") {
    if ($2 ~ /^[a-z0-9:]{17}$/) {
      if (e["MAC"]) {
        printf("{\"mac\":\"%s\",\"ssid\":\"%s\",\"freq\":\"%s\",\"sig\":\"%s\",\"sig%\":\"%s\",\"wpa\":\"%s\",\"wpa2\":\"%s\",\"wep\":\"%s\",\"tkip\":\"%s\",\"ccmp\":\"%s\"},\n",
          e["MAC"], e["SSID"], e["freq"], e["sig"], e["sig%"], e["WPA"], e["WPA2"], e["WEP"], e["TKIP"], e["CCMP"]);
      }
      e["MAC"] = $2;
      e["WPA"] = "n";
      e["WPA2"] = "n";
      e["WEP"] = "n";
      e["TKIP"] = "n";
      e["CCMP"] = "n";
    }
  }
  if ($1 == "SSID:") {
    e["SSID"] = substr($0, index($0,$2));
  }
  if ($1 == "freq:") {
    e["freq"] = $NF;
  }
  if ($1 == "signal:") {
    e["sig"] = $2 " " $3;
    e["sig%"] = (60 - ((-$2) - 40)) * 100 / 60;
  }
  if ($1 == "WPA:") {
    e["WPA"] = "y";
  }
  if ($1 == "RSN:") {
    e["WPA2"] = "y";
  }
  if ($1 == "WEP:") {
    e["WEP"] = "y";
  }
  if ($4 == "CCMP" || $5 == "CCMP") {
    e["CCMP"] = "y";
  }
  if ($4 == "TKIP" || $5 == "TKIP") {
    e["TKIP"] = "y";
  }
}
END {
  printf("{\"mac\":\"%s\",\"ssid\":\"%s\",\"freq\":\"%s\",\"sig\":\"%s\",\"sig%\":\"%s\",\"wpa\":\"%s\",\"wpa2\":\"%s\",\"wep\":\"%s\",\"tkip\":\"%s\",\"ccmp\":\"%s\"}\n",
    e["MAC"], e["SSID"], e["freq"], e["sig"], e["sig%"], e["WPA"], e["WPA2"], e["WEP"], e["TKIP"], e["CCMP"]);
  printf("]\n")
}')"
}

_status()
{

if [ $1 -eq 0 ]; then
	if su -c cmd wifi status | grep -Fos "Wifi is disabled" >/dev/null 2>&1; then
		if which svc >/dev/null 2>&1; then
			echo "- Enabling Wi-Fi"
			svc wifi enable && sleep 1.0
		fi
	fi
		return 0
fi

if [ $1 -eq 2 ]; then
	if su -c cmd wifi status | grep -Fos "Wifi is disabled" >/dev/null 2>&1; then
		echo "- Exiting... Wi-Fi is disbled by user"
		exit 0
	fi
		return 0
fi

if [ $1 -eq 3 ]; then

	echo "- Performing eligibility test..."
	_status 1; _connect

	devmac="$(netspotter -s1 --print-devmac)"
	if [ "$2" = "$devmac" ]; then
		echo -e "- Test has been passed !"
		return 0
	else
		echo "- An error occurred while trying to set dev address."
		_echo "   Requested MAC: $2\n   Returned MAC: $devmac"
		exit 1
	fi
fi

#su -c cmd wifi status | grep -Fos "Wifi is not connected" >/dev/null 2>&1

if [ $1 -eq 1 ]; then
		local id f
		f="$root_dir/logs/tmp"
		su -c cmd wifi list-networks>"$f"
		su -c iw dev wlan0 disconnect
	 while true; do
			id="$(grep -Fm1 "${ssid:1:-1}" "$f" | awk '{print $1}')"
			#auth="$(grep -Fm1 "${ssid}" "$f" | awk '{print $3}')"
			#[ "${auth:0:4}" = "open" ]
		if [ -n "$id" ]; then
			_echo "- Removing ID: $id"
			su -c cmd wifi forget-network "$id" >/dev/null 2>&1
			return 0
			#test "${auth:0:4}" = "wpa2" -o "wpa3"
		else
			return 0
		fi
	done
fi

}


_select()
{
	local IFS i x
	IFS=$'\n'
	_status 0
	_scan_wifi()
	{
		echo "- Starting: Wi-Fi scan..."
		wifi_stat="$(wifiscan wlan0 2>/dev/null | jq . 2>/dev/null)"
		#[[ "$wifi_stat" = *"Operation not permitted"* ]] && echo "Error insufficient permission !" && exit 1
		ssid_list=($(echo "$wifi_stat" | jq . 2>/dev/null | grep -F ssid | sed "s/.*: //g; s/,//g"))
		[ "$ssid_list" = '""' ] && echo -e "- The scan result was empty !\n- Make sure to run the program as root." && exit 1
		bssid_list=($(echo "$wifi_stat" | jq . 2>/dev/null | grep -F mac | sed "s/.*: //g; s/,//g; s/\"//g"))
		wpa_list=($(echo "$wifi_stat" | jq . 2>/dev/null | grep -F 'wpa":' | sed "s/.*: //g; s/,//g; s/\"//g"))
		wpa2_list=($(echo "$wifi_stat" | jq . 2>/dev/null | grep -F 'wpa2":' | sed "s/.*: //g; s/,//g; s/\"//g"))
		wep_list=($(echo "$wifi_stat" | jq . 2>/dev/null | grep -F 'wep":' | sed "s/.*: //g; s/,//g; s/\"//g"))
		sig_list=($(echo "$wifi_stat" | jq . 2>/dev/null | grep -F 'sig":' | sed "s/.*: //g; s/,//g"))
	}

	_wifisec()
	{
		wifisec=""
		[ "${wep_list[$1]}" = "y" ] && wifisec="wep"
		[ "${wpa_list[$1]}" = "y" ] && wifisec="wpa"
		[ "${wpa2_list[$1]}" = "y" ] && wifisec="wpa2"
		[ -z "$wifisec" ] && wifisec="open"
	}

	x="s"
while [ "$x" = "s" ]; do
		_scan_wifi; i="0"; total_wifi='0'
	for x in ${ssid_list[@]}; do
		_wifisec "$i"
		total_wifi=$((total_wifi+1))
		echo -e "   ${i}) $x [$wifisec, ${sig_list[$i]:1:-1}]"; i=$((i+1))
	done
		echo -e "  s) Scan again\n  x) Exit"
		read -p "- Please enter your option:" x
		[ "$x" = "x" ] && exit 0
	if [ "$x" != "s" ]; then
		ssid="${ssid_list[$x]}"
		bssid="${bssid_list[$x]}"
		_wifisec "$x"
		break
	fi
done

		[ "$simulate" = "no" ] && [ "$test" = '0' ] && { _xset :; _status 3 "${x[1]}"; }

}

_connect()
{

		local t
		t="0"
		psk=""
		_echo "- Trying to connect: $ssid"
		_xwifipsk
	while true; do
		t=$((t+1))
	if [ "$wifisec" = "open" ]; then
		su -c cmd wifi connect-network "${ssid}" open >/dev/null 2>&1
	else
		#_echo "- Trying PSK: $psk"
		su -c cmd wifi connect-network "${ssid}" "$wifisec" "${psk}" >/dev/null 2>&1
	fi
		sleep 0.1
		su -c cmd wifi status | grep -Fos "Wifi is connected to" >/dev/null 2>&1 && \
			{
				[ "$t" = "1" ] && _echo "- Connection succedd !" && _echo "- Waiting for DHCP..."
				devip="$(ip r | awk '{print $9}')"; [ -n "$devip" ] && _echo "- Device IP: $devip" && echo -e "- Totoal connect attempts: $t" && return 0 || sleep 0.1
			}
		[ "$t" -ge "200" ] && _echo "- Maximum connection tries exceeded !" && break
	done

}

_ghost_serve()
{

		[ "$simulate" = "yes" ] && return 0
		local i
		i="$max_ghosts"
	if [ "$i" != "0" ]; then
		until [ $i -eq 0 ]; do
			i=$((i-1))
			_xset :
			_status 1
			_connect
		done
	fi
		
}

_get_reqs()
{

		[ "$check_reqs" = "1" ] && { [ -f "$root_dir/logs/x.log" ] && list="$(cat "$root_dir/logs/x.log" | tr ' ' '\n' | grep '[^\n]')" || exit 1; }
		local f1 f2 gid
		f1="$root_dir/resources/discovered_units.log"
		f2="$root_dir/resources/discovered_devices.log"
	if [ "$entire_req" = "no" ]; then
				_echo "- Waiting for GID response..."
				gid="$(netspotter -s1 --print-gid)"
				[ -z "$gid" ] && echo "- Error could not get the GID" && exit 1
				bssid_list="$(grep "$gid" "$f1" | awk '{$1=""}; {print $0}')"
			if [ "$monitor_option" = "1" ]; then
				bssid_list+=" ${bssid_list[@]}"
			fi
			total_query="0"
		for x in $bssid_list; do
			total_query=$((total_query+1))
			list+="$(grep "$x" "$f2" | awk '{print $2}' | tr '\n' ' ') "
		done
	else
		total_query="0"
		list="$(grep "$x" "$f2" | awk '{print $2}' | tr '\n' ' ') "
	fi
		list="$(echo "$list" | tr ' ' '\n' | sort | uniq | grep '[^\n]' | sort -R | tr '\n' ' ')"; total_req="$(echo "$list" | tr ' ' '\n' | wc -l)"
		[ "$simulate" = "yes" ] && echo "$list">"$root_dir/logs/x.log"
		_echo "- Available networks: $total_wifi"
		_echo "- Available requests: $total_req"
		_echo "- Available queries: $total_query"
		_echo "- Max requests: $max_reqs"
		echo "- Max tries: $max_tries"
		[ "$check_reqs" = "0" ] && { rm -f "$root_dir/logs/x.log"; exit 0; }
		[ "$check_reqs" = "2" ] && { echo "$list">>"$root_dir/logs/x.log"; exit; }

}

_serve()
{

		local i t1 ex
		_get_reqs
		i="0"; _echo "- Ghosts count: $max_ghosts"; ex=""
	for x in $list; do
		i=$((i+1))
		echo "- Proccessing: $i/$max_tries"
		_xset "$x"
	if [ "$simulate" = "no" ]; then
		if [[ "$ex" != *"$x"* ]]; then
			ex+="$x "
			_status 1
			_connect
			cred x && max_reqs=$((max_reqs-1))
			_ghost_serve
		fi
	fi
		[ "$i" -ge "$max_tries" ] && break
		[ "$max_reqs" -eq "0" ] && break
	done
	_status 1

}

_survival_connect()
{

	_select
	echo "- Starting: Survival Wi-Fi connecting..."
	echo "- Target SSID: $ssid"
while true; do
		sleep 1
	if [ -z "$(ip n)" ]; then
		echo -e "- Disconnection was occurred !"
		_status 2
		_status 1
		_connect
	fi
done
	exit 0

}

_echo()
{

	if [ "$verbose" = 'yes' ]; then
		echo -e "$1"
	fi

}

_config "$@"
