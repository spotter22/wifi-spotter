# magisk post script

# WebView
echo "- Spoofing User-Agent for WebView..."
resetprop "ro.product.model" "Redmi Note 13 5G"
resetprop "ro.build.id" "QW2P.431870.000"
resetprop "ro.build.version.release" "16"

# CaptivePortal
settings put global captive_portal_user_agent "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.32 Safari/537.36"

# Dalvik
# ?

echo "- Spoofing User-Agent Completed."





