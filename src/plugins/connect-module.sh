#!/bin/bash


_connect_module_cmdwifiscan(){
	local i u arr; i=0
	su -c 'cmd wifi list-scan-results' &>"${result}"
	echo "EOF" >>"${result}"
while read u; do
	[[ "${u}" =~ (No scan results) ]] && continue
	echo $u; continue
	if [ "${u}" = "EOF" ]; then
		list+=']'
	fi
		arr=(${u})
	if [ ${i} -ge 1 ]; then
		list+=\"mac\":${arr[0]}
	elif [ ${i} -eq 0 ]; then
		list='['
	fi
done< <(cat "${result}")
}


_connect_module_iwscan(){
	local iface result prefix
	[ -z "${1}" ] && iface="wlan0" || iface="${1}"
	[ -z "${2}" ] && result="./iwscan.log" || result="${2}"
	[ -z "${3}" ] && prefix="${PREFIX}/bin/" || prefix="${3}"
	echo "_connect_module_iwscan: starting wifi scan..."
	su -c ''${prefix}'/timeout -k10 10 '${prefix}'/iw '${iface}' scan 2>&1' >"${result}"
}


_connect_module_iwparse(){
		local input output x
		[ -z "${1}" ] && input="./iwscan.log" || input="${1}"
		[ -z "${2}" ] && output="./iwscan.json" || output="${2}"
		[ -s "${input}" ] || { echo "_connect_module_iwparse: can not read: ${input} (err: file is empty)"; return 1; }
		echo "_connect_module_iwparse: starting parsing..."
	while read x; do
		[[ "${x}" =~ "command failed: Operation not permitted" ]] && { echo "_connect_module_iwparse: root is required (err: ${x})"; return 1; }
		[[ "${x}" =~ "command failed: Network is down" ]] && { echo "_connect_module_iwparse: wifi is disabled (err: ${x})"; return 2; }
		[[ "${x}" =~ "command failed: Device or resource busy" ]] && { echo "_connect_module_iwparse: device is busy (err: ${x})"; return 3; }
	done< <(cat "${input}")
	echo -e "$(cat "${input}" | sed -e 's#(on wlan# (on wlan#g' | awk '
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
	      e["LAST"] = "n";
	    }
	  }
	  if ($1 == "SSID:" && e["LAST"] == "n") {
	    e["LAST"] = "y"; e["SSID"] = substr($0, index($0,$2));
	    gsub("\x1e", "0", e["SSID"]);
		gsub("\"", "\\&quot;", e["SSID"]);
		gsub(/'\''/, "\\&squot;", e["SSID"]);
		gsub("\\\\x5c", "\\&bslash;", e["SSID"]);
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
	}')" | tr '\0' '0' >"${output}"
	return 0
}


_connect_module_iwselect(){
	local input output
	[ -z "${1}" ] && input="./iwscan.json" || input="${1}"
	#[ -z "${2}" ] && output="./iwscan.json" || output="${2}"
	local i t IFS result ssid wifiscan_date u
		t=0; IFS=$'\n'
	i=0; unset list_wifi_view list_wifi_json


		local i x z
	while read x; do
		if [[ "${x}" =~ "\"mac\": " ]]; then
			z[1]="${x/    \"mac\": \"/}"; z[1]="${z[1]/\",/}"
		elif [[ "${x}" =~ "\"ssid\": " ]]; then
			z[2]="${x/    \"ssid\": \"/}"; z[2]="${z[2]/\",/}"
		elif [[ "${x}" =~ "\"sig%\": " ]]; then
			z[3]="${x/    \"sig%\": \"/}"; z[3]="${z[3]/\",/}"
			z[3]="${z[3]/.*/}"
		elif [[ "${x}" =~ "\"wpa\": \"y\"" ]]; then
			z[4]="🔒WPA"
		elif [[ "${x}" =~ "\"wpa2\": \"y\"" ]]; then
			z[4]="🔒WPA2"
		elif [[ "${x}" =~ "\"wep\": " ]]; then
			[[ "${x}" =~ "\"wep\": \"y\"" ]] && z[4]="🔒WEP"
			[ -n "${z[1]}" ] && [ -z "${z[4]}" ] && z[4]="🔑Open"
		fi
		if [ -n "${z[4]}" ]; then
			i=$((i[0]+1))
			echo "${i}) ${z[2]} ${z[4]} ${z[3]}%"
			unset z
		fi
	done< <(jq . "${input}")
	exit
		# parse result
		bssid_list=($(cat "${input}" | jq -r .[].mac 2>"${home_dir}/logs/err"))
			[ -s "${home_dir}/logs/err" ] && { _echo "\t${color_error}Unexpected return of wifiscan exiting...${color_reset}" 1; echo "${result}" >"${home_dir}/logs/wifiscan_result_json_${wifiscan_date}.log"; cat "${home_dir}/logs/tmp" >"${home_dir}/logs/wifiscan_result_${wifiscan_date}.log"; return 1; }
			[ -z "${bssid_list[0]}" ] && { sleep 1.0; continue; }
				ssid_list=($(echo "$result" | jq .[].ssid))
					freq_list=($(echo "$result" | jq -r .[].freq))
						wpa2_list=($(echo "$result" | jq -r .[].wpa2))
							wpa_list=($(echo "$result" | jq -r .[].wpa))
								wep_list=($(echo "$result" | jq -r .[].wep))
									sig_list=($(echo "$result" | jq -r '.[]."sig%"' | awk -F '.' '{print $1}'))
	for ssid in ${ssid_list[@]}; do
		if [ "${wpa2_list[$i]}" = "y" ]; then
			secX[$i]="🔒"
			secY[$i]="wpa2"
		elif [ "${wpa_list[$i]}" = "y" ]; then
			secX[$i]="🔒"
			secY[$i]="wpa"
		elif [ "${wep_list[$i]}" = "y" ]; then
			secX[$i]="🔒"
			secY[$i]="wep"
		else
			secX[$i]="🔑"
			secY[$i]="open"
		fi
			u="${ssid:1:-1}"
		if [ -z "${u//0/}" ]; then
			ssid="\"hidden_ssid_${bssid_list[$i]//:/}\""
			ssid_list[$i]="${ssid}"
		fi
		if [ $i -eq 0 ]; then
			ssid="${ssid:1:-1}"; ssid="${ssid//&quot;/\"}"; ssid="${ssid//&squot;/\'}"; ssid="${ssid//&bslash;/\\}"
			list_wifi_view[$i]="SSID:@Sec:@Sig:\n ${i}) ${ssid}@${secX[$i]}@${sig_list[$i]}%\n"
		else
			ssid="${ssid:1:-1}"; ssid="${ssid//&quot;/\"}"; ssid="${ssid//&squot;/\'}"; ssid="${ssid//&bslash;/\\}"
			list_wifi_view[$i]="${i}) ${ssid}@${secX[$i]}@${sig_list[$i]}%\n"
		fi
		if [ -z "$list_wifi_json" ]; then
			list_wifi_json='"'${bssid_list[$i]}'":{"ssid":'${ssid_list[$i]}',"freq":"'${freq_list[$i]}'","sec":"'${secY[$i]}'"}'
		else
			list_wifi_json=''${list_wifi_json}',"'${bssid_list[$i]}'":{"ssid":'${ssid_list[$i]}',"freq":"'${freq_list[$i]}'","sec":"'${secY[$i]}'"}'
		fi
			i=$((i+1))
	done
			return 0

}



_connect_module_wifiscan_select(){
	local p pad cur_bssid b
	ssid=0; bssid=0; sec=0; p="s"
	pad="============================================="
while true; do
	if [ "$p" = "s" ]; then
				_wificonnect_getinfo || return 1
				[ "${wifi_force_select}" = "yes" ] || \
					cur_bssid="$(su -c ''${prefix}'/iw dev '${iface}' link 2>&1 | '${prefix}'/grep -Po '\''Connected to \K[^ ]*'\''')"
		if [ "${wifi_force_select}" = "yes" ]; then
			_echo "\t\t_wificonnect_select --> manually wifi connect mode is requested" 0
		elif [ -z "${cur_bssid}" ]; then
			_echo "_wificonnect_select --> warnning current bssid is null" 0
		elif _wificonnect_status "is_connected" "${cur_bssid}"; then
				p=0
			for b in ${bssid_list[@]}; do
				if [ "$b" = "$cur_bssid" ]; then
					bssid="${bssid_list[$p]}"
						[ -z "${bssid}" ] && { _echo "\tError BSSID2 is: null"; return 1; }
					ssid="${ssid_list[$p]}"
					sec="${secY[$p]}"
					return 0
				fi
					p=$((p+1))
			done
		fi
	fi
		echo -e "${list_wifi_view[@]}" | column -t -s $'@' | sed "s|Sig:|Sig:\n${pad}|"
		echo -e "s) Scan again\nx) Exit\n${pad}"
		read -p "- Please enter your option:" p
	if [ -z "${p}" ]; then
		p=0; _echo "\t${color_error}Error you have entered: null${color_reset}" 1
		_echo "\t${color_tip}Tip: Type your option, then click enter${color_reset}" 1; sleep 3; continue
	elif [ "${p}" = "s" ]; then
		p="s"; continue
	elif [ "${p}" = "x" ]; then
		return 1
	elif [[ "${p:0:1}" = [0-9] ]] || [[ "${p:0:2}" = [0-9][0-9] ]]; then
		bssid="${bssid_list[$p]}"
			[ -z "${bssid}" ] && continue
		ssid="${ssid_list[$p]}"
		sec="${secY[$p]}"
		return 0
	else
		_echo "\t${color_error}${p} is invalid option, try again${color_reset}" 1; sleep 3; continue
	fi
done
}


_connect_module_wifiscan_connect(){
	local u t i x target_ssid ssid sec psk psk_tries is_first
	ssid="${1}"; sec="${2}"; bssid="${3}"
	ssid=$"${ssid:1:-1}"
	t=0; connected="no"; psk_tries=0; is_first="yes"
	[ -z "${max_tries}" ] && max_tries=3 || { [ ${max_tries} -ge 0 ] || { _echo "_wificonnect_connect --> error max tries equals: ${max_tries}" 0; return 1; }; }
	_echo "\t\t_wificonnect_connect --> trying to connect with: [ssid](${ssid}) [bssid](${bssid}) [sec](${sec})" 0
while true; do
		t=$((t+1))
	if [ "${bruteforce_psk}" = "yes" ]; then
		[ "${is_first}" = "no" ] && [ ${psk_tries} -eq 0 ] && break
		[ "${is_first}" = "no" ] && \
		[ $t -ge ${max_tries} ] && \
		{ t=0; psk_tries=$((psk_tries-1)); }
	else
		[ $t -gt ${max_tries} ] && break
	fi
		_wificonnect_status "is_disabled" || return 1
		_echo "\tTrying connect to: ${ssid}" 1
		_echo "\t\t_wificonnect_connect --> connection attempt: ${t}" 0
	if [[ "${ssid}" =~ (\&squot\;|hidden_ssid_*) ]]; then
		_echo "\t${color_error}Not supported yet connecting to:${color_reset} ${ssid}" 1
		return 1
	else
		target_ssid="${ssid//&quot;/\"}"
		target_ssid="${target_ssid//&bslash;/\\}"
	fi
	if [ "$sec" = "open" ]; then
		u=$(su -c ''${prefix}'/cmd wifi connect-network '\'''${target_ssid}''\'' open '${cmd_wifi_args}' 2>&1 | tr -d "\n"')
		[ "${bssid}" = "unknown" ] && return 0
		sleep 3
	else	
		if [ "${is_first}" = "yes" ]; then
					is_first="no"
				if [ "${bruteforce_psk}" = "yes" ]; then
					psk[0]="000000000"
					psk[1]="12345678"
					psk[2]="123123123"
					psk[3]="123456789"
					psk[4]="1234567890"
					psk[5]="0123456789"
					psk[6]="987654321"
					psk[7]="147258369"
					psk[8]="999999999"
					psk_tries=$((psk_tries+8))
				fi
			while read -r u; do
					if [ -z "${u}" ]; then
						continue
					elif [ ${psk_tries} -eq 1 ]; then
						psk[$psk_tries]="$u"
					else
						psk_tries=$((psk_tries+1))
						psk[$psk_tries]="$u"
					fi
			done< <(jq --arg s "${ssid}" '.ws.psk.[$s]' "${db_file}" | sed '/\[/d; /\]/d; /null/d; s/\,//g; s/\"//g')
		fi
				[ -n "${psk[${psk_tries}]}" ] || { _echo "\tNo PSK found" 1; break; }
				[ ${#psk[${psk_tries}]} -le 7 ] && { _echo "\tSkipping short PSK: ${psk[${psk_tries}]}" 1; _echo "\t\t_wificonnect_connect --> warnning skipping psk with too short length: [psk_tries](${psk_tries}) [psk](${psk[${psk_tries}]})" 0; psk_tries=$((psk_tries-1)); continue; }
				_echo "\tTrying PSK: ${psk[${psk_tries}]}" 1
				_echo "\t\t_wificonnect_connect --> trying psk: [psk_tries](${psk_tries}) [psk](${psk[${psk_tries}]})" 0
				u=$(su -c ''${prefix}'/cmd wifi connect-network '\'''${target_ssid}''\'' "'${sec}'" "'${psk[${psk_tries}]}'" '${cmd_wifi_args}' 2>&1 | tr -d "\n"')
				sleep 5
	fi

		# cmd wifi on sucess can return either null or "Connection initiated"
	if [ -n "${u}" ] && [[ ! "${u}" =~ "Connection initiated" ]] && [[ ! "${u}" =~ "autojoin setting skipped" ]]; then
			_echo "\tUnexpected return: ${u}" 1; _echo "\t\t_wificonnect_connect --> unexpected return: (${u})" 0
			return 1
	else
		if [[ "${u}" =~ "autojoin setting skipped" ]]; then
			unset cmd_wifi_args
		fi
			_wificonnect_status "is_connected" "${bssid}"
		if [ $? -eq 0 ]; then
			_echo "\t${color_success}Connection succedd !${color_reset}" 1
			return 0
		elif [ $? -eq 2 ]; then
			_echo "\t${color_warn}Timeout on: ${ssid}${color_reset}" 1
			[ -n "${psk_tries}" ] && continue
			return 1
		else
			continue
		fi
	fi
done
	_echo "\t${color_error}Failed connecting to: ${ssid}${color_reset}" 1
	return 1
}


#_connect_module_iwscan
_connect_module_iwparse
_connect_module_iwselect


