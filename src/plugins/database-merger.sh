#!/bin/bash

					_validate_db()
								{
									index=(0 0 0 0)
									jq -e 'has("ws")' "${1}" >/dev/null || return 1
									# xclients added on version 4.3-b1
									# below statement prevents merging
									# from old database scheme
									# which contains invalidated data.
									[ "$(grep -Fcm1 "\"xclients\"" "${1}")" -ge 1 ] || return 1
									index[0]=$(jq '.ws.bssid[].clients | length' "${1}" | jq -s add)
									index[1]=$(jq '.ws.bssid | length' "${1}" | jq -s add)
									index[2]=$(jq '.ws.psk | length' "${1}" | jq -s add)
									index[3]=$(jq '.ws.gid | length' "${1}" | jq -s add)
								}


_db_clear(){
	unset output; i=0

	local x y z tmp del d n e

	tmp=$(mktemp); output=$(mktemp); cp "${db}" "${output}"

	#echo "clearing database from previous clients..."
	echo "clearing database from invalidated data..."
	jq 'del(.ws.bssid.[].["tclients","admins"]) | jq del(.ws.["gid","psk"])' "${output}" >"${tmp}" && \
		mv "${tmp}" "${output}"
	return 0

	echo "clearing database from incorrect entries..."
	x=($(jq -r '.ws.bssid | keys_unsorted' "${output}" | tr -d '"' | sed 's/\,//g; /\[/d; /\]/d' | tr "\n" " "))
	y=($(jq '.ws.bssid.[].clients | length' "${output}" | tr "\n" " "))
	z=($(jq '.ws.bssid.[].route' "${output}" | tr -d '"' | tr "\n" " "))

		c=0; d=0; unset entry
		_cmd_del_key(){ [ "${entry: -1}" = "," ] && entry="${entry:0: -1}"; [ "${entry:0:1}" = "," ] && entry="${entry:1}"; jq 'del(.ws.bssid.['${entry}'])' "${output}" >"${tmp}" && mv "${tmp}" "${output}" && return 0 || return 1; }
	for n in ${y[@]} EOF; do
		if [ "${n}" = "EOF" ]; then
			true
		elif [ ${n} -ge 1000 ]; then
			echo "deleting entry with 1k items: ${x[${e}]}"
			entry+=",\"${x[${e}]}\""; d=$((d+1))
		elif [ ${n} -ge 500 ]; then
			echo "deleting entry with 500 items: ${x[${e}]}"
			entry+=",\"${x[${e}]}\""; d=$((d+1))
		elif [ ${n} -ge 20 ] && [[ ${z[${e}]} =~ (/24) ]]; then
			#echo "deleting entry with 20 items: ${x[${e}]}"
			entry+=",\"${x[${e}]}\""; d=$((d+1))
		elif [ ${n} -eq 0 ]; then
			#echo "deleting entry with 0 items: ${x[${e}]}"
			entry+=",\"${x[${e}]}\""; d=$((d+1))
		fi
			e=$((e+1))
		if [ ${d} -ge 1000 ] || ([ "${n}" = "EOF" ] && [ ${d} -ne 0 ]); then
			_cmd_del_key && echo "succedd" || echo "failed"
			i=$((i+1)); d=0; unset entry
		fi
	done
}


_db_merge(){
	unset output; i=0

	local tmp pd pf z f

	tmp=$(mktemp); output=$(mktemp); cp "${db}" "${output}"

	i=0; z=$(getprop persist.sys.timezone | tr "[:upper:]" "[:lower:]" | tr -d /); [ -n "${z}" ] || z="unknown"
	unset pd pf

	if [ "${mode}" = "restore" ]; then
		pd[0]="/sdcard/Android/media/com.wifi.spotter/"
		pd[1]="/data/data/com.termux/files/home/com.wifi.spotter/"
		if [ -s "/sdcard/Android/media/com.network.spotter/nspotterdb.json" ]; then
		echo -n>"${home_dir}/logs/nspotter_restored.log"
		pd[2]="/sdcard/Android/media/com.network.spotter/"
		sed -i 's|"ns":|"ws":|' "/sdcard/Android/media/com.network.spotter/nspotterdb.json" && \
		mv "/sdcard/Android/media/com.network.spotter/nspotterdb.json" "/sdcard/Android/media/com.network.spotter/wsdb.json" \
		|| echo -n>"${home_dir}/logs/nspotter_failed.log"
		fi
		pf="wsdb*"
	elif [ "${mode}" = "merge" ]; then
		pd[0]="${home_dir}/uploads/${z}/"
		pd[1]="/sdcard/"
		pf="wsdb*"
	fi

	for f in $(find "${pd[@]}" -name "${pf}" 2>/dev/null); do
		i=$((i+1))
		_validate_db "${f}" || { echo "Warning: skipping: ${f}"; continue; }
		echo "merging: ${f}" && \
			jq -f "${home_dir}/plugins/database-merger.jq" "${output}" "${f}" >"${tmp}" && \
			mv "${tmp}" "${output}" || { echo "Error: unexpected error while merging: ${f}"; continue; }
			[ "${mode}" = "restore" ] && rm -f "${f}"
	done

}

		home_dir=~/wifi-spotter-root
		db="${home_dir}/wsdb_43.json"
	if [ "${1}" = "--merge" ]; then
		mode="merge"
	elif [ "${1}" = "--restore" ]; then
		mode="restore"
	elif [ "${1}" = "--clear" ]; then
		mode="clear"
	else
		cat <<EOF
usage: database-merger [options]
 --merge, Merge remote database into your records.
 --restore, Restore your previous losted database files.
 --clear, Clear your local database from incorrect entries.
EOF
		exit 1
	fi

	if [ ! -s "${home_dir}/plugins/database-merger.jq" ]; then
		echo "Error: can not find merger plugin: ${home_dir}/plugins/database-merger.jq"
		exit 1
	fi

	if [ ! -s "${db}" ] && [ "${mode}" = "merge" ]; then
		echo "Error: can not merge db is empty: ${db}"
		exit 1
	elif [ ! -s "${db}" ] && [ "${mode}" = "clear" ]; then
		echo "Error: can not clean db is empty: ${db}"
		exit 1
	elif [ ! -s "${db}" ] && [ "${mode}" = "restore" ]; then
		echo "Warning: creating new db: ${db}"
		echo '{"ws":{"bssid":{},"gid":{}}}' | jq . >"${db}" \
			|| { echo "Error: unexpected error while creating db !"; exit 1; }
	fi

		echo "getting current entries..."
	if _validate_db "${db}"; then
		echo "Current entries: [Clients](${index[0]}) [BSSID](${index[1]}) [PSK](${index[2]}) [GID](${index[3]})"
	else
		echo "Error: can not continue db looks currupted !"
		exit 1
	fi


	if [ "${mode}" = "restore" ]; then
		_db_merge
	elif [ "${mode}" = "merge" ]; then
		_db_merge
	elif [ "${mode}" = "clear" ]; then
		_db_clear
	fi

	if [ ${i} -eq 0 ]; then
		echo "Nothing was ${mode} !"
		exit 0
	elif _validate_db "${output}"; then
		echo "Updated entries: [Clients](${index[0]}) [BSSID](${index[1]}) [PSK](${index[2]}) [GID](${index[3]})"
		mv "${output}" "${db}"
		echo "${mode} completed !"
	fi
			
