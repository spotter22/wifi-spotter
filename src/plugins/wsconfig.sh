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
												source "${home_dir/\.suroot/}/plugins/connection-status.sh" || return 1

												_connection_interface_disconnect "0" && ws_disconnect_alt=0 || \
													{ _connection_interface_disconnect "1" && ws_disconnect_alt=1 || ws_disconnect_alt=2; }
												
												sed -i '/ws_disconnect_alt/d' "${profile}"
												echo "export ws_disconnect_alt=${ws_disconnect_alt}" >>"${profile}"

												_connection_interface_setaddr "--random" "0" && ws_macchanger_alt=0 || \
													{ _connection_interface_setaddr "--random" "1" && ws_macchanger_alt=1 || return 1; }

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
											echo "installing hostname-spoofer..."
											su -c 'rm -f "/data/adb/post-fs-data.d/identfiers-spoofer.sh" "/data/adb/post-fs-data.d/useragent-spoofer.sh" 2>/dev/null; cp "'${home_dir}'/plugins/hostname-spoofer.sh" "/data/adb/post-fs-data.d/" && chmod 755 "/data/adb/post-fs-data.d/hostname-spoofer.sh" && /data/adb/post-fs-data.d/hostname-spoofer.sh'
										}

	unset home_dir
	home_dir=/data/data/com.termux/files/home/wifi-spotter-root

	if [ "${1}" = "--install-plugins" ]; then
		_process_plugins
	else
		_process_tests || exit 1
	fi
