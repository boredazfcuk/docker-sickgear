#!/bin/ash

##### Functions #####
Initialise(){
   LANIP="$(hostname -i)"
   echo -e "\n"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    ***** Starting SickGear/SickGear container *****"
   if [ -z "${STACKUSER}" ]; then echo "$(date '+%Y-%m-%d %H:%M:%S') WARNING: User name not set, defaulting to 'stackman'"; STACKUSER="stackman"; fi
   if [ -z "${STACKPASSWORD}" ]; then echo "$(date '+%Y-%m-%d %H:%M:%S') WARNING: Password not set, defaulting to 'Skibidibbydibyodadubdub'"; STACKPASSWORD="Skibidibbydibyodadubdub"; fi   
   if [ -z "${UID}" ]; then echo "$(date '+%Y-%m-%d %H:%M:%S') WARNING: User ID not set, defaulting to '1000'"; UID="1000"; fi
   if [ -z "${GROUP}" ]; then echo "$(date '+%Y-%m-%d %H:%M:%S') WARNING: Group name not set, defaulting to 'group'"; GROUP="group"; fi
   if [ -z "${GID}" ]; then echo "$(date '+%Y-%m-%d %H:%M:%S') WARNING: Group ID not set, defaulting to '1000'"; GID="1000"; fi
   if [ -z "${TVDIRS}" ]; then echo "$(date '+%Y-%m-%d %H:%M:%S') WARNING: TV paths not set, defaulting to '/storage/tvshows'"; fi
   if [ -z "${TVCOMPLETEDIR}" ]; then echo "$(date '+%Y-%m-%d %H:%M:%S') WARNING: Completed tv path not set, defaulting to '/storage/downloads/complete/tv/'"; TVCOMPLETEDIR="/storage/downloads/complete/tv/"; fi
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Local user: ${STACKUSER}:${UID}"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Local group: ${GROUP}:${GID}"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    SickGear application directory: ${APPBASE}"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    TV Show paths: ${TVDIRS}"
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
   if [ -z "$(getent passwd "${STACKUSER}" | cut -d: -f3)" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    User ID available, creating user"
      adduser -s /bin/ash -H -D -G "${GROUP}" -u "${UID}" "${STACKUSER}"
   elif [ ! "$(getent passwd "${STACKUSER}" | cut -d: -f3)" = "${UID}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') ERROR:   User ID already in use - exiting"
      exit 1
   fi
}

FirstRun(){
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    First run detected. Initialisation required"
   find "${CONFIGDIR}" ! -user "${STACKUSER}" -exec chown "${STACKUSER}" {} \;
   find "${CONFIGDIR}" ! -group "${GROUP}" -exec chgrp "${GROUP}" {} \;
   su -m "${STACKUSER}" -c "/usr/bin/python ${APPBASE}/sickgear.py --config ${CONFIGDIR}/sickgear.ini --datadir ${CONFIGDIR} --quiet --nolaunch --daemon --pidfile=/tmp/sickgear.pid"
   sleep 15
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Default configuration created - restarting"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    ***** Reload SickGear/SickGear *****"
   pkill python
   sleep 5
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Set git path: /usr/bin/git"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Configure update interval to 48hr"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Enable notifications for available updates"
   sed -i \
      -e "/^\[General\]/,/^\[.*\]/ s%git_path =.*%git_path = /usr/bin/git%" \
      -e "/^\[General\]/,/^\[.*\]/ s%update_frequency =.*%update_frequency = 48%" \
      -e "/^\[General\]/,/^\[.*\]/ s%version_notify =.*%version_notify = 1%" \
      -e "/^\[General\]/,/^\[.*\]/ s%update_shows_on_start =.*%update_shows_on_start = 1%" \
      -e "/^\[General\]/,/^\[.*\]/ s%keep_processed_dir =.*%keep_processed_dir = 0%" \
      -e "/^\[General\]/,/^\[.*\]/ s%unpack =.*%unpack = 1%" \
      -e "/^\[GUI\]/,/^\[.*\]/ s%default_home =.*%default_home = shows%" \
      -e "/^\[FailedDownloads\]/,/^\[.*\]/ s%use_failed_downloads = 0%use_failed_downloads = 1%" \
      -e "/^\[FailedDownloads\]/,/^\[.*\]/ s%delete_failed = 0%delete_failed = 1%" \
      "${CONFIGDIR}/sickgear.ini"
   sleep 1
}

EnableSSL(){
   if [ ! -d "${CONFIGDIR}/https" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Configure SickGear to use HTTPS"
      mkdir -p "${CONFIGDIR}/https"
      openssl ecparam -genkey -name secp384r1 -out "${CONFIGDIR}/https/sickgear.key"
      openssl req -new -subj "/C=NA/ST=Global/L=Global/O=SickGear/OU=SickGear/CN=SickGear/" -key "${CONFIGDIR}/https/sickgear.key" -out "${CONFIGDIR}/https/sickgear.csr"
      openssl x509 -req -sha256 -days 3650 -in "${CONFIGDIR}/https/sickgear.csr" -signkey "${CONFIGDIR}/https/sickgear.key" -out "${CONFIGDIR}/https/sickgear.crt" >/dev/null 2>&1
      sed -i \
         -e "/^\[General\]/,/^\[.*\]/ s%https_key =.*%https_key = ${CONFIGDIR}/https/sickgear.key%" \
         -e "/^\[General\]/,/^\[.*\]/ s%https_cert =.*%https_cert = ${CONFIGDIR}/https/sickgear.crt%" \
         -e "/^\[General\]/,/^\[.*\]/ s%enable_https =.*%enable_https = 1%" \
         "${CONFIGDIR}/sickgear.ini"
   fi
}

Configure(){
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Disable browser launch on startup"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Configure host IP: ${LANIP}"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Enable failed download handling"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Set TV Show library paths: ${TVDIRS}"
   sed -i \
      -e "/^\[General\]/,/^\[.*\]/ s%launch_browser =.*%launch_browser = 0%" \
      -e "/^\[General\]/,/^\[.*\]/ s%web_host =.*%web_host = ${LANIP}%" \
      -e "/^\[General\]/,/^\[.*\]/ s%root_dirs =.*%root_dirs = 0|${TVDIRS//,/|}%" \
      -e "/^\[General\]/,/^\[.*\]/ s%tv_download_dir =.*%tv_download_dir = ${TVCOMPLETEDIR}%" \
      -e "/^\[General\]/,/^\[.*\]/ s%auto_update =.*%auto_update = 0%" \
      -e "/^\[General\]/,/^\[.*\]/ s%notify_on_update =.*%notify_on_update = 0%" \
      -e "/^\[General\]/,/^\[.*\]/ s%web_username = \".*\"%web_username = \"${STACKUSER}\"%" \
      -e "/^\[General\]/,/^\[.*\]/ s%web_password = \".*\"%web_password = \"${STACKPASSWORD}\"%" \
      -e "/^\[General\]/,/^\[.*\]/ s%allowed_hosts = \".*\"%allowed_hosts = \"${HOSTNAME}\"%" \
      -e "/^\[General\]/,/^\[.*\]/ s%allow_anyip =.*%allow_anyip = 0%" \
      "${CONFIGDIR}/sickgear.ini"
   if [ ! -z "${MEDIAACCESSDOMAIN}" ]; then
      sed -i \
         -e "/^\[General\]/,/^\[.*\]/ s%allowed_hosts = \".*\"%allowed_hosts = \"${HOSTNAME}, ${MEDIAACCESSDOMAIN}\"%" \
         "${CONFIGDIR}/sickgear.ini"
   fi
   if [ ! -z "${GLOBALAPIKEY}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Enable API key usage"
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Set API key sabnzbd:::${GLOBALAPIKEY}"
      sed -i \
         -e "/^\[General\]/,/^\[.*\]/ s%use_api =.*%use_api = 1%" \
         -e "/^\[General\]/,/^\[.*\]/ s%api_keys =.*%api_keys = sabnzbd:::${GLOBALAPIKEY}%" \
         "${CONFIGDIR}/sickgear.ini"
   fi
   if [ ! -z "${SICKGEARENABLED}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Set web root for reverse proxying"
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Enable handling of reverse proxy headers"
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Enable handling of security headers"
      sed -i \
         -e "/^\[General\]/,/^\[.*\]/ s%web_root =.*%web_root = /sickgear%" \
         -e "/^\[General\]/,/^\[.*\]/ s%handle_reverse_proxy =.*%handle_reverse_proxy = 1%" \
         -e "/^\[General\]/,/^\[.*\]/ s%send_security_headers =.*%send_security_headers = 1%" \
         "${CONFIGDIR}/sickgear.ini"
   fi
   if [ ! -z "${KODIHEADLESS}" ]; then
      if [ "$(grep -c use_kodi "${CONFIGDIR}/sickgear.ini")" = 0 ]; then
         echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Configuring kodi-headless"
         sed -i \
            -e "s%metadata_kodi =.*%metadata_kodi = 1|1|0|0|0|0|0|0|0|0%" \
            "${CONFIGDIR}/sickgear.ini"
         sed -i \
            -e "/^\[Kodi\]/a kodi_update_library = 1" \
            -e "/^\[Kodi\]/a kodi_update_full = 1" \
            -e "/^\[Kodi\]/a kodi_notify_ondownload = 1" \
            -e "/^\[Kodi\]/a kodi_host = kodi:8080" \
            -e "/^\[Kodi\]/a kodi_password = ${KODIPASSWORD}" \
            -e "/^\[Kodi\]/a kodi_username = kodi" \
            -e "/^\[Kodi\]/a use_kodi = 1" \
            "${CONFIGDIR}/sickgear.ini"
      else
         echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Configuring kodi-headless"
         sed -i \
            -e "/^\[Kodi\]/,/^\[.*\]/ s%kodi_host =.*%kodi_host = kodi:8080%" \
            -e "/^\[Kodi\]/,/^\[.*\]/ s%kodi_password =.*%kodi_password = ${KODIPASSWORD}%" \
            -e "/^\[Kodi\]/,/^\[.*\]/ s%kodi_username =.*%kodi_username = kodi%" \
            -e "/^\[Kodi\]/,/^\[.*\]/ s%use_kodi =.*%use_kodi = 1%" \
            -e "/^\[Kodi\]/,/^\[.*\]/ s%kodi_always_on =.*%kodi_always_on = 1%" \
            -e "/^\[Kodi\]/,/^\[.*\]/ s%kodi_notify_ondownload =.*%kodi_notify_ondownload = 1%" \
            -e "/^\[Kodi\]/,/^\[.*\]/ s%kodi_update_full =.*%kodi_update_full = 1%" \
            -e "/^\[Kodi\]/,/^\[.*\]/ s%kodi_update_library =.*%kodi_update_library = 1%" \
            "${CONFIGDIR}/sickgear.ini"
      fi
   fi
   if [ ! -z "${SABNZBDENABLED}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Enable SABnzbd"
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Setting SABnzbd host to https://sabnzbd:9090/"
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Setting SABnzbd category to: tv"
      sed -i \
         -e "/^\[General\]/,/^\[.*\]/ s%use_nzbs = 0%use_nzbs = 1%" \
         -e "/^\[General\]/,/^\[.*\]/ s%nzb_method =.*%nzb_method = sabnzbd%" \
         -e "/^\[General\]/,/^\[.*\]/ s%process_automatically =.*%process_automatically = 0%" \
         -e "/^\[SABnzbd\]/,/^\[.*\]/ s%sab_category =.*%sab_category = tv%" \
         "${CONFIGDIR}/sickgear.ini"
      if [ "$(grep -c sab_username "${CONFIGDIR}/sickgear.ini")" = 0 ]; then
         sed -i \
            -e "/^\[SABnzbd\]/a sab_username = ${STACKUSER}" \
            "${CONFIGDIR}/sickgear.ini"
      else
         sed -i \
            -e "/^\[SABnzbd\]/,/^\[.*\]/ s%sab_username =.*%sab_username = ${STACKUSER}%" \
            "${CONFIGDIR}/sickgear.ini"
      fi
      if [ "$(grep -c "sab_password" "${CONFIGDIR}/sickgear.ini")" = 0 ]; then
         sed -i \
            -e "/^\[SABnzbd\]/a sab_password = ${STACKPASSWORD}" \
            "${CONFIGDIR}/sickgear.ini"
      else
         sed -i \
            -e "/^\[SABnzbd\]/,/^\[.*\]/ s%sab_password =.*%sab_password = ${STACKPASSWORD}%" \
            "${CONFIGDIR}/sickgear.ini"
      fi
      if [ "$(grep -c sab_host "${CONFIGDIR}/sickgear.ini")" = 0 ]; then
         sed -i \
            -e "/^\[SABnzbd\]/a sab_host = https://sabnzbd:9090/" \
            "${CONFIGDIR}/sickgear.ini"
      else
         sed -i \
            -e "/^\[SABnzbd\]/,/^\[.*\]/ s%sab_host =.*%sab_host = https://sabnzbd:9090/%" \
            "${CONFIGDIR}/sickgear.ini"
      fi
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Setting SABnzbd API Key"
      if [ "$(grep -c sab_apikey "${CONFIGDIR}/sickgear.ini")" = 0 ]; then
         sed -i \
            -e "/^\[SABnzbd\]/a sab_apikey = ${GLOBALAPIKEY}" \
            "${CONFIGDIR}/sickgear.ini"
      else
         sed -i \
            -e "/^\[SABnzbd\]/,/^\[.*\]/ s%sab_apikey =.*%sab_apikey = ${GLOBALAPIKEY}%" \
            "${CONFIGDIR}/sickgear.ini"
      fi
   fi
   if [ ! -z "${DELUGEENABLED}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Config Deluge MORE ECHO EXPLANATIONS NEEDED***************************************"
      sed -i \
         -e "/^\[General\]/,/^\[.*\]/ s%use_torrents =.*%use_torrents = 1%" \
         -e "/^\[General\]/,/^\[.*\]/ s%torrent_method =.*%torrent_method = deluge%" \
         "${CONFIGDIR}/sickgear.ini"
      if [ "$(grep -c "\[TORRENT\]" "${CONFIGDIR}/sickgear.ini")" = 0 ]; then
         echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Configuring Deluge"
         echo "[TORRENT]" >> "${CONFIGDIR}/sickgear.ini"
         sed -i \
            -e "/^\[TORRENT\]/a torrent_password = ${STACKPASSWORD}" \
            -e "/^\[TORRENT\]/a torrent_host = https://deluge:8112/" \
            -e "/^\[TORRENT\]/a torrent_path = ${TVCOMPLETEDIR}" \
            -e "/^\[TORRENT\]/a torrent_label = tv" \
            "${CONFIGDIR}/sickgear.ini"
      else
         sed -i \
            -e "/^\[TORRENT\]/,/^\[.*\]/ s%torrent_password =.*%torrent_password = ${STACKPASSWORD}%" \
            -e "/^\[TORRENT\]/,/^\[.*\]/ s%torrent_host =.*%torrent_host = https://deluge:8112/%" \
            -e "/^\[TORRENT\]/,/^\[.*\]/ s%torrent_path = ${TVCOMPLETEDIR}.*%torrent_path = ${TVCOMPLETEDIR}%" \
            -e "/^\[TORRENT\]/,/^\[.*\]/ s%torrent_label =.*%torrent_label = tv%" \
            "${CONFIGDIR}/sickgear.ini"
      fi
   fi
   if [ ! -z "${PROWLAPI}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Configuring Prowl notifications"
      sed -i \
         -e "/^\[Prowl\]/,/^\[.*\]/ s%^use_prowl =.*%use_prowl = 1%" \
         -e "/^\[Prowl\]/,/^\[.*\]/ s%^prowl_api =.*%prowl_api = ${PROWLAPI}%" \
         -e "/^\[Prowl\]/,/^\[.*\]/ s%^prowl_notify_onsnatch =.*%prowl_notify_onsnatch = 1%" \
         -e "/^\[Prowl\]/,/^\[.*\]/ s%^prowl_notify_ondownload =.*%prowl_notify_ondownload = 1%" \
         "${CONFIGDIR}/sickgear.ini"
   else
      sed -i \
         -e "/^\[Prowl\]/,/^\[.*\]/ s%^use_prowl =.*%use_prowl = 0%" \
         "${CONFIGDIR}/sickgear.ini"
   fi
   if [ ! -z "${OMGWTFNZBS}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Configuring OMGWTFNZBs search provider"
      sed -i \
         -e "/^\[OMGWTFNZBS\]/,/^\[.*\]/ s%^omgwtfnzbs_username =.*%omgwtfnzbs_username = ${OMGWTFNZBS}%" \
         -e "/^\[OMGWTFNZBS\]/,/^\[.*\]/ s%^omgwtfnzbs_api_key =.*%omgwtfnzbs_api_key = ${OMGWTFNZBSAPI}%" \
         "${CONFIGDIR}/sickgear.ini"
   else
      sed -i \
         -e "/^\[OMGWTFNZBS\]/,/^\[.*\]/ s%^omgwtfnzbs_username =.*%omgwtfnzbs_username = \"\"%" \
         -e "/^\[OMGWTFNZBS\]/,/^\[.*\]/ s%^omgwtfnzbs_api_key =.*%omgwtfnzbs_api_key = \"\"%" \
         "${CONFIGDIR}/sickgear.ini"
   fi
}

SetOwnerAndGroup(){
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Correct owner and group of application files, if required"
   find "${CONFIGDIR}" ! -user "${STACKUSER}" -exec chown "${STACKUSER}" {} \;
   find "${CONFIGDIR}" ! -group "${GROUP}" -exec chgrp "${GROUP}" {} \;
   find "${APPBASE}" ! -user "${STACKUSER}" -exec chown "${STACKUSER}" {} \;
   find "${APPBASE}" ! -group "${GROUP}" -exec chgrp "${GROUP}" {} \;
}

LaunchSickGear(){
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Starting SickGear as ${STACKUSER}"
   su -m "${STACKUSER}" -c "/usr/bin/python ${APPBASE}/sickgear.py --config ${CONFIGDIR}/sickgear.ini --datadir ${CONFIGDIR}"
}

##### Script #####
Initialise
CreateGroup
CreateUser
if [ ! -f "${CONFIGDIR}/sickgear.ini" ]; then FirstRun; fi
if [ ! -d "${CONFIGDIR}/https" ]; then EnableSSL; fi
Configure
SetOwnerAndGroup
LaunchSickGear
