#!/bin/bash


_302parser_crawl_fetch(){
	local url output useragent x
	[ -n "${1}" ] && url="${1}" || url="http://google.com"
	[ -n "${2}" ] && output="${2}" || output="./output_dir"
	[ -n "${3}" ] && useragent="${3}" || useragent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.32 Safari/537.36"

	echo "_302parser_crawl_request: crawling request for: ${url}"
	while read -r x; do
		([ -z "${x}" ] || [[ "${x}" =~ (Prepended | -> |FINISHED |Total wall clock time: |Downloaded: ) ]]) && continue
		#echo "${x}"
	done< <(wget -nc -nv -rU "${useragent}" ${url} -P "${output}" 2>&1)
}


_302parser_request_send(){
	local url output useragent x
	[ -n "${1}" ] && url="${1}" || url="http://google.com"
	[ -n "${2}" ] && output="${2}" || output="./output.log"
	[ -n "${3}" ] && useragent="${3}" || useragent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.32 Safari/537.36"

	echo "_302parser_request_send: sending request for: ${url}"
	curl -svLA "${useragent}" "${url}" &>>"${output}"
	echo -e "\nEOF" >>"${output}" # fixes when last line has no \n

	echo "_302parser_request_send: checking received response..."
	while read -r x; do
		if [[ "${x}" =~ "Failed to connect to " ]]; then
			echo "_302parser_request_send: error no connection (err: ${x})"
			return 1
		elif [[ "${x}" =~ "Could not resolve host: " ]]; then
			echo "_302parser_request_send: error dns failed (err: ${x})"
			return 2
		elif [[ "${x}" =~ "timed out after " ]]; then
			echo "_302parser_request_send: error response timed out (err: ${x})"
			return 3
		elif [[ "${x}" =~ "Recv failure: Software caused connection abort" ]]; then
			echo "_302parser_request_send: error connection lost (err: ${x})"
			return 4
		fi
	done< <(cat "${output}")

	return 0
}


_302parser_parse_login(){
	domain=0; host=0; port=0; page=0
	local input x arr err
	[ -n "${1}" ] && input="${1}" || input="./output.log"
	echo "_302parser_parse_login: parsing login from: ${input}"
	err=0
	while read -r x; do
		if [[ "${x}" =~ (md5\.js|doctype html|<html) ]]; then
			echo "_302parser_parse_login: warning breaking at begin of html (ret: ${x})"
			[ "${domain}" = "www.google.com" ] && { err=4; break; } || { err=1; break; }
		elif [ "${#x}" -le 100 ] && [[ "${x}" =~ "window.location.href" ]]; then
			echo "_302parser_parse_login: following js-redirect (ret: ${x})."
			page="${x// /}"; page="${page/*=\"/}"; page="${page/\"*/}"
			err=2; break
		elif [[ "${x}" =~ '<LoginURL>' ]]; then
			echo "_302parser_parse_login: following xml-redirect (ret: ${x})."
			page=$(echo "${x}" | sed 's|<LoginURL>||; s|</LoginURL>||' | tr -d '\r ')
			err=3; break
		elif [[ "${x}" =~ "Location: " ]]; then
			arr=(${x}); page="${arr[2]##*/}"; page="${page/\?*}"
			[ -n "${page}" ] || page=0
			continue
		elif [[ "${x}" =~ "Established connection to " ]]; then
			arr=(${x}); domain="${arr[3]}"; host="${arr[4]/(/}"; port="${arr[6]/)/}"
			continue
		fi
	done< <(cat "${input}" | tr -d '!*')
	echo "_302parser_parse_login: parsing success: [domain](${domain}) [page](${page}) [host](${host}) [port](${port})"

		if [ ${err} -eq 1 ]; then
			page="${page}"
			return 1
		elif [ ${err} -eq 2 ]; then
			page="${page}"; domain="${domain}/${page}"
			return 2
		elif [ ${err} -eq 3 ]; then
			page="${page##*/}"; domain="${page}"
			return 3
		elif [ ${err} -eq 4 ]; then
			echo "_302parser_parse_login: warning connected network is not captive-portal (ret: ${domain})."
			return 4
		else
			return 0
		fi
}


_302parser_parse_resources(){
	ret=0
	local input x list
	[ -n "${1}" ] && input="${1}" || input="./output.log"
	[ -n "${2}" ] && mode="${2}" || mode="curl"
	[ -n "${3}" ] && index="${2}" || unset index

	echo "_302parser_parse_resources: parsing resources from: ${input}"
	while read x; do
		if [ -z "${x}" ] || [[ "${_VAR_IMMUTABLE_EXCLUDE_RESOURCES}" =~ "${x}" ]]; then
			continue
		elif [[ "${x}" =~ ".js" ]] && [ "${mode}" = "curl" ]; then
			list+="${x},"
		elif [ "${mode}" = "wget" ]; then
			list+=" ${index}/${x}"
		fi
			_VAR_IMMUTABLE_EXCLUDE_RESOURCES+=" ${x}"
	done < <(cat "${input}" | grep -ao '"[^"]\+"' | tr -d '"' | grep -E "\.[a-zA-Z0-9]{2,3}$" | sed 's|^/||g' | sort | uniq)

	if [ -n "${list}" ]; then
		echo "_302parser_parse_resources: parsing success (ret: ${list})."
	else
		echo "_302parser_parse_resources: error parsing failed (ret: null)."
		return 1
	fi

	if [ "${mode}" = "curl" ]; then
		ret="{${list:0:-1}}"
		echo "_302parser_parse_resources: sorting finished (ret: ${ret})."
		return 0
	fi
}


_302parser_parse_status(){
	status="status"
	local input x
	[ -n "${1}" ] && input="${1}" || input="./output.log"
	[ "${2}" = "4" ] && { echo "_302parser_parse_status: warning skipping since error code ${2} is passed."; return 1; }

	echo "_302parser_parse_status: parsing status from: ${input}"
	x=$(cat "${input}" | grep -ao '[^"]\+"' | grep -F '/status?' | tr -d '"' | sort | uniq)

	if [ -n "${x}" ]; then
		status="${x}"
		echo "_302parser_parse_status: parsing success (ret: ${status})."
		return 0
	else
		echo "_302parser_parse_status: warning parsing failed (ret: ${status})."
		return 1
	fi
}


_302parser_parse_strings(){
	grep -aoe '"[^"]\+"' -e '>[^<]\+<' | sort | uniq
}


_302parser_filter_strings(){
	grep -Ev "\
\"#......\"\
|\"[0-9]{1,5}\"\
|\"color.*(.*)\"\
|\".*-.*:.*;\"\
|\".*:.*px\"\
|>[0-9]{2,5} [^0-9]{1,10}<\
|[^0-9] [0-9]{2,5} [^0-9]\
|\.(png|jpg|js|css|svg)\"\
|\".*:.*(px|%);\"\
|}.*else.*{\
|\"[^.]{1,5}\"\
|bg-\[#........\]\
|(bg-|border-|rounded-|object-|overflow-|items-|font-|marginRight|\"background: |ISO[0-9]{4}[^0-9]|Cp[0-9]{4}[^0-9]|\"windows-[0-9]{4}\"|linear-gradient)\
|\"....\"\
|[^0-9] [0-9]{2,3}% [^0-9]\
| if (.*) {\
| [0-9]{1,2}\.[0-9]{2,3} [0-9]{1,3}\.[0-9]{2} \
|.*().*;.*().*;\
|[0-9]{1,3}\.[0-9],[0-9]{1,3}\
| [0-9]{1,2}\.[0-9] [0-9] [0-9] \
|\\\u....\\\u....\\\u....\
|.*(.*).*\|\|\
|RegExp\(.*\)\
|\(.*\..*\)\
|[0-9]{1,4}.*\*\
|.*=.*\?\
| \|= \
|(ABCDEF|abcdef)\
|[0-9]\.[0-9]{2,3} [0-9]\.[0-9]{2,3} \
|.*function.*\(.*\)/*{\
|[0-9]{2,3} [0-9]{2,3} [0-9]{2,3} [0-9]{2,3} [0-9]{2,3} [0-9]{2,3}\
|Math\..*\(.*\)\
|background: #......;\
|[0-9a-fA-F]{2}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}\
|(return .*\(|t.append\(|String.fromCharCode\(|throw .*\(|constructor\(\)|switch\(.*\)|setAttribute\(|emit\()\
|,.*:.*,.*:.*,\
|(width=[0-9]{1,4}[^0-9]|height=[0-9]{1,4}[^0-8])\
|VARIABLE_LENGTH,\
|\",.*\[.*\]=\"\
|.*\(.*\),.*\(.*\),\
|>=.{1,10}<|\",.{1,10}\"|\".{1,10}\?\"|>.{1,10}&.*\(|>.{1,10}\|=.*<|\+\(.*\)\+\(.*\)<\
|http://|https://\
|.* \
|\"#gentle-wave\"|\"\).replace\(\"|\"\){document.write\(\"|\"--acid-height\"|\"-upoff\"|\".replace\(\"|\"1.1\"\
|\"16M/16M\"|\"256k/256k\"|\"32M/32M\"|\"512k/512k\"|\";path=/\"|\"</div>\"|\">unlimited</span>\"\
|\"Cache-Control\"|\"Content-Type\"|\"Expires\"|\"IE=edge,chrome=1\"|\"JavaScript\"|\"Layer_1\"\
|\"Pragma\"|\"X-UA-Compatible\"|\"_blank\"|\"acid-container\"|\"action-button\"|\"action-buttons\"\
|\"additional-options\"|\"adv.html\"|\"applyChange\"|\"assets/img/favicon.ico\"|\"banner\"|\"battery\"\
|\"battery2\"|\"btn-group\"|\"button\"|\"byteLeft\"|\"byteLeft2\"|\"byteLeft3\"|\"byteLeft4\"|\"byteLeft5\"\
|\"card-con\"|\"center\"|\"choose-auto-update-off\"|\"choose-link-card-to-8888\"|\"content-wrapper\"\
|\"copyright2\"|\"details\"|\"domain\"|\"domain=\"|\"domainvalue\(\)\"|\"dropdown-container\"\
|\"dropdown-style\"|\"erase-cookie\"|\"eraseCookie\"|\"ether_cart\"|\"expires\"|\"expires=\"\
|\"finalLogoutButton\"|\"floateed\"|\"font/woff2\"|\"fonts/Cairo.woff2\"|\"forface\"|\"format-detection\"\
|\"gentle-wave\"|\"header\"|\"hidden\"|\"icon-alert\"|\"icon-clock-1\"|\"icon-download\"|\"icon-download-1\"\
|\"icon-login\"|\"icon-off\"|\"icon-user\"|\"image/png\"|\"images/favicon.ico\"|\"index.html\"|\"info-section\"\
|\"info-title\"|\"info-value\"|\"interactive\"|\"javascript\"|\"lastcard\"|\"lastcardsize\"|\"lastcardspeed\"|\"lastsize\"\
|\"lastuser\"|\"letter\"|\"letter-a\"|\"letter-i\"|\"letter-k\"|\"letter-l\"|\"letter-n\"|\"letter-r\"|\"letter-s\"|\"letter-t\"|\"letters\"\
|\"line_fragmentshader\"|\"line_vertexshader\"|\"logo-0000\"|\"logo-basheer\"|\"logo_x\"|\"logout\"|\"logoutButton\"\
|\"main-content-area\"|\"mask_x1\"|\"mask_x2\"|\"message-content\"|\"message-wrapper\"|\"middle\"|\"no-cache\"\
|\"openAdvert\(\)\"|\"openQuranPlayer\(\)\"|\"overlay\"|\"parallax\"|\"password\"|\"password=\"|\"percentage\"\
|\"pragma\"|\"preload\"|\"preserve\"|\"progress-bar\"|\"progress-fill\"|\"refresh\"|\"remain\"|\"section\"|\"sendin\"\
|\"speed_economic\"|\"speed_gaming\"|\"speed_high\"|\"speed_normal\"|\"speed_very\"|\"starlink-logo\"\
|\"status-btn\"|\"status-card\"|\"stylesheet\"|\"sub-title\"|\"submit\"|\"tabula\"|\"telephone=no\"|\"text/css\"\
|\"text/javascript\"|\"theme-color\"|\"timeLeft\"|\"timeLeft2\"|\"top-message\"|\"unlimited\"|\"update\"\
|\"updateStatus\"|\"url\(#mask_x1\)\"|\"url\(#mask_x2\)\"|\"usageProgress\"|\"usageText\"\
|\"username\"|\"username=\"|\"usernameDisplay\"|\"usernames\"|\"valuee\"|\"viewport\"\
|\"x-shader/x-fragment\"|\"x-shader/x-vertex\"|>\"\)};<|>connected:<|>document.write\(UpdateStatus\(\(update\)\)\);<\
|>document.write\(checkSpeed\(\(speed\)\)\);<|>nameCard\(\);<\
"
}


_302parser_parse_digits(){
	grep -Eo "\
[0-9]{5,15}\
|\([0-9]-[0-9]{3}\) [0-9]{5}\
|\([0-9]-[0-9][0-9][0-9]\) [0-9][0-9][0-9][0-9][0-9]\
|\([0-9][0-9][0-9]\) [0-9][0-9][0-9]-[0-9][0-9][0-9][0-9]\
|\([0-9][0-9][0-9]\) [0-9][0-9][0-9][0-9][0-9][0-9]\
|[0-9] \([0-9][0-9][0-9]\) [0-9][0-9][0-9] [0-9][0-9][0-9][0-9]\
|[0-9] \([0-9][0-9][0-9]\) [0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\
|[0-9] [0-9][0-9] [0-9][0-9][0-9][0-9][0-9][0-9]\
|[0-9] [0-9][0-9][0-9] [0-9][0-9][0-9]\
|[0-9] [0-9][0-9][0-9] [0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\
|[0-9] [0-9][0-9][0-9][0-9] [0-9][0-9][0-9][0-9]\
|[0-9][0-9] [0-9][0-9] [0-9][0-9] [0-9][0-9] [0-9][0-9]\
|[0-9][0-9] [0-9][0-9] [0-9][0-9] [0-9][0-9]\
|[0-9][0-9] [0-9][0-9] [0-9][0-9]\
|[0-9][0-9] [0-9][0-9][0-9] [0-9][0-9] [0-9][0-9]\
|[0-9][0-9] [0-9][0-9][0-9] [0-9][0-9][0-9]\
|[0-9][0-9] [0-9][0-9][0-9] [0-9][0-9][0-9][0-9]\
|[0-9][0-9] [0-9][0-9][0-9]\
|[0-9][0-9] [0-9][0-9][0-9][0-9][0-9][0-9]\
|[0-9][0-9] [0-9][0-9][0-9][0-9][0-9][0-9][0-9]\
|[0-9][0-9] [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\
|[0-9][0-9][0-9] [0-9][0-9] [0-9][0-9] [0-9][0-9]\
|[0-9][0-9][0-9] [0-9][0-9] [0-9][0-9]\
|[0-9][0-9][0-9] [0-9][0-9] [0-9][0-9][0-9] [0-9][0-9]\
|[0-9][0-9][0-9] [0-9][0-9][0-9] [0-9][0-9] [0-9][0-9]\
|[0-9][0-9][0-9] [0-9][0-9][0-9] [0-9][0-9][0-9]\
|[0-9][0-9][0-9] [0-9][0-9][0-9] [0-9][0-9][0-9][0-9]\
|[0-9][0-9][0-9] [0-9][0-9][0-9]\
|[0-9][0-9][0-9] [0-9][0-9][0-9]-[0-9][0-9][0-9]\
|[0-9][0-9][0-9] [0-9][0-9][0-9][0-9]\
|[0-9][0-9][0-9] [0-9][0-9][0-9][0-9][0-9]\
|[0-9][0-9][0-9] [0-9][0-9][0-9][0-9][0-9][0-9]\
|[0-9][0-9][0-9] [0-9][0-9][0-9][0-9][0-9][0-9][0-9]\
|[0-9][0-9][0-9] [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\
|[0-9][0-9][0-9]-[0-9][0-9][0-9] [0-9][0-9] [0-9][0-9]\
|[0-9][0-9][0-9]-[0-9][0-9][0-9] [0-9][0-9][0-9][0-9]\
|[0-9][0-9][0-9]-[0-9][0-9][0-9]-[0-9][0-9][0-9][0-9]\
|[0-9][0-9][0-9]-[0-9][0-9][0-9][0-9]\
|[0-9][0-9][0-9]-[0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9]\
|[0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9][0-9]\
|[0-9][0-9][0-9][0-9] [0-9][0-9] [0-9][0-9] [0-9][0-9]\
|[0-9][0-9][0-9][0-9] [0-9][0-9] [0-9][0-9][0-9]\
|[0-9][0-9][0-9][0-9] [0-9][0-9][0-9] [0-9][0-9] [0-9][0-9]\
|[0-9][0-9][0-9][0-9] [0-9][0-9][0-9] [0-9][0-9][0-9]\
|[0-9][0-9][0-9][0-9] [0-9][0-9][0-9] [0-9][0-9][0-9][0-9]\
|[0-9][0-9][0-9][0-9] [0-9][0-9][0-9]-[0-9][0-9][0-9][0-9]\
|[0-9][0-9][0-9][0-9] [0-9][0-9][0-9][0-9]\
|[0-9][0-9][0-9][0-9] [0-9][0-9][0-9][0-9][0-9][0-9]\
|[0-9][0-9][0-9][0-9] [0-9][0-9][0-9][0-9][0-9][0-9][0-9]\
|[0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9]\
|[0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9]-[0-9][0-9][0-9]\
|[0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9]\
|[0-9][0-9][0-9][0-9][0-9] [0-9][0-9][0-9][0-9][0-9][0-9]\
|[0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9]\
|[0-9][0-9][0-9][0-9][0-9][0-9] [0-9][0-9][0-9][0-9][0-9]\
|[0-9][0-9][0-9][0-9][0-9][0-9]\
|[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\
"
}


_302parser_parse_gid(){
	gid=(0 0 0)
	local input code x
	[ -n "${1}" ] && input="${1}" || input="./output.log"
	[ -n "${2}" ] && code="${2}" || unset code

		echo "_302parser_parse_gid: parsing gid from: ${input}"
	if [ "${code}" = "4" ]; then
		echo "_302parser_parse_gid: warning skipping since error code ${2} is passed."
		return 1
	else

			gid[1]=$(cat "${input}" | _302parser_parse_strings | tr '\r\n' '.')
		if [ -n "${gid[1]}" ]; then
			echo "_302parser_parse_gid: parsing success (ret: ${gid[1]})."
		else
			echo "_302parser_parse_gid: parsing failed (ret: ${gid[1]})."
		fi

			gid[2]=$(cat "${input}" | grep -Eao '<title.*>.*</title>|<h[1-6].*>.*</h[1-6]>' | grep -va '{{.*}}' | tr '\r\n' '.')
		if [ -n "${gid[2]}" ]; then
			echo "_302parser_parse_gid: parsing success (ret: ${gid[2]})."
		else
			echo "_302parser_parse_gid: parsing failed (ret: ${gid[2]})."
		fi
				
			gid[1]=$(cat "${input}" | _302parser_parse_strings | _302parser_parse_digits | sort | uniq | tr '\r\n' '.')
		if [ -n "${gid[1]}" ]; then
			echo "_302parser_parse_gid: filtering success (ret: ${gid[1]})."
		else
			echo "_302parser_parse_gid: filtering failed (ret: ${gid[1]})."
		fi	
	fi

	#echo "_302parser_parse_gid: error generating gid failed (err: null)."; return 1; }
	x=$(echo -n "${gid[1]}.${gid[2]}" | md5sum); gid[0]="${x/  -/}"
	return 0
}


_302parser_crawl_auto(){
		output_dir="${output%/*}"
			mkdir -p "${output_dir}" || return 1
				_302parser_crawl_fetch "${host}:${port}" "${output_dir}"; exit
					_302parser_parse_resources "${output_dir}" "${domain%/*}"; result="${ret}"
						_302parser_crawl_fetch "${result}" "${output_dir}"
}


_302parser_parse_auto(){
	local url output output_dir err result _attempt
	[ -n "${1}" ] && url="${1}" || url="http://google.com"
	[ -n "${2}" ] && output="${2}" || output="./output.log"

	echo -n>"${output}"
	_302parser_request_send "${url}" "${output}" || return 1
		_302parser_parse_login "${output}"; err=${?}

	if [ ${err} -eq 1 ]; then
		:
	elif [ ${err} -eq 2 ] || [ ${err} -eq 3 ]; then
		_302parser_request_send "${host}:${port}/${page}" "${output}" || return 1
	elif [ ${err} -eq 4 ]; then
		_302parser_parse_status "${output}" "${err}"
		_302parser_parse_gid "${output}" "${err}"
		return 4
	else
		echo "_302parser_parse_auto: an error occurred while trying to parse (err: ${err}). "
		return 1
	fi

		_attempt=0
	until [ ${_attempt} -ge 10 ]; do
		_302parser_parse_resources "${output}" "curl"; result="${ret}"
		[ "${result}" = "0" ] && break
		_302parser_request_send "${host}:${port}/${result}" "${output}" || return 1
		_attempt=$((_attempt+1))
	done

	if [ ${_attempt} -ge 10 ]; then
		echo "_302parser_parse_auto: unexpected error exccedd maximum attempts (ret: ${result})."
	fi

	_302parser_parse_status "${output}"
	_302parser_parse_gid "${output}" "p2"

	return 0
}


_302parser_test_manually(){
	echo -e "_302parser_test_manually: performing manually test: $1"
	echo -e "\nPARSE:"
	cat "$1" | _302parser_parse_strings
	echo -e "\nFilter:"
	cat "$1" | _302parser_parse_strings | _302parser_filter_strings
}


_302parser_test_all(){
	local result_digits result_strings
	echo -e "_302parser_test_filter: performing digits-test..."
	result_digits=$(cat "tests/302parser-digits.txt" | _302parser_parse_digits | wc -l)

	echo -e "_302parser_test_filter: performing strings-test..."
	result_strings=$(cat "tests/302parser-strings.txt" | _302parser_filter_strings | wc -l)

	if [ ${result_digits} -eq 55 ]; then
		echo -e "_302parser_test_filter: Passed digits-test (ret: ${result_digits})."
	else
		echo -e "\nParse (digits-test):"
		cat "tests/302parser-digits.txt"

		echo -e "\nFilter (digits-test):"
		cat "tests/302parser-digits.txt" | _302parser_parse_digits >tmp
		cat "tests/302parser-digits.txt" "tmp" | sort | uniq -u

		echo -e "_302parser_test_filter: Failed digits-test (ret: ${result_digits})."
	fi

	if [ ${result_strings} -eq 0 ]; then
		echo -e "_302parser_test_filter: Passed strings-test (ret: ${result_strings})."
	else
		echo -e "\nParse (strings-test):"
		cat "tests/302parser-strings.txt"

		echo -e "\nFilter (strings-test):"
		cat "tests/302parser-strings.txt" | _302parser_filter_strings >tmp
		cat "tests/302parser-strings.txt" "tmp" | sort | uniq -u

		echo -e "_302parser_test_filter: Failed strings-test (ret: ${result_strings})."
	fi

}


#_302parser_test_all
_302parser_test_manually "$1"
#_302parser_parse_resources "$1"
#_302parser_parse_login "$1"
#_302parser_parse_auto "${@}"
#_302parser_parse_gid "$1"
#_302parser_parse_resources "${@}"

