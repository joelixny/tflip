#!/usr/bin/env bash

###
#
# Download and converts Tabletop Simulator binary mods to usable .json or .cjc files.
#
# Reqiures: mongodb, jq, curl, and sed.
###
yell() { echo "$0: $*" >&2; }
die() { yell "$1"; exit "$2"; }
try() { $1 || die "$2" "$3"; }
convertBSON() {
	# Convert bson to json, remove artifacts, and whitespace formating
	bsondump "${1}" 2>/dev/null                                                    |\
	sed -r 's/(\"DrawImage\":)\{[^\}]*\"\$binary\":(\"[^\}\"]*\")([^\}]*)\}/\1\2/' |\
	jq -M .                                                                        |\
	sed 's/"SaveName": "None"/"SaveName": "'"${2}"'"/'                             |\
	sed 's/"GameMode": "None"/"GameMode": "'"${2}"'"/'                             |\
	sed '/null/d'                                                                  > "${1}.json"
}

if [ $# -eq 0 ]; then
	echo "Usage: ${0} (-n|--name) (-k|--no-clean) [URL]"
	exit 1
fi

NAME=false
CLEAN=true

while [[ $# -gt 0 ]]; do
	OPT="${1}"
	case ${OPT} in
		-n|--name)
			NAME=true
			shift
			;;
		-k|--no-clean)
			CLEAN=false
			shift
			;;
		*)
			URL="${1}"
			shift
			;;
	esac
done

# Fetch download link and title.
API="http://api.steampowered.com/ISteamRemoteStorage/GetPublishedFileDetails/v0001/" 
MID=`echo ${URL} | sed 's/.*id=\([0-9]*\)/\1/'`
MOD=`curl -s --data "itemcount=1&publishedfileids[0]=${MID}&format=json" ${API}`
DLL=`echo ${MOD} | jq '.response.publishedfiledetails[0].file_url'`
DLL=`echo ${DLL} | sed 's/"//g'`
TIT=`echo ${MOD} | jq '.response.publishedfiledetails[0].title'`
TIT=`echo ${TIT} | sed 's/"//g'`

if [ "${NAME}" == "true" ]; then
	FLN="${TIT}"
else
	FLN="${MID}"
fi

echo "Downloading ${TIT}"
try "curl -s ${DLL} -o ${FLN}" "Download failed" 2

# Tries to detect if file is a bson or cjc file. 
# If detection fails try to run with CLEAN=false, and rename the file to `filename.cjc`.
FLT=`file ${FLN}`
FLT=`echo ${FLT} | sed 's/.*: //'`

if   [ "${FLT}" == "TrueType font data" ]; then
	EXT="cjc"
	cp "${FLN}" "${FLN}.cjc"
elif [ "${FLT}" == "data" ]; then
	EXT="json"
	convertBSON "${FLN}" "${TIT}"
else
	echo "Unexpected filetype. Please report issue with the link to the workshop."
	echo "You might get this mod to work by using the --no-clean argument and renaming the file to `filename.cjc`"
fi

if [ "${CLEAN}" == "true" ]; then
	rm "${FLN}"
fi

if [ -s "${FLN}.${EXT}" ]; then
	echo "Saved on ${FLN}.${EXT}"
else
	echo "Saving failed" 
	rm "${FLN}.${EXT}"
	exit 3
fi

exit 0