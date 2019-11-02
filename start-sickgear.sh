#!/bin/ash

##### Functions #####
Initialise(){
   LANIP="$(hostname -i)"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    ***** Starting SickGear/SickGear container *****"
   if [ -z "${USER}" ]; then echo "$(date '+%Y-%m-%d %H:%M:%S') WARNING: User name not set, defaulting to 'user'"; USER="user"; fi
   if [ -z "${UID}" ]; then echo "$(date '+%Y-%m-%d %H:%M:%S') WARNING: User ID not set, defaulting to '1000'"; UID="1000"; fi
   if [ -z "${GROUP}" ]; then echo "$(date '+%Y-%m-%d %H:%M:%S') WARNING: Group name not set, defaulting to 'group'"; GROUP="group"; fi
   if [ -z "${GID}" ]; then echo "$(date '+%Y-%m-%d %H:%M:%S') WARNING: Group ID not set, defaulting to '1000'"; GID="1000"; fi
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Local user: ${USER}:${UID}"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Local group: ${GROUP}:${GID}"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    SickGear application directory: ${APPBASE}"
   sed -i "s%web_host =.*$%web_host = ${LANIP}%" "${CONFIGDIR}/config.ini"

   if [ ! -f "${CONFIGDIR}/ssl" ]; then mkdir -p "${CONFIGDIR}/ssl"; fi
   if [ ! -f "${CONFIGDIR}/ssl/sickgear.crt" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Generate private key for encrypting communications"
      openssl ecparam -genkey -name secp384r1 -out "${CONFIGDIR}/ssl/sickgear.key"
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Create certificate request"
      openssl req -new -subj "/C=NA/ST=Global/L=Global/O=SickGear/OU=SickGear/CN=SickGear/" -key "${CONFIGDIR}/ssl/sickgear.key" -out "${CONFIGDIR}/ssl/sickgear.csr"
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Generate self-signed certificate request"
      openssl x509 -req -sha256 -days 3650 -in "${CONFIGDIR}/ssl/sickgear.csr" -signkey "${CONFIGDIR}/ssl/sickgear.key" -out "${CONFIGDIR}/ssl/sickgear.crt"
   fi

}

CreateGroup(){
   if [ -z "$(getent group "${GROUP}" | cut -d: -f3)" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Group ID available, creating group"
      addgroup -g "${GID}" "${GROUP}"
   elif [ ! "$(getent group "${GROUP}" | cut -d: -f3)" = "${GID}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') ERROR:   Group GID mismatch - exiting"
      exit 1
   fi
}

CreateUser(){
   if [ -z "$(getent passwd "${USER}" | cut -d: -f3)" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    User ID available, creating user"
      adduser -s /bin/ash -H -D -G "${GROUP}" -u "${UID}" "${USER}"
   elif [ ! "$(getent passwd "${USER}" | cut -d: -f3)" = "${UID}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') ERROR:   User ID already in use - exiting"
      exit 1
   fi
}

SetOwnerAndGroup(){
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Correct owner and group of application files, if required"
   find "${CONFIGDIR}" ! -user "${USER}" -exec chown "${USER}" {} \;
   find "${CONFIGDIR}" ! -group "${GROUP}" -exec chgrp "${GROUP}" {} \;
   find "${APPBASE}" ! -user "${USER}" -exec chown "${USER}" {} \;
   find "${APPBASE}" ! -group "${GROUP}" -exec chgrp "${GROUP}" {} \;
}

LaunchSickGear(){
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Starting SickGear as ${USER}"
   su -m "${USER}" -c 'python '"${APPBASE}/sickgear.py"' --config '"${CONFIGDIR}/config.ini"' --datadir '"${CONFIGDIR}"''
}

##### Script #####
Initialise
CreateGroup
CreateUser
SetOwnerAndGroup
LaunchSickGear
