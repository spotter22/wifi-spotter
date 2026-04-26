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

}



	if [ "${1}" = "--release" ]; then
		_release
	elif [ "${1}" = "--commit" ]; then
		_commit
	else
		cat <<EOF
usage: poster.sh [options]
 --commit, Commit release
 --release, Make Release
EOF
	fi
