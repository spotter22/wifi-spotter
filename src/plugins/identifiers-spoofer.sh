# magisk post script

echo "Shuffling identifiers ..."
release=$(echo -e "5\n6\n7\n8\n9\n10\n11\n12\n13\n14\n15\n16\n17" | shuf | sed -n 1p)
model=$(echo -e "SM-S938B\nSM-S901B\nSM-X520\nSM-T575\nSM-F936B" | shuf | sed -n 1p)
build=$(echo -e "RP1A.200720.012\nRN1A.300820.001\nQM1B.400181.411" | shuf | sed -n 1p)


# WebView (spoofs only dynamic values)
# e.g: Mozilla/5.0 (Linux; Android 16; Redmi Note 13 5G Build/QW2P.431870.000; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/122.0.6261.90 Mobile Safari/537.36
echo "Spoofing User-Agent for WebView ..."
resetprop "ro.build.version.release" "${release}"
resetprop "ro.product.model" "${model}"
resetprop "ro.build.id" "${build}"

# CaptivePortal (some varint app can ignore it)
echo "Spoofing User-Agent for Captive-Portal ..."
UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.32 Safari/537.36"
settings put global captive_portal_user_agent "${UA}"
settings put system captive_portal_user_agent  "${UA}"

# Hostname (some systems does not allow to alter it)
echo "Spoofing Hostname ..."
settings put global device_name "${model}"

# Dalvik User-Agent
# can be only altered by hook or modified app


echo "Completed."

