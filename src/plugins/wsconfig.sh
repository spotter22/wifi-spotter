#!/bin/bash




						_process_tests()
										{
												local home profile ws_disconnect_alt ws_macchanger_alt ws_env ws_captiveportal_alt
												home="/data/data/com.termux/files/home/"
												profile="/data/data/com.termux/files/home/.profile"
												ws_env="${home_dir}/logs/_init_env.log"
												touch "${profile}"
											if [ "${1}" = "--install-plugins" ]; then
												_process_plugins
												return 0
											elif [ $(id -u) -ne 0 ]; then
												echo "error configuring requires root access !"
												return 1
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

												_connection_interface_setaddr "11:11:11:11:11:11" "${ws_macchanger_alt}" && ws_interface_allows="odd" || \
													{ ws_interface_allows="even"; }

												sed -i '/ws_interface_allows/d' "${profile}"
												echo "export ws_interface_allows=\"${ws_interface_allows}\"" >>"${profile}"

												sed -i '/_init_env\.log/d' "${profile}"
												echo "echo -n>\"${ws_env}\"" >>"${profile}"

												chmod 600 "${profile}"
												chown --reference="${home}" "${profile}"
												source "${profile}"

												echo >"${ws_env}"
												chmod 644 "${ws_env}"
												chown --reference="${home}" "${ws_env}"

												echo "ws_disconnect_alt result: ${ws_disconnect_alt}"
												echo "ws_macchanger_alt result: ${ws_macchanger_alt}"
												return 0
										}
						_process_plugins()
										{
											if [ "${ws_plugin_hostname_spoofer}" != "no" ]; then
												echo "installing hostname-spoofer..."
												su -c 'rm -f "/data/adb/post-fs-data.d/identfiers-spoofer.sh" "/data/adb/post-fs-data.d/useragent-spoofer.sh" "/data/adb/post-fs-data.d/hostname-spoofer.sh" 2>/dev/null; cp "'${home_dir}'/plugins/hostname-spoofer.sh" "/data/adb/service.d/" && chmod 755 "/data/adb/service.d/hostname-spoofer.sh" && /data/adb/service.d/hostname-spoofer.sh'
												echo "installing macsposed-persist..."
											fi

											if [ "${ws_plugin_macsposed_persist}" != "no" ]; then
												su -c 'cp "'${home_dir}'/plugins/macsposed-persist.sh" "/data/adb/service.d/" && chmod 755 "/data/adb/service.d/macsposed-persist.sh"'
												echo >"${home_dir}/logs/_init_macsposed_persist.log"
												echo "export ws_init_macsposed_persist=\"incomplete\"" >>"${profile}"
											fi

												sed -i '/ws_captiveportal_alt/d' "${profile}"
											if [ "${ws_plugin_captive_portal_clear}" != "no" ]; then
												ws_captiveportal_alt=$(echo "pm list packages" | su - | grep -F "captiveportallogin" | sed "s/package://g" | tr "\n" " ")
												echo "export ws_captiveportal_alt=${ws_captiveportal_alt}" >>"${profile}"
											fi

											return 0
										}

	unset home_dir
	home_dir=/data/data/com.termux/files/home/wifi-spotter-root
	_process_tests "${@}"

