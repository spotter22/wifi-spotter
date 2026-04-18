#!/bin/bash



						_process_clean()
										{
											echo "cleanning previous releases ..."
											rm -f "${PREFIX}/bin/ws-uploader" "${PREFIX}/bin/ws-updater" "${PREFIX}/bin/sss" "${PREFIX}/bin/netspotter" "${PREFIX}/bin/ns-uploader" "${PREFIX}/bin/ws-merge" ~/.wsu.pid ~/.wsupdate.pid ~/.ns.pid ~/.wsg.pid ~/.wsr.pid ~/ns.tar.gz &>/dev/null
											rm -rf ~/.ws ~/.ws.pid ~/.wsc.pid ~/.wsm.pid "${PREFIX}/etc/m.jq" &>/dev/null
										}
						_process_storage()
										{
												# startting from v3.3
											if [ -z "${ws_dir}" ]; then
												home_dir=~/wifi-spotter-root
											else
												home_dir="${ws_dir}"
											fi
												mkdir -p "${home_dir}/logs"
											if [ ! -w "${home_dir}" ]; then
												echo "Error: can not write into: ${home_dir}"
												return 1
											fi

												echo -n>"${home_dir}/logs/test_write"
												chmod +x "${home_dir}/logs/test_write"
											if [ ! -x "${home_dir}/logs/test_write" ]; then
												echo "Error: can not execute files within: ${home_dir}"
												exit 1
											fi
												echo "Root-Directory: ${home_dir}"

												_process_clean
										}
						_process_deps()
										{
												local p deps result list
											if [ -n "${TERMUX_VERSION}" ]; then
													deps[0]="clang automake autoconf"
													deps[1]="libnet libpcap root-repo"
													deps[2]="git sudo play-audio jq wget curl"
													deps[3]="iproute2 iptables iw arp-scan tcpdump tshark socat macchanger net-tools"
													echo "checking required packages ..."
												for p in ${deps[@]}; do
														result=$(apt list --installed "${p}" 2>&1)
													if [[ ! "${result}" =~ "installed" ]]; then
														list+=" ${p}"
													fi
												done
												if [ -n "${list}" ]; then
													echo "Getting packages updates..."
													apt update >/dev/null || exit 1

													echo "Installing required packages ..."
													apt install -y ${list} >/dev/null || exit 1
												fi

											else
												echo "Error: unknown platform"
												return 1
											fi
										}
						_process_compile()
										{
											if ! command -v arping >/dev/null; then
													echo "Compiling arping ..."
													git clone "https://github.com/ThomasHabets/arping" "${home_dir}/logs/"
													cd "${home_dir}/logs/arping"
													./bootstrap.sh >/dev/null
													./configure --prefix="${PREFIX}" >/dev/null
													make >/dev/null
												if command -v "./src/arping"; then
													make install >/dev/null
												else
													echo "compiling arping failed !"
													return 1
												fi
											fi
											if ! command -v arp-poison >/dev/null; then
													echo "Compiling arp-poison ..."
													git clone "https://github.com/mast3rz3ro/arp-poison" "${home_dir}/logs/"
													cd "${home_dir}/logs/arp-poison"
													make >/dev/null
												if command -v "./arp-poison"; then
													make install INSTALL_PREFIX="${PREFIX}" >/dev/null
												else
													echo "compiling arp-poison failed !"
													return 1
												fi
											fi
										}
						_process_install()
										{
											cd "${current_dir}"
											echo "copying wifi-spotter files ..."
											cp -R "./src/plugins/" "./src/sfx/" "./src/wifi-spotter.sh" "./LICENSE" "./HISTORY" "${home_dir}/" || return 1
											cp "${current_dir}/install.sh" "${home_dir}/plugins/updater.sh"

											echo "setting wifi-spotter scripts ..."
											sed -i "s|home_dir=\"[^\"]*.|home_dir=\"${home_dir}\"|" \
												"${home_dir}/wifi-spotter.sh" \
												"${home_dir}/plugins/configs.sh" \
												"${home_dir}/plugins/updater.sh" \
												"${home_dir}/plugins/reporter.sh" \
												"${home_dir}/plugins/database-merger.sh" || exit 1

											chmod +x \
												"${home_dir}/wifi-spotter.sh" \
												"${home_dir}/plugins/configs.sh" \
												"${home_dir}/plugins/updater.sh" \
												"${home_dir}/plugins/reporter.sh" \
												"${home_dir}/plugins/database-merger.sh" || exit 1

											echo "making link to wifi-spotter.sh ..."
											ln -fs "${home_dir}/wifi-spotter.sh" "${PREFIX}/bin/ws"

											echo "Installation completed !"
										}

		unset home_dir current_dir
		version="unknown"
		commit="unknown"
		current_dir=$(pwd)
	if [[ "${@}" = *"--uninstall"* ]]; then
			read -p "To continue uninstalling enter (Yes/y):" option
		if [[ "${option}" =~ (Y/y) ]]; then
			_process_storage || exit 1
			rm -rf "${home_dir}"
			echo "uninstalling completed !"
		fi
	elif [[ "${@}" = *"--silent-update"* ]]; then
		if [ ! -d "${home_dir}" ]; then
			echo "Please use instead: --install-latest"
			exit 1
		fi
		if [ ! -s "${home_dir}/updates/update.tar.gz" ]; then
				ws_link="https://raw.githubusercontent.com/spotter22/wifi-spotter/refs/heads/main/LATEST"
			while true; do
					latest=$(curl -sL "${ws_link}" 2>/dev/null)
				if [ -z "${latest}" ]; then
					sleep 10; continue
				elif [ "${latest}" = "${version}" ]; then
					exit 0
				else
					version="${latest}"
					break
				fi
			done

				mkdir -p "${home_dir}/updates/tmp"
				ws_link="https://github.com/spotter22/wifi-spotter/releases/download"
				ws_latest="wifi-spotter-${version}.tar.gz"
			while true; do
				curl -sL "${ws_link}/${version}/${ws_latest}" -o "${home_dir}/updates/${ws_latest}" &>/dev/null && cp "${home_dir}/updates/${ws_latest}" "${home_dir}/updates/update.tar.gz" && break || continue
			done
		fi
		if [ "${ws_update}" = "yes" ]; then
			tar --overwrite -xf "${home_dir}/updates/update.tar.gz" -C "${home_dir}/updates/tmp/" &>/dev/null && \
				rm -f "${home_dir}/updates/update.tar.gz"
			cd "${home_dir}/updates/tmp/"
			_process_deps || exit 1
			_process_compile || exit 1
			_process_install
		fi
	elif [[ "${@}" = *"--install-latest"* ]]; then
		_process_storage || exit 1
		mkdir -p "${home_dir}/updates/tmp"
		ws_link="https://github.com/spotter22/wifi-spotter/releases/download"
		ws_latest="wifi-spotter-${version}.tar.gz"
		echo "Downloading latest wifi-spotter package ..."
		curl -L "${ws_link}/${version}/${ws_latest}" -o "${home_dir}/updates/${ws_latest}" || exit 1

		echo "Extracting wifi-spotter package ..."
		tar --overwrite -xvf "${home_dir}/updates/${ws_latest}" -C "${home_dir}/updates/tmp/" >/dev/null || exit 1
		cd "${home_dir}/updates/tmp"
		_process_deps || exit 1
		_process_compile || exit 1
		_process_install
	elif [[ "${@}" = *"--install"* ]]; then
		_process_storage || exit 1
		_process_deps || exit 1
		_process_compile || exit 1
		_process_install
	else
		cat <<EOF
usage: ./install.sh [options]
wifi-spotter package manager

Option:       Description:
 --silent-update, Update silently
 --install-latest, Install latest version
 --install, Install current version
 --uninstall, Remove completely
EOF
	fi
