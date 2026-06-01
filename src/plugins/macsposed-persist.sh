# magisk post script

export ASH_STANDALONE=1


_persist_apply_safely(){

		# Ref: https://serverfault.com/a/631119
		addr="none"
		rand=$(printf '%02x' $((0x$(od /dev/urandom -N1 -t x1 -An | tr -d ' ') & 0xFE | 0x02)); od /dev/urandom -N5 -t x1 -An | tr ' '  ':')
	if ([ -z "${addr}" ] || [ "${addr}" = "none" ]) || [ -z "${rand}" ]; then
		exit 1
	fi

	while true; do
		until ip link show dev wlan0 | grep -qs ",UP"; do
			sleep 10
					done
				until iw dev wlan0 info | grep -qs "${addr}"; do
			sleep 10
		done
		ip link set dev wlan0 down
		ip link set dev wlan0 address "${rand}"
		ip link set dev wlan0 up
	done

	return 0
}

_persist_apply_safely
