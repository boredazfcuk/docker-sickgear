#!/bin/ash
exit_code=0
exit_code="$(wget --quiet --tries=1 --spider --no-check-certificate "https://${HOSTNAME}:8081/sickgear/images/ico/favicon.ico" | echo ${?})"
if [ "${exit_code}" != 0 ]; then
   echo "WebUI not responding: Error ${exit_code}"
   exit 1
fi
echo "WebUIs available"
exit 0