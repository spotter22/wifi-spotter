#!/bin/bash


_connection_wifiscan_iwscan(){
	local iface output prefix
	[ -z "${1}" ] && iface="wlan0" || iface="${1}"
	[ -z "${2}" ] && output="./output.log" || output="${2}"
	[ -z "${3}" ] && prefix="${PREFIX}/bin" || prefix="${3}"

	echo "_connection_wifiscan_iwscan: starting wifi-scan..."
	su -c ''${prefix}'/timeout -k10 10 '${prefix}'/iw '${iface}' scan 2>&1' >"${output}"

	return 0
}


_connection_wifiscan_iwparse(){
		local input output x
		[ -z "${1}" ] && input="./output.log" || input="${1}"
		[ -z "${2}" ] && output="./output.json" || output="${2}"

		[ -s "${input}" ] || { echo "_connection_wifiscan_iwparse: can not read: ${input} (err: file is empty)"; return 1; }

		echo "_connection_wifiscan_iwparse: starting parsing..."
	while read x; do
		[[ "${x}" =~ "command failed: Operation not permitted" ]] && { echo "_connection_wifiscan_iwparse: error root is required (err: ${x})"; return 2; }
		[[ "${x}" =~ "command failed: Network is down" ]] && { echo "_connection_wifiscan_iwparse: error wifi is disabled (err: ${x})"; return 3; }
		[[ "${x}" =~ "command failed: Device or resource busy" ]] && { echo "_connection_wifiscan_iwparse: error device is busy (err: ${x})"; return 4; }
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


_connection_wifiscan_iwselect(){
	wifi_array=(0); wifi_json=(0)
	local input x
	[ -z "${1}" ] && input="./outout.json" || input="${1}"

	while true; do
		wifi_array[0]=$((wifi_array[0]+1))
		wifi_json[0]=$((wifi_json[0]+1))
	done< <(cat "${input}" | jq -c '.[]')
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


_connection_interface_connect(){
	ret=0
	local ssid sec iface prefix result
	[ -z "${1}" ] && unset ssid || ssid="${1}"
	[ -z "${2}" ] && sec="open" || sec="${2}"
	[ -z "${3}" ] && iface="wlan0" || iface="${3}"
	[ -z "${4}" ] && prefix="${PREFIX}/bin" || prefix="${4}"

	echo "_connection_interface_connect: optimizing passed info ssid: ${ssid} sec: ${sec}"

	[[ "${ssid}" =~ "&squot;" ]] && ssid="${ssid//&squot;/\\\'}"
	[[ "${ssid}" =~ "&quot;" ]] && ssid="${ssid//&quot;/\\\"}"
	[[ "${ssid}" =~ "&bslash;" ]] && ssid="${ssid//&bslash;/\\\\}"
	[[ "${ssid}" =~ " " ]] && ssid="${ssid// /\\ }"
	[[ "${ssid}" =~ "*" ]] && ssid="${ssid//\*/\\*}"
	[[ "${ssid}" =~ "!" ]] && ssid="${ssid//\!/\\!}"
	[[ "${ssid}" =~ "?" ]] && ssid="${ssid//\?/\\?}"
	[[ "${ssid}" =~ ";" ]] && ssid="${ssid//\;/\\;}"
	[[ "${ssid}" =~ ":" ]] && ssid="${ssid//\:/\\:}"
	[[ "${ssid}" =~ "(" ]] && ssid="${ssid//\(/\\(}"
	[[ "${ssid}" =~ ")" ]] && ssid="${ssid//\)/\\)}"
	[[ "${ssid}" =~ "&" ]] && ssid="${ssid//\&/\\&}"
	[[ "${ssid}" =~ "|" ]] && ssid="${ssid//\|/\\|}"
	[[ "${ssid}" =~ "#" ]] && ssid="${ssid//\#/\\#}"
	if [[ "${ssid:0:1}" =~ (\") ]] && [[ "${ssid: -1}" =~ (\") ]]; then
		ssid="${ssid:1:-1}"
	fi

	echo "_connection_interface_connect: using optimized info ssid: ${ssid} sec: ${sec}"

	result=$(su -c 'local i; i=0; until ([ -n "$('${prefix}'/ip r)" ] || [ ${i} -ge 100 ]); do i=$((i+1)); echo "_connection_interface_connect: connecting into wifi attempt: ${i}"; '${prefix}'/cmd wifi connect-network '${ssid}' '${sec}' -d; done; [ ${i} -ge 100 ] && echo "ERROR" 2>&1' | tr '\n' '#')

	if [[ "${result}" =~ (ERROR) ]]; then
		ret="_connection_interface_connect: error could not connect to network (ret: ${result})."
		echo "${ret}"
		return 1
	else
		ret="${result}"
		echo "_connection_interface_connect: success (ret: ${ret})."
		return 0
	fi
}


_connection_interface_disconnect(){
	ret=0
	local method iface prefix result
	[ -z "${1}" ] && method="0" || method="${1}"
	[ -z "${2}" ] && iface="wlan0" || iface="${2}"
	[ -z "${3}" ] && prefix="${PREFIX}/bin" || prefix="${3}"

	if [ ${method} -eq 0 ] || [ ${method} -eq 1 ] || [ ${method} -eq 2 ]; then
		:
	else
		echo "_connection_interface_disconnect: warning unknown method is passed (method: ${method})."
		method=1
	fi

	if [ ${method} -eq 0 ] || [ ${method} -eq 1 ]; then
		[ ${method} -eq 1 ] && \
			{ _connection_interface_state "down" "${iface}" "${prefix}" && result="${ret}" || return 1; }

		result+=$(su -c 'local i; i=0; until ([ -z "$('${prefix}'/ip r)" ] || [ ${i} -ge 10 ]); do i=$((i+1)); echo "_connection_interface_disconnect: disconnecting from wifi attempt: ${i}"; '${prefix}'/iw dev '${iface}' disconnect; done; [ ${i} -ge 10 ] && echo "ERROR" 2>&1' | tr '\n' '#')

		[ ${method} -eq 1 ] && \
			{ _connection_interface_state "up" "${iface}" "${prefix}" && result+="${ret}" || return 1; }
	elif [ ${method} -eq 2 ]; then
		result=$(su -c 'local x y; y=$('${prefix}'/iw dev '${iface}' info | grep "ssid" | sed "s/.*ssid //"); [ -z "${y}" ] && exit 0; y=$(echo -e "${y}"); '${prefix}'/cmd wifi list-networks | grep "${y}" | awk '\''{print $1}'\'' | while read x; do echo "_connection_interface_disconnect: removing network with id: ${x}"; '${prefix}'/cmd wifi forget-network ${x} >/dev/null 2>&1; done' | tr '\n' '#')
	fi

	if [[ "${result}" =~ (ERROR|Usage:) ]]; then
		ret="_connection_interface_disconnect: error could not disconnect from network (ret: ${result})."
		echo "${ret}"
		return 1
	else
		echo "_connection_interface_disconnect: success (ret: ${result})."
		return 0
	fi

}


_connection_interface_state(){
	ret=0
	local mode iface prefix result
	[ -z "${1}" ] && mode="up" || mode="${1}"
	[ -z "${2}" ] && iface="wlan0" || iface="${2}"
	[ -z "${3}" ] && prefix="${PREFIX}/bin" || prefix="${3}"

	if [ "${mode}" = "down" ]; then
		result=$(su -c 'local i; i=0; until ([ -z "$('${prefix}'/ip r)" ] || [ ${i} -ge 3 ]); do i=$((i+1)); echo "_connection_interface_state: setting interface down attempt: ${i}"; '${prefix}'/ip link set dev '${iface}' down; done; [ ${i} -ge 3 ] && echo "ERROR" 2>&1' | tr '\n' '#')
	elif [ "${mode}" = "up" ]; then
		result=$(su -c 'echo "_connection_interface_state: setting up interface: '${iface}'"; '${prefix}'/ip link set dev '${iface}' up 2>&1' | tr '\n' '#')
	else
		echo "_connection_interface_state: error unknown mode is passed (mode: null)."
		return 1
	fi

	if [[ "${result}" =~ "ERROR" ]]; then
		ret="_connection_interface_state: error could not set ${mode} interface ${iface} (ret: ${result})."
		echo "${ret}"
		return 1
	else
		return 0
	fi

}


_connection_interface_setaddr(){
	ret=0
	local addr method iface prefix result
	[ -z "${1}" ] && addr="--random" || addr="${1}"
	[ -z "${2}" ] && method=1 || method=${2}
	[ -z "${3}" ] && iface="wlan0" || iface="${3}"
	[ -z "${4}" ] && prefix="${PREFIX}/bin" || prefix="${4}"

	if [ ${method} -eq 0 ] || [ ${method} -eq 1 ]; then
		:
	else
		echo "_connection_interface_setaddr: warning unknown method is passed (method: ${method})."
		method=1
	fi

	[ ${method} -eq 1 ] && \
		{ _connection_interface_state "down" "${iface}" "${prefix}" || return 1; }

	if [ "${addr}" = "--random" ]; then
		result=($(su -c ''${prefix}'/macchanger -r '${iface}' 2>&1 | '${prefix}'/sed "s|([^)]*)||g" 2>&1'))
	else
		result=($(su -c ''${prefix}'/macchanger -m '${addr}' '${iface}' 2>&1 | '${prefix}'/sed "s|([^)]*)||g" 2>&1'))
	fi

	# 2, 5, 8
	if [[ "${result[@]}" =~ (ERROR|Usage:) ]]; then
		ret="_connection_interface_setaddr: error could not set address ${addr} (ret: ${result[@]})."
		echo "${ret}"
		return 1
	else
		echo "_connection_interface_setaddr: success (ret: ${result[@]})."
	fi

	[ ${method} -eq 1 ] && \
		{ _connection_interface_state "up" "${iface}" "${prefix}" || return 1; }

	ret="${result[8]}"
	return 0
}

#_connection_wifiscan_iwscan
#_connection_wifiscan_iwparse
#_connection_wifiscan_iwselect
