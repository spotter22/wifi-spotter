#!/bin/bash


_302parser_send_request(){
	local url output useragent
	[ -n "${1}" ] && url="${1}" || url="http://google.com"
	[ -n "${2}" ] && output="${2}" || output="./302parser_request.log"
	[ -n "${3}" ] && useragent="${3}" || useragent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.32 Safari/537.36"

	echo "_302parser_send_request: sending request for: ${url}"
	curl -svLA "${useragent}" "${url}" &>"${output}"
	echo -e "\nEOF" >>"${output}" # fixes when last line has no \n

	local x
	echo "_302parser_send_request: checking received response..."
	while read -r x; do
		if [[ "${x}" =~ "Failed to connect to " ]]; then
			echo "_302parser_send_request: error no connection (err: ${x})"
			return 1
		elif [[ "${x}" =~ "Could not resolve host: " ]]; then
			echo "_302parser_send_request: error dns failed (err: ${x})"
			return 2
		elif [[ "${x}" =~ "timed out after " ]]; then
			echo "_302parser_send_request: error response timed out (err: ${x})"
			return 3
		elif [[ "${x}" =~ "Recv failure: Software caused connection abort" ]]; then
			echo "_302parser_send_request: error connection lost (err: ${x})"
			return 4
		fi
	done< <(cat "${output}")

	return 0
}


_302parser_crawl_request(){
	local url output useragent x
	[ -n "${1}" ] && url="${1}" || url="http://google.com"
	[ -n "${2}" ] && output="${2}" || output="./302parser_request.log"
	[ -n "${3}" ] && useragent="${3}" || useragent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.32 Safari/537.36"

	echo "_302parser_crawl_request: crawling request for: ${url}"
	while read -r x; do
		([ -z "${x}" ] || [[ "${x}" =~ (WARNING: combining|^will be placed) ]]) && continue
		#echo "${x}"
	done< <(wget -nv -rU "${useragent}" "${url}" -R "jpg,png,ico,mp4,svg,gif,css,eot,ttf,woff" -O "${output}" 2>&1)
}


_302parser_parse_login(){
	domain=0; host=0; port=0; ret=0
	local input x arr
	[ -n "${1}" ] && input="${1}" || input="./302parser_request.log"
	echo "_302parser_parse_login: parsing login from: ${input}"
	while read -r x; do
		if [[ "${x}" =~ (md5\.js|doctype html|<html) ]]; then
			echo "_302parser_parse_login: warning breaking at begin of html (ret: ${x})"
			return 0
		elif [ "${#x}" -le 100 ] && [[ "${x}" =~ "window.location.href" ]]; then
			echo "_302parser_parse_login: js-redirect result: [js-redirect](${x})"
			ret="${x/*=\"/}"; ret="${ret/\"*/}"
			return 1
		elif [[ "${x}" =~ '<LoginURL>' ]]; then
			echo "_302parser_parse_login: xml-redirect result: [xml-redirect](${ret})"
			ret=$(echo "${x}" | sed 's|<LoginURL>||; s|</LoginURL>||' | tr -d '\r ')
			return 2
		elif [[ "${x}" =~ "Established connection to " ]]; then
			arr=(${x}); domain="${arr[3]}"; host="${arr[4]/(/}"; port="${arr[6]/)/}"
			echo "_302parser_parse_login: parsing success: [domain](${domain}) [host](${host}) [port](${port})"
			continue
		fi
	done< <(cat "${input}" | tr -d '!*')
	return 0
}



_302parser_parse_scripts(){
	ret=0
	local input index x
	[ -n "${1}" ] && input="${1}" || input="./302parser_request.log"
	[ -n "${2}" ] && index="${2}"

	echo "_302parser_parse_scripts: parsing scripts from: ${input}"
	x=$(cat "${input}" | grep -ao '"[^"]\+"' | grep -F ".js" | tr -d '"' | sort | uniq | tr "\n" " " | tr ' ' ',')

	if [ -n "${x}" ]; then
		echo "_302parser_parse_scripts: parsing success (ret: ${x})."
	else
		ret="${index}"
		echo "_302parser_parse_scripts: warning parsing failed (ret: ${ret})."
		return 1
	fi

		x="${x// /}"
	if [ -n "${index}" ]; then
		ret="{${index},${x:0:-1}}"
	else
		ret="{${x:0:-1}}"
	fi

	echo "_302parser_parse_scripts: sorting finished (ret: ${ret})."
	return 0
}


_302parser_parse_status(){
	status=0
	local input
	[ -n "${1}" ] && input="${1}" || input="./302parser_request.log"

	echo "_302parser_parse_status: parsing status from: ${input}"
	status=$(cat "${input}" | grep -ao '[^"]\+"' | grep -F '/status?' | tr -d '"' | sort | uniq)

	if [ -n "${status}" ]; then
		echo "_302parser_parse_status: parsing success (ret: ${status})."
		return 0
	else
		status="status"
		echo "_302parser_parse_status: warning parsing failed (ret: status)."
		return 1
	fi
}


_302parser_parse_gid(){
	gid=(0 0)
	local input x
	[ -n "${1}" ] && input="${1}" || input="./302parser_request.log"

	echo "_302parser_parse_gid: parsing gid from: ${input}"
	gid[1]=$(cat "${input}" | tr -d ' -)(' | grep -oE '[0-9]{7}|[0-9]{8}|[0-9]{9}' 2>/dev/null | tr '\n' '.')

	if [ -n "${gid[1]}" ]; then
		echo "_302parser_parse_gid: parsing success (ret: ${gid[1]})."
	else
		gid=(0 0)
		echo "_302parser_parse_gid: error generating gid failed (err: null)."
		return 1
	fi

	x=$(echo -n "${gid[1]}" | md5sum); gid[0]="${x/  -/}"
	return 0
}


_302parser_parse_auto(){
	local request output index
	[ -n "${1}" ] && request="${1}" || request="http://google.com"
	[ -n "${2}" ] && output="${2}" || output="./302parser_auto.log"

	_302parser_send_request "${request}" "${output}" || return 1
	_302parser_parse_login "${output}"

	if [ "${domain}" = "www.google.com" ]; then
		return 0
	elif [ ${?} -eq 0 ]; then
		:
	elif [ ${?} -eq 1 ]; then
		domain="${domain}/${ret}"
		_302parser_parse_scripts "${output}" "${ret}"
		_302parser_send_request "${host}:${port}/${ret}" "${output}" || return 1
		#_302parser_crawl_request "${host}:${port}/${ret}" "${output}" || return 1
	elif [ ${?} -eq 2 ]; then
		domain="${ret}"
		_302parser_parse_scripts "${output}" "${ret##*/}"
		_302parser_send_request "${host}:${port}/${ret}" "${output}" || return 1
		#_302parser_crawl_request "${host}:${port}/${ret}" "${output}" || return 1
	else
		echo "_302parser_parse_auto: an error occurred while trying to parse (err: ${?}). "
		return 1
	fi

	_302parser_parse_scripts "${output}"
	_302parser_send_request "${host}:${port}/${ret}" "${output}" || return 1
	_302parser_parse_status "${output}"
	_302parser_parse_gid "${output}" || return 1

	return 0
}

#_302parser_parse_auto

