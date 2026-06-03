#!/bin/bash



_wsconfig_test_disconnect(){
	unset ws_disconnect_alt

	echo "testing disconnect-method..."

		# testing `disconnect` requires device to be connected into wifi
	if [ -z "$(ip n)" ]; then
		echo "warning: no wifi connection is found !"
		ws_disconnect_alt=2
		return 1
	fi

	iw dev wlan0 disconnect && \
		{ ws_disconnect_alt=0; return 0; }

	if [ ${ws_macchanger_alt} -eq 1 ]; then
		ws_disconnect_alt=2
		return 0
	else
		ws_disconnect_alt=1
		return 0
	fi

}


_wsconfig_test_macsposed(){
	unset ws_macchanger_alt ws_interface_allows

	echo "testing macsposed..."

	cmd wifi set-wifi-enabled enabled; sleep 1

	macchanger -r wlan0 &>/dev/null && ws_macchanger_alt=0 || ws_macchanger_alt=1

	[ ${ws_macchanger_alt} -eq 1 ] && ip link set dev wlan0 down
	macchanger -m "11:11:11:11:11:11" wlan0 &>/dev/null && ws_interface_allows="odd" || ws_interface_allows="even"
	[ ${ws_macchanger_alt} -eq 1 ] && ip link set dev wlan0 up

}


_wsconfig_init_profile(){
	local e

	if [ "$(id -u)" != "0" ]; then
		echo "error configuring requires root access !"
		return 1
	fi

	# create profile if not exist
	touch "${profile}"

	_wsconfig_test_disconnect
	sed -i '/ws_disconnect_alt/d' "${profile}"
	echo "export ws_disconnect_alt=${ws_disconnect_alt}" >>"${profile}"

	_wsconfig_test_macsposed
	sed -i '/ws_macchanger_alt/d' "${profile}"
	sed -i '/ws_interface_allows/d' "${profile}"
	echo "export ws_macchanger_alt=${ws_macchanger_alt}" >>"${profile}"
	echo "export ws_interface_allows=\"${ws_interface_allows}\"" >>"${profile}"

	# let wifi-spotter know reloading profile is needed
	e="${home_dir}/logs/_init_env.log"
	echo >"${e}"; chmod 664 "${e}"
	chown --reference="${home}" "${e}"
	sed -i '/_init_env\.log/d' "${profile}"
	echo "echo -n>\"${e}\"" >>"${profile}"

	# fix profile permission
	chmod 600 "${profile}"
	chown --reference="${home}" "${profile}"

	echo "ws_interface_allows result: ${ws_interface_allows}"
	echo "ws_macchanger_alt result: ${ws_macchanger_alt}"
	echo "ws_disconnect_alt result: ${ws_disconnect_alt}"
	
}


_wsconfig_init_plugins(){

	if [ "${ws_plugin_hostname_spoofer}" != "no" ]; then
		echo "installing hostname-spoofer..."
		su -c 'rm -f "/data/adb/post-fs-data.d/identfiers-spoofer.sh" "/data/adb/post-fs-data.d/useragent-spoofer.sh" "/data/adb/post-fs-data.d/hostname-spoofer.sh" 2>/dev/null; cp "'${home_dir}'/plugins/hostname-spoofer.sh" "/data/adb/service.d/" && chmod 755 "/data/adb/service.d/hostname-spoofer.sh"'
	fi

		# error typo from v4.1
		sed -i '/ws_init_macsposed_persist/d' "${profile}"
	if [ "${ws_plugin_macsposed_persist}" != "no" ]; then
		echo "installing macsposed-persist..."
		su -c 'cp "'${home_dir}'/plugins/macsposed-persist.sh" "/data/adb/service.d/" && chmod 755 "/data/adb/service.d/macsposed-persist.sh"'
		echo >"${home_dir}/logs/_init_macsposed_persist.log"
		chmod 664 "${home_dir}/logs/_init_macsposed_persist.log"
		chown --reference="${home}" "${home_dir}/logs/_init_macsposed_persist.log"
	fi

		sed -i '/ws_captiveportal_alt/d' "${profile}"
	if [ "${ws_plugin_captive_portal_clear}" != "no" ]; then
		ws_captiveportal_alt=$(echo "pm list packages" | su - | grep -F "captiveportallogin" | sed "s/package://g" | tr "\n" " ")
		echo "export ws_captiveportal_alt=\"${ws_captiveportal_alt}\"" >>"${profile}"
	fi

}

	home_dir="/data/data/com.termux/files/home/wifi-spotter-root"
	home="/data/data/com.termux/files/home/"
	profile="${home_dir}/.wsprofile"

	# clean v4.2-b6
	if [ -s "${home}/.profile" ]; then
		sed -i '/ws_macchanger_alt/d' "${home}/.profile"
		sed -i '/ws_interface_allows/d' "${home}/.profile"
		sed -i '/ws_disconnect_alt/d' "${home}/.profile"
		sed -i '/ws_captiveportal_alt/d' "${home}/.profile"
		sed -i '/_init_env\.log/d' "${home}/.profile"
	fi

	if [ "${1}" = "--install-plugins" ]; then
		_wsconfig_init_plugins
	else
		_wsconfig_init_profile
	fi

