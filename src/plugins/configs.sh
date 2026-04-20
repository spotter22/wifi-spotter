#!/bin/bash




						_process_tests()
										{
												local home profile ws_disconnect_alt ws_macchanger_alt
												home="/data/data/com.termux/files/home/"
												profile="/data/data/com.termux/files/home/.profile"
												touch "${profile}"
											if [ $(id -u) -ne 0 ]; then
												echo "error configuring requires root access !"
												exit 1
											fi
											if [ -z "$(iw dev wlan0 disconnect 2>&1)" ]; then
												ws_disconnect_alt=0
											elif [ -z "$(ifconfig wlan0 down; iw dev wlan0 disconnect 2>&1; ifconfig wlan0 up)" ]; then
												ws_disconnect_alt=1
											else
												ws_disconnect_alt=2
											fi
												sed -i '/ws_disconnect_alt/d' "${profile}"
												echo "export ws_disconnect_alt=${ws_disconnect_alt}" >>"${profile}"

											if [[ ! "$(macchanger -r wlan0 2>&1)" =~ (ERROR) ]]; then
												ws_macchanger_alt=0
											elif [[ ! "$(ifconfig wlan0 down; macchanger -r wlan0 2>&1; ifconfig wlan0 up)" =~ (ERROR) ]]; then
												ws_macchanger_alt=1
											else
												echo "Unexpected error:"
												macchanger -r wlan0
												exit 1
											fi
												sed -i '/ws_macchanger_alt/d' "${profile}"
												echo "export ws_macchanger_alt=${ws_macchanger_alt}" >>"${profile}"

												source "${profile}"
												chmod 600 "${profile}"
												chown --reference="${home}" "${profile}"
												echo "ws_disconnect_alt result: ${ws_disconnect_alt}"
												echo "ws_macchanger_alt result: ${ws_macchanger_alt}"
												return 0
										}
						_process_plugins()
										{
											echo "Installing device's identifiers spoofer..."
											su -c 'cp "'${home_dir}'/plugins/identfiers-spoofer.sh" "/data/adb/post-fs-data.d/" && chmod 755 "/data/adb/post-fs-data.d/identfiers-spoofer.sh"'
										}

unset home_dir
home_dir=~/wifi-spotter-root
_process_tests || exit 1
#_process_plugins
