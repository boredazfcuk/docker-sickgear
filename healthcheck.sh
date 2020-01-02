#!/bin/ash
EXIT_CODE=0
EXIT_CODE="$(wget --quiet --tries=1 --spider --no-check-certificate "https://${HOSTNAME}:8081/sickgear/images/ico/favicon.ico" | echo ${?})"
if [ "${EXIT_CODE}" != 0 ]; then
   echo "WebUI not responding: Error ${EXIT_CODE}"
   exit 1
fi
echo "WebUIs available"
exit 0