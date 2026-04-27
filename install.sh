#!/bin/bash



						_process_clean()
										{
											echo "cleanning previous releases..."
											rm -f "${PREFIX}/bin/ws-uploader" "${PREFIX}/bin/ws-updater" "${PREFIX}/bin/sss" "${PREFIX}/bin/netspotter" "${PREFIX}/bin/ns-uploader" "${PREFIX}/bin/ws-merge" ~/.wsu.pid ~/.wsupdate.pid ~/.ns.pid ~/.wsg.pid ~/.wsr.pid ~/ns.tar.gz &>/dev/null
											rm -rf ~/.ws ~/.ws.pid ~/.wsc.pid ~/.wsm.pid "${PREFIX}/etc/m.jq" "${PREFIX}/bin/wifi-spotter-config" "${PREFIX}/bin/wifi-spotter-updater" &>/dev/null
											rm -f "${home_dir}/logs/.wsc.pid" "${home_dir}/logs/.wsm.pid" "${home_dir}/logs/updater.pid"
											rm -f "${home_dir}/logs/"*.log
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
										}
						_process_deps()
										{
												local p deps result list
											if [ -n "${TERMUX_VERSION}" ]; then
													deps[0]="clang automake autoconf"
													deps[1]="libnet libpcap"
													deps[2]="git sudo play-audio jq wget curl"
													deps[3]="iproute2 iptables iw arp-scan tcpdump tshark socat macchanger net-tools"
													echo "checking required packages..."
												for p in ${deps[@]}; do
														result=$(apt list --installed "${p}" 2>&1)
													if [[ ! "${result}" =~ "installed" ]]; then
														list+=" ${p}"
													fi
												done
												if [ -n "${list}" ]; then
														echo "Getting packages updates..."
														apt update || exit 1
													if ! command -v clang >/dev/null; then
														apt upgrade -y || exit 1
													fi

													echo "Installing required packages..."
													apt install -y "root-repo" || exit 1
													apt install -y ${list} || exit 1
												fi
											else
												echo "Error: unknown platform"
												return 1
											fi
										}
						_process_compile()
										{
											if ! command -v arping >/dev/null; then
													echo "Compiling arping..."
													rm -rf "${home_dir}/logs/arping"
													git clone "https://github.com/ThomasHabets/arping" "${home_dir}/logs/arping" || return 1
													cd "${home_dir}/logs/arping"
													./bootstrap.sh >/dev/null
													./configure --prefix="${PREFIX}" >/dev/null
													make >/dev/null
												if command -v "./src/arping"; then
													cp "./src/arping" "${PREFIX}/bin/"
												else
													echo "Error: compiling arping failed !"
													return 1
												fi
											fi
											if ! command -v arp-poison >/dev/null; then
													echo "Compiling arp-poison..."
													rm -rf "${home_dir}/logs/arp-poison"
													git clone "https://github.com/mast3rz3ro/arp-poison" "${home_dir}/logs/arp-poison" || return 1
													cd "${home_dir}/logs/arp-poison"
													make >/dev/null
												if command -v "./arp-poison"; then
													make install INSTALL_PREFIX="${PREFIX}" >/dev/null
												else
													echo "Error: compiling arp-poison failed !"
													return 1
												fi
											fi
										}
						_process_install()
										{
											_process_clean

											cd "${current_dir}"
											echo "copying wifi-spotter files..."
											cp -R "./src/plugins/" "./src/sfx/" "./src/wifi-spotter.sh" "./LICENSE" "./HISTORY" "${home_dir}/" || return 1
											cp "./install.sh" "${home_dir}/plugins/updater.sh"

											echo "setting wifi-spotter scripts..."
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

											echo "merging previous database..."
											"${home_dir}/plugins/database-merger.sh" --restore

											echo "making link to wifi-spotter.sh..."
											ln -fs "${home_dir}/wifi-spotter.sh" "${PREFIX}/bin/ws"

											echo "Installation completed !"
										}
						_process_ufetch()
										{
													local link latest
													link="https://raw.githubusercontent.com/spotter22/wifi-spotter/refs/heads/main/LATEST"
													echo "getting latest version info..."
											while true; do
													latest=$(curl -sL "${link}" 2>/dev/null)
												if [ -z "${latest}" ]; then
													echo "Error: could not obtain version info"
													[ "${1}" = "--silent" ] && { sleep 3; continue; } || { return 1; }
												elif [ "${latest}" = "${version}" ]; then
													echo "Warning: current version matches latest version..."
													[ "${1}" = "--silent" ] && { return 1; } || { break; }
												else
													version="${latest}"
													break
												fi
											done

												if [ -s "${home_dir}/updates/update.tar.gz" ]; then
													echo "testing tarball..."
													tar -tf "${home_dir}/updates/update.tar.gz" &>/dev/null && return 0 \
														|| rm -f "${home_dir}/updates/update.tar.gz"
												fi

													echo "downloading latest wifi-spotter package..."
													mkdir -p "${home_dir}/updates/tmp"
													link="https://github.com/spotter22/wifi-spotter/releases/download"
													latest="wifi-spotter-${version}.tar.gz"
													while true; do
														curl -sL "${link}/${version}/${latest}" -o "${home_dir}/updates/${latest}" || continue
														tar -tf "${home_dir}/updates/${latest}" >/dev/null && \
															cp "${home_dir}/updates/${latest}" "${home_dir}/updates/update.tar.gz" && break \
															|| { echo -e "Error: downloading failed !\ntrying to download again..."; rm -f "${home_dir}/updates/${latest}"; }
													done
										}
						_process_uinstall()
										{
											if [ "${1}" = "--silent" ] && [ "${ws_update}" = "yes" ]; then
												true
											elif [ "${1}" = "--install" ]; then
												true
											else
												return 1
											fi
												echo "extracting wifi-spotter package..."
												tar --overwrite -xf "${home_dir}/updates/update.tar.gz" -C "${home_dir}/updates/tmp/" &>/dev/null && \
													rm -f "${home_dir}/updates/update.tar.gz"
												current_dir="${home_dir}/updates/tmp/"
												cd "${current_dir}"
												./install.sh --install
										}


		unset home_dir current_dir
		version="unknown"
		commit="unknown"
	if [[ "${@}" = *"--uninstall"* ]]; then
			read -p "To continue uninstalling enter (Yes/y):" option
		if [[ "${option}" =~ (Y/y) ]]; then
			_process_storage || exit 1
			rm -rf "${home_dir}"
			echo "uninstalling completed !"
		fi
	elif [[ "${@}" = *"--silent-update"* ]]; then
			_process_storage || exit 1
		if [ ! -d "${home_dir}/updates" ]; then
			echo "Please use instead: --install-latest"
			exit 1
		else
			_process_ufetch "--silent" || exit 1
			_process_uinstall "--silent" || exit 1
		fi
	elif [[ "${@}" = *"--install-latest"* ]]; then
			_process_storage || exit 1
			_process_ufetch "--install" || exit 1
			_process_uinstall "--install" || exit 1
	elif [[ "${@}" = *"--install"* ]]; then
		_process_storage || exit 1
		current_dir=$(pwd)
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
