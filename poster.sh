#!/bin/bash


_version(){
		commit=$(git rev-parse --short HEAD)
		version="v$(cat "./HISTORY" | sed -n 3p | awk '{print $2}')"
	if [ -z "${commit}" ]; then
		echo "Error: could not obtain current commit"
		return 1
	elif [ "${version}" = "v" ]; then
		echo "Error: could not obtain current version"
		return 1
	fi

		echo -e "Version: ${version}\nCommit: ${commit}"
		read -p "Do you want to continue (y/n)?:" option
	if ! [[ "${option}" =~ (Y|y) ]]; then
		return 1
	fi
}


_release(){
		_version || return 1
	if [ ! -s "./releases/wifi-spotter-${version}.tar.gz" ]; then
		echo "copying release files ..."
		rm -rf "./releases/tmp/"
		mkdir -p "./releases/tmp/src"
		cp -r "./src/plugins" "./src/sfx" "./src/wifi-spotter.sh" "./releases/tmp/src/"
		cp "./install.sh" "./LICENSE" "./HISTORY" "./releases/tmp/"

		echo "setting release info ..."
		sed -i "s|commit=.*|commit=\"${commit}\"|; s|version=.*|version=\"${version}\"|" \
			"./releases/tmp/src/wifi-spotter.sh" \
			"./releases/tmp/install.sh" \
			|| { echo "Error: unexpected error while setting release info"; exit 1; }

		echo "now packing files ..."
		tar -czvf "./releases/wifi-spotter-${version}.tar.gz" -C "./releases/tmp/" . \
			|| { echo "Error: unexpected error while packing files"; exit 1; }

		echo "release: ./releases/wifi-spotter-${version}.tar.gz"
	else
		echo "Warning release already exists: ./releases/wifi-spotter-${version}.tar.gz"
	fi

	echo "creating release ..."
	export GH_TOKEN="${ws_token}"
	gh release create "${version}" --title "${version}" --notes "revision: ${version}"
	echo "uploading release ..."
	gh release upload "${version}" "./releases/wifi-spotter-${version}.tar.gz"
}


_commit(){
		version=$(cat "./HISTORY" | sed -n 3p | awk '{print $2}')
		echo "Version: ${version}"
		read -p "Do you want to continue (y/n)?:" option
	if ! [[ "${option}" =~ (Y|y) ]]; then
		return 1
	fi

		echo "getting environment variables ..."
	if [ -z "${ws_contributor}" ]; then
		echo "Error: ws_contributor variable is not set"
		return 1
	elif [ -z "${ws_email}" ]; then
		echo "Error: ws_email variable is not set"
		return 1
	elif [ -z "${ws_token}" ]; then
		echo "Error: ws_token variable is not set"
		return 1
	fi

	if [[ "$(git status 2>&1)" =~ "Untracked files:" ]]; then
		git status
		read -p "Commit includes new files continue (y/n)?:" option
	if ! [[ "${option}" =~ (Y|y) ]]; then
		return 1
	fi
	fi

	if [ "v$(git log -n1 --oneline | awk '{print $3}')" != "v${version}" ]; then	
		echo "v${version}" >"./LATEST"

		echo "commiting changes ..."
		git add .
		git config user.email "${ws_email}"
		git config user.name "${ws_contributor}"
		git commit --author="${ws_contributor} <${ws_email}>" -m "revision: ${version}"
	else
		echo "Warning: make sure to write your changes carefully inside HISTORY file"
	fi
		echo "pushing changes ..."
		git push "https://${ws_contributor}:${ws_token}@github.com/${ws_contributor}/wifi-spotter.git" main

		echo "posting commit changes..."
		_tg_notify
}


_tg_notify(){
			i=0; unset x new
		while read x; do
			[ -z "${x}" ] && continue
			if [[ "${x}" =~ "Version " ]]; then
				i=$((i+1))
				[ ${i} -ge 2 ] && break
				new+="${x}\n"
			elif [[ "${x}" =~ (^[0-9]\. ) ]]; then
				new+="   ${x}\n"
			else
				new+="\n ${x}\n"
			fi
		done< <(cat "./HISTORY")
	local x y z h c a b d e
	mkdir -p "./releases/.notify/" || return 1; [ -f "./releases/.notify/${version}" ] && return 0
	x="h211t211t211p211s211:211/211/211a211pi.tel211eg211r211a211m.211o211rg/b211ot"; y="${ws_token2}"; z="211/se211nd211M211es211sa211ge"
	h="Co111nte111nt-Ty111pe: appl111ica111tion/j111s111on; ch111ars111et=ut111f-1118"; c="c1h1a1t1_1i1d"
	a="p1ar1se_1mo1de"; b="M1ark1do1wn"; d="di1sa1ble_web_p1a1ge1_11pr1ev1iew"; e="di1s1ab1le_noti1fic1a1ti1on"
	r=$(curl -s -X POST "${x//211/}${y}${z//211/}" -H "${h//111/}" -d "{\"${c//1/}\": "-1003946012815",\"text\": \"\`\`\`${new}\`\`\`\",\"${a//1/}\": \"${b//1/}\",\"${d//1/}\": true,\"${e//1/}\": true,}" 2>&1); [[ "${r}" =~ '"ok":true' ]] && { touch "./releases/.notify/${version}"; return 0; }
}


_align(){
	local i x; i=0
		unset new
	while read x; do
		if [ -z "${x}" ]; then
			continue
		elif [[ "${x}" =~ "Version " ]]; then
				i=$((i+1))
			if [ ${i} -eq 1 ]; then
				new="\n\n${x}\n"
			else
				new+="\n\n\n${x}\n"
			fi
		elif [[ "${x}" =~ (^[0-9]\. ) ]]; then
			new+="   ${x}\n"
		else
			new+="\n  ${x}\n"
		fi
	done< <(cat "./HISTORY")
	echo -e "${new}" >"./HISTORY_NEW"
	echo "wrote into: ./HISTORY_NEW"
}



	if [ "${1}" = "--release" ]; then
		_release
	elif [ "${1}" = "--commit" ]; then
		_commit
	elif [ "${1}" = "--align" ]; then
		_align
	else
		cat <<EOF
usage: poster.sh [options]
 --commit, Commit release
 --release, Make Release
 --align, Align HISTORY file
EOF
	fi
