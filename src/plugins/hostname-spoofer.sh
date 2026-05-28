# magisk post script

export ASH_STANDALONE=1

_spoofer_get_prop(){
	model=0; release=0; build=0; UA=0
	local i props

	echo "getting valid props..."
	UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.32 Safari/537.36"

	if [ "$(shuf -e "test")" != "test" ]; then
		unset mode release build
		echo "error: can not execute shuf utility."
		return 1
	fi

	props="\
00CN_1_270 SG1 7.1.1 SHARP SG1 
00WW_5_15G NB1 9 Nokia NB1 
32.4.A.1.54 E5823 7.1.1 Sony E5823 
54.0.A.6.23 I4312 8.1.0 Sony I4312 
62.0.A.3.131 XQ-BT52 11 Sony XQ-BT52 
AGS2-W09-8.0.0.317OCEC431 HWAGS2 8.0.0 HUAWEI HWAGS2 
AN3516-camellia-build-20221116211412 camellia 12 Redmi camellia 
BKL-L09-10.0.0.177(C432E4R1P4) HWBKL 10 HONOR HWBKL 
CLT-L09-9.0.0.168C782E3R1P9 HWCLT 9 HUAWEI HWCLT 
CLT-L29-10.0.0.171C432E3R1P3 HWCLT 10 HUAWEI HWCLT 
CLT-L29-8.1.0.131C432 HWCLT 8.1.0 HUAWEI HWCLT 
CLT-L29-9.1.0.387C432E8R1P11 HWCLT 9 HUAWEI HWCLT 
CPH2387_11_A.26 OP5355 12 OPPO OP5355 
DE2118_10_210430 OnePlusN200TMO 11 OnePlus OnePlusN200TMO 
DUA-L22-1.0.0.147(C432) HWDUA-M 8.1.0 HONOR HWDUA-M 
DUB-LX1-8.2.0.145C10 HWDUB-Q 8.1.0 HUAWEI HWDUB-Q 
DUB-LX1-8.2.0.145C636 HWDUB-Q 8.1.0 HUAWEI HWDUB-Q 
ENT_PE_A5_2020_V5.0 P963F50 9 ZTE P963F50 
Flyme-6.3.2.0G M3s 5.1 Meizu M3s 
GEN_AE_A3_2020_V1.0 P932F50 9 ZTE P932F50 
GEN_GLB_V10_VITA_V1.3 P963F01 9 ZTE P963F01 
JSN-L21-9.1.0.221(C10E2R2P1) HWJSN-H 9 HONOR HWJSN-H 
LDN-L21-8.0.0.164C185 HWLDN-Q 8.0.0 HUAWEI HWLDN-Q 
LE7n-H697MN-R-RU-230518V359 TECNO-LE7n 11 TECNO TECNO-LE7n 
LMY47V.J111MUBS0AQJ6 J111M 5.1.1 samsung j1acevelte 
LRX22C.I9505XXUHOD7 I9505 5.0.1 samsung jflte 
M1AJQ.J727T1UVS8BTI1 J727T 8.1.0 samsung j7popeltemtr 
MAR-L21A-10.0.0.275C431E8R2P7 HWMAR 10 HUAWEI HWMAR 
MMB29M.G900VVRU2DQL1 G900V 6.0.1 samsung kltevzw 
MMB29M.J510FNXXU1APG1 J510F 6.0.1 samsung j5xnlte 
MPB24.65-34-3 titan_udstv 6.0 motorola titan_udstv 
MRA58K p1 6.0 lge p1 
N2G47H cv109 7.1.2 lge cv109 
N2G47H rolex 7.1.2 Xiaomi rolex 
NRD90M.A510FXXS8CTI6 A510F 7.0 samsung a5xelte 
NRD90M.G925FXXS6ETK1 G925F 7.0 samsung zerolte 
NRD90M.G925IDVS4FTJ3 G925I 7.0 samsung zerolte 
NRD90M.J327AUCS2ARD2 J327A 7.0 samsung j3popelteatt 
NRD90U mlv7 7.0 lge mlv7 
O11019 mcv1s 8.1.0 lge mcv1s 
ONEPLUS-A5010_43_200224 OnePlus5T 9 OnePlus OnePlus5T 
OPM1.171019.026 1817 8.1.0 vivo 1817 
OPM1.171019.026 cv1 8.1.0 lge cv1 
OPP28.85-19-4-2 cedric 8.1.0 motorola cedric 
OPSS27.76-12-25-23 albus 8.0.0 motorola albus 
PKQ1.190118.001 1723 9 vivo 1723 
PKQ1.190416.001.V10.3.13.0.PFQEUXM laurel_sprout 9 Xiaomi laurel_sprout 
PPPS29.55-35-23-7 aljeter 9 motorola aljeter 
PPR1.180610.011.A202FXXU2ASJ3 A202F 9 samsung a20e 
PPR1.180610.011.A205GUBU2ASG1 A205G 9 samsung a20 
PPR1.180610.011.A530FXXULCUK6 A530F 9 samsung jackpotlte 
PPR1.180610.011.G950FXXSBDTJ1 G950F 9 samsung dreamlte 
PPR1.180610.011.G970USQS1ASD9 G970U 9 samsung beyond0q 
PPR1.180610.011.J415FNPUU6BUE1 J415F 9 samsung j4primelte 
PPR1.180610.011.J730GMUBU8CSK1 J730G 9 samsung j7y17lte 
PPR1.180610.011.N950FXXSEDTL1 N950F 9 samsung greatlte 
PPR1.180610.011.N950U1UES8DTG2 N950U 9 samsung greatqlteue 
PPR1.180610.011.N960USQS2CSGB N960U 9 samsung crownqltesq 
PPR1.180610.011.N975FXXU1ASH5 N975F 9 samsung d2s 
PQ3A.190505.001 taimen 9 google taimen 
QKQ1.190910.002 lavender 10 xiaomi lavender 
QKQ1.190910.002 platina 10 Xiaomi platina 
QKQ1.190929.002 alphalm 10 lge alphalm 
QKQ1.191008.001 onc 10 xiaomi onc 
QKQ1.191014.001 pine 10 Xiaomi pine 
QKQ1.191215.002 curtana 10 Redmi curtana 
QKQ1.191215.002 joyeuse 10 Redmi joyeuse 
QKQ1.200108.002 mdh5lm 10 lge mdh5lm 
QKQ1.200114.002 willow 10 xiaomi willow 
QKQ1.200216.002 mdh50lm 10 lge mdh50lm 
QKQ1.200730.002 mdh30lm 10 lge mdh30lm 
QP1A.190711.020 Tokyo_Lite_4G 10 T-Mobile Tokyo_Lite_4G 
QP1A.190711.020 U705AC 10 Cricket U705AC 
QP1A.190711.020 angelican 10 Redmi angelican 
QP1A.190711.020 begonia 10 Redmi begonia 
QP1A.190711.020 dandelion 10 Redmi dandelion 
QP1A.190711.020.A115AZTUU3ATL2 A115A 10 samsung a11q 
QP1A.190711.020.A205FXXS8BTG1 A205F 10 samsung a20 
QP1A.190711.020.A205USQU5BTF3 A205U 10 samsung a20p 
QP1A.190711.020.A515FXXU4CTJ1 A515F 10 samsung a51 
QP1A.190711.020.G960FXXSBETH2 G960F 10 samsung starlte 
QP1A.190711.020.G960FXXSHFUJ2 G960F 10 samsung starlte 
QP1A.190711.020.G960FXXUFFUE1 G960F 10 samsung starlte 
QP1A.190711.020.G960USQS9FUG2 G960U 10 samsung starqltesq 
QP1A.190711.020.G965FXXUGFUG4 G965F 10 samsung star2lte 
QP1A.190711.020.G965USQS9FUG2 G965U 10 samsung star2qltesq 
QP1A.190711.020.G970FXXS9DTK9 G970F 10 samsung beyond0 
QP1A.190711.020.G970FXXU8CTG4 G970F 10 samsung beyond0 
QP1A.190711.020.G975USQS4ETJ2 G975U 10 samsung beyond2q 
QP1A.190711.020.N960FXXS7FUA1 N960F 10 samsung crownlte 
QP1A.190711.020.T295XXU3BUC3 T295X 10 samsung gto 
QP1A.190711.020.T835PUS5CUD1 T835P 10 samsung gts4llte 
QP1A.191005.007.A3 sailfish 10 google sailfish 
QPCS30.Q4-31-26-1-9 minsk 10 motorola minsk 
QPJS30.131-61-10 rav 10 motorola rav 
QQ2A.200501.001.B2.2020.05.05.02 sargo 10 Android sargo 
QQ3A.200805.001 walleye 10 google walleye 
QZA30.Q4-39-57-2-2-1 guamna 10 motorola guamna 
QZB30.Q4-43-120 borneo 10 motorola borneo 
R16NW.A520FXXUGCTKA A520F 8.0.0 samsung a5y17lte 
R16NW.A530FXXS3BRL1 A530F 8.0.0 samsung jackpotlte 
R16NW.G930FXXS6ESI5 G930F 8.0.0 samsung herolte 
R16NW.G930W8VLS5CSA1 G930W 8.0.0 samsung heroltebmc 
R16NW.G935FXXS5ESF8 G935F 8.0.0 samsung hero2lte 
R16NW.G935FXXS8ETC6 G935F 8.0.0 samsung hero2lte 
R16NW.G935SKSU3ETJ1 G935S 8.0.0 samsung hero2lteskt 
R16NW.G950FXXU2CRF7 G950F 8.0.0 samsung dreamlte 
R16NW.G950FXXU3CRGB G950F 8.0.0 samsung dreamlte 
R16NW.G960FXXU2BRGA G960F 8.0.0 samsung starlte 
R16NW.S767VLUDU3ASC2 S767V 8.0.0 samsung j7topeltetfnvzw 
RD2A.211001.002 barbet 11 google barbet 
RIO-AL00C00B394- hwRIO-AL00 6.0.1 HUAWEI hwRIO-AL00 
RKQ1.200826.002 joyeuse 11 Redmi joyeuse 
RKQ1.200826.002 surya 11 POCO surya 
RKQ1.200826.002 sweet 11 Redmi sweet 
RKQ1.201022.002 OnePlus7T 11 OnePlus OnePlus7T 
RKQ1.210420.001 mdh30xlm 11 lge mdh30xlm 
RKQ1.211001.001 spes 11 Redmi spes 
RMX1971_11_C.02 RMX1971 10 realme RMX1971 
RP1A.200720.011 S42 11 Cat S42 
RP1A.200720.011 U319AA 10 ATT U319AA 
RP1A.200720.012.A015FXXU4BUD8 A015F 11 samsung a01q 
RP1A.200720.012.A115FXXS2BVA2 A115F 11 samsung a11q 
RP1A.200720.012.A125FXXU1BUG6 A125F 11 samsung a12 
RP1A.200720.012.A125USQU2BUJ5 A125U 11 samsung a12u 
RP1A.200720.012.A217FXXU7CUK1 A217F 11 samsung a21s 
RP1A.200720.012.A326USQU7AVB1 A326U 11 samsung a32x 
RP1A.200720.012.A405FNXXU3CUF2 A405F 11 samsung a40 
RP1A.200720.012.A505FDDU7CUD4 A505F 11 samsung a50 
RP1A.200720.012.A505U1UEUJDVG3 A505U 11 samsung a50 
RP1A.200720.012.A525FXXU2AUF3 A525F 11 samsung a52q 
RP1A.200720.012.G970FXXS9EUB1 G970F 11 samsung beyond0 
RP1A.200720.012.G970USQS5GUF1 G970U 11 samsung beyond0q 
RP1A.200720.012.G981WVLU2DUDB G981W 11 samsung x1q 
RP1A.200720.012.G985FXXSCDUJ5 G985F 11 samsung y2s 
RP1A.200720.012.G991BXXS3AUJ7 G991B 11 samsung o1s 
RP1A.200720.012.G991USQU3AUDD G991U 11 samsung o1q 
RP1A.200720.012.G996BXXU3AUGM G996B 11 samsung t2s 
RP1A.200720.012.G998BXXU2AUC8 G998B 11 samsung p3s 
RP1A.200720.012.N975U1UES7FUH7 N975U 11 samsung d2q 
RQ2A.210405.005.2021.04.16.04 bonito 11 Android bonito 
RQ3A.210805.001.A1.2.8.0 sargo 11 Android sargo 
RQ3A.210905.001 redfin 11 google redfin 
RRHS31.Q3-46-110-10 ellis 11 motorola ellis 
RTAS31.68-29-2 java 11 motorola java 
S1PB32.41-10-17-3-4 burton 12 motorola burton 
SD1A.210817.036 raphael 12 Xiaomi raphael 
SKQ1.210908.001 sweet 12 Redmi sweet 
SKQ1.211006.001 vili 12 Xiaomi vili 
SLA-L22C432B176- HWSLA-Q 7.0 HUAWEI HWSLA-Q 
SNE-LX3-10.0.0.178C212E3 HWSNE 10 HUAWEI HWSNE 
SP1A.210812.003 2036 12 vivo 2036 
SP1A.210812.015.2021102300 redfin 12 google redfin 
SP1A.210812.016 raphael 12 Xiaomi raphael 
SP1A.210812.016.A035FXXU2BVI8 A035F 12 samsung a03 
SP1A.210812.016.A136USQU2BVE9 A136U 12 samsung a13x 
SP1A.210812.016.G970FXXUGHVJ5 G970F 12 samsung beyond0 
SP1A.210812.016.G973FXXSEGVA9 G973F 12 samsung beyond1 
SP1A.210812.016.G973FXXSGHWA3 G973F 12 samsung beyond1 
SP1A.210812.016.G973U1UES7IVJ2 G973U 12 samsung beyond1q 
SP1A.210812.016.G980FXXUDEVA9 G980F 12 samsung x1s 
SP1A.210812.016.G988BXXUDEVA9 G988B 12 samsung z3s 
SP1A.210812.016.G996BXXU3BUK8 G996B 12 samsung t2s 
SP1A.210812.016.G998U1UEU5CVDC G998U 12 samsung p3q 
SP1A.210812.016.M315FXXU2CVCE M315F 12 samsung m31 
SP1A.210812.016.M317FXXU3DVH2 M317F 12 samsung m31s 
SP1A.210812.016.N981USQU2FVEB N981U 12 samsung c1q 
STK-L22-9.1.0.231C636E2R2P1 HWSTK-HF 9 HUAWEI HWSTK-HF 
TP1A.220624.014.A146USQU1AWA6 A146U 13 samsung a14xm 
TP1A.220624.014.A715FXXUADWH4 A715F 13 samsung a71 
TP1A.220624.014.F936BXXS2CWB5 F936B 13 samsung q4q 
TP1A.220624.014.G981BXXSFGWA7 G981B 13 samsung x1s 
TP1A.220624.014.G981VSQS3HWC3 G981V 13 samsung x1q 
TP1A.220624.014.S906U1UES2BWA2 S906U 13 samsung g0q 
TP1A.220905.004.A1.2022092300 raven 13 google raven 
TQ1A.230205.002 bluejay 13 google bluejay 
UP1A.231005.007.G990U2SQS9GXF1 G990U 14 samsung r9q 
WAS-LX1-8.0.0.390C432 HWWAS-H 8.0.0 HUAWEI HWWAS-H 
WTRVL5G_0.07.29 Sprout 10 T-Mobile Sprout 
X652B-H627CDM-P-210105V260 Infinix-X652B 9 Infinix Infinix-X652B 
X657B-H6117DFJ-QGo-OP-201103V301 Infinix-X657B 10 Infinix Infinix-X657B 
YAL-L61-10.1.0.252C10E3R1P1 HWYAL 10 HUAWEI HWYAL 
Z559DLV1.0.0B13 Z559DL 8.1.0 ZTE Z559DL 
Z828RV1.0.0B03 achill 5.1.1 zte achill 
ZQL2115-olive-build-20200604214157 olive 9 Xiaomi olive
"

		i=0
	for x in $(echo -e "${props}" | shuf | sed -n 1p); do
			i=$((i+1))
		if [ ${i} -eq 1 ]; then
			build="${x}"
		elif [ ${i} -eq 2 ]; then
			model="${x}"
		elif [ ${i} -eq 3 ]; then
			version="${x}"
		elif [ ${i} -eq 4 ]; then
			break
		fi
	done

	return 0
}


_spoofer_set_prop(){


	# CaptivePortal (some varint app can ignore it)
	echo "settings put global captive_portal_user_agent \"${UA}\"" | su -
	echo "settings put system captive_portal_user_agent  \"${UA}\"" | su -

	# Hostname (some systems does not allow to alter it)
	echo "settings put global device_name \"${model}\"" | su -
	echo "settings put secure bluetooth_name \"${model}\"" | su -

	# Dalvik User-Agent
	# can be only altered by hook or modified app

	# WebView (spoofs only dynamic values)
	# e.g: Mozilla/5.0 (Linux; Android 16; Redmi Note 13 5G Build/QW2P.431870.000; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/122.0.6261.90 Mobile Safari/537.36
	resetprop "ro.build.version.release" "${release}"
	resetprop "ro.product.model" "${model}"
	resetprop "ro.build.id" "${build}"

	echo "spoofing props completed !"

	return 0
}


_spoofer_apply_safely(){
		local i; i=0

		echo "startting props spoofer..."
	until ([ ${i} -gt 180 ] || [ -z "$(settings get global "device_name" 2>&1 | grep -F "cmd: Can't find service:")" ]); do
		i=$((i+1)); echo "error: settings service not ready yet (${i})."
		sleep 1
	done

	if [ ${i} -le 180 ]; then
		_spoofer_get_prop
		_spoofer_set_prop
		echo "hostname-spoofer succedd within: ${i} seconds."
		return 0
	else
		echo "error: hostname-spoofer ended with errors."
		return 1
	fi

}


_spoofer_apply_safely 

