#!/bin/bash

					_validate_db()
								{
									index=(0 0 0 0)
									jq -e 'has("ws")' "${1}" >/dev/null || return 1
									index[0]=$(jq '.ws.bssid[].clients | length' "${1}" | jq -s add)
									index[1]=$(jq '.ws.bssid | length' "${1}" | jq -s add)
									index[2]=$(jq '.ws.psk | length' "${1}" | jq -s add)
									index[3]=$(jq '.ws.gid | length' "${1}" | jq -s add)
								}

		home_dir=~/wifi-spotter-root
		db="${home_dir}/wsdb.json"
	if [ "${1}" = "--merge" ]; then
		mode="merge"
	elif [ "${1}" = "--restore" ]; then
		mode="restore"
	else
		cat <<EOF
usage: database-merger [options]
 --merge, Merge remote database into your records.
 --restore, Restore your previous losted database files.
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
	elif [ ! -s "${db}" ] && [ "${mode}" = "restore" ]; then
		echo "Warning: creating new db: ${db}"
		echo '{"ws":{"bssid":{},"gid":{}}}' | jq . >"${db}" \
			|| { echo "Error: unexpected error while creating db !"; exit 1; }
	fi

		echo "getting current entries ..."
	if _validate_db "${db}"; then
		echo "Current entries: [Clients](${index[0]}) [BSSID](${index[1]}) [PSK](${index[2]}) [GID](${index[3]})"
	else
		echo "Error: can not continue db looks currupted !"
		exit 1
	fi

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
		pd="${home_dir}/uploads/${z}/"
		pf="wsdb.json"
	fi
	for f in $(find "${pd[@]}" -name "${pf}" 2>/dev/null); do
		i=$((i+1))
		_validate_db "${f}" || { echo "Warning: skipping: ${f}"; continue; }
		echo "merging: ${f}" && \
			jq -f "${home_dir}/plugins/database-merger.jq" "${output}" "${f}" >"${tmp}" && \
			mv "${tmp}" "${output}" || { echo "Error: unexpected error while merging: ${f}"; continue; }
			[ "${mode}" = "restore" ] && rm -f "${f}"
	done

	if [ ${i} -eq 0 ]; then
		echo "Nothing was merged !"
		exit 0
	elif _validate_db "${output}"; then
		echo "Updated entries: [Clients](${index[0]}) [BSSID](${index[1]}) [PSK](${index[2]}) [GID](${index[3]})"
		mv "${output}" "${db}"
		echo "Merging completed !"
	fi
			
