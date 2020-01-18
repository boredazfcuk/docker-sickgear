#!/bin/ash
#
##### Functions #####
Initialise(){
   lan_ip="$(hostname -i)"
   echo -e "\n"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    ***** Starting SickGear/SickGear container *****"
   if [ -z "${stack_user}" ]; then echo "$(date '+%Y-%m-%d %H:%M:%S') WARNING: User name not set, defaulting to 'stackman'"; stack_user="stackman"; fi
   if [ -z "${stack_password}" ]; then echo "$(date '+%Y-%m-%d %H:%M:%S') WARNING: Password not set, defaulting to 'Skibidibbydibyodadubdub'"; stack_password="Skibidibbydibyodadubdub"; fi   
   if [ -z "${user_id}" ]; then echo "$(date '+%Y-%m-%d %H:%M:%S') WARNING: User ID not set, defaulting to '1000'"; user_id="1000"; fi
   if [ -z "${group}" ]; then echo "$(date '+%Y-%m-%d %H:%M:%S') WARNING: Group name not set, defaulting to 'group'"; group="group"; fi
   if [ -z "${group_id}" ]; then echo "$(date '+%Y-%m-%d %H:%M:%S') WARNING: Group ID not set, defaulting to '1000'"; group_id="1000"; fi
   if [ -z "${tv_dirs}" ]; then echo "$(date '+%Y-%m-%d %H:%M:%S') WARNING: TV paths not set, defaulting to '/storage/tvshows'"; fi
   if [ -z "${tv_complete_dir}" ]; then echo "$(date '+%Y-%m-%d %H:%M:%S') WARNING: Completed tv path not set, defaulting to '/storage/downloads/complete/tv/'"; tv_complete_dir="/storage/downloads/complete/tv/"; fi
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Local user: ${stack_user}:${user_id}"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Local group: ${group}:${group_id}"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    SickGear application directory: ${app_base_dir}"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    TV Show paths: ${tv_dirs}"
}

CreateGroup(){
   if [ -z "$(getent group "${group}" | cut -d: -f3)" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Group ID available, creating group"
      addgroup -g "${group_id}" "${group}"
   elif [ ! "$(getent group "${group}" | cut -d: -f3)" = "${group_id}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') ERROR:   Group group_id mismatch - exiting"
      exit 1
   fi
}

CreateUser(){
   if [ -z "$(getent passwd "${stack_user}" | cut -d: -f3)" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    User ID available, creating user"
      adduser -s /bin/ash -H -D -G "${group}" -u "${user_id}" "${stack_user}"
   elif [ ! "$(getent passwd "${stack_user}" | cut -d: -f3)" = "${user_id}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') ERROR:   User ID already in use - exiting"
      exit 1
   fi
}

FirstRun(){
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    First run detected. Initialisation required"
   find "${config_dir}" ! -user "${stack_user}" -exec chown "${stack_user}" {} \;
   find "${config_dir}" ! -group "${group}" -exec chgrp "${group}" {} \;
   su -m "${stack_user}" -c "/usr/bin/python ${app_base_dir}/sickgear.py --config ${config_dir}/sickgear.ini --datadir ${config_dir} --quiet --nolaunch --daemon --pidfile=/tmp/sickgear.pid"
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
      "${config_dir}/sickgear.ini"
   sleep 1
}

EnableSSL(){
   if [ ! -d "${config_dir}/https" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Configure SickGear to use HTTPS"
      mkdir -p "${config_dir}/https"
      openssl ecparam -genkey -name secp384r1 -out "${config_dir}/https/sickgear.key"
      openssl req -new -subj "/C=NA/ST=Global/L=Global/O=SickGear/OU=SickGear/CN=SickGear/" -key "${config_dir}/https/sickgear.key" -out "${config_dir}/https/sickgear.csr"
      openssl x509 -req -sha256 -days 3650 -in "${config_dir}/https/sickgear.csr" -signkey "${config_dir}/https/sickgear.key" -out "${config_dir}/https/sickgear.crt" >/dev/null 2>&1
      sed -i \
         -e "/^\[General\]/,/^\[.*\]/ s%https_key =.*%https_key = ${config_dir}/https/sickgear.key%" \
         -e "/^\[General\]/,/^\[.*\]/ s%https_cert =.*%https_cert = ${config_dir}/https/sickgear.crt%" \
         -e "/^\[General\]/,/^\[.*\]/ s%enable_https =.*%enable_https = 1%" \
         "${config_dir}/sickgear.ini"
   fi
}

Configure(){
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Disable browser launch on startup"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Configure host IP: ${lan_ip}"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Enable failed download handling"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Set TV Show library paths: ${tv_dirs}"
   sed -i \
      -e "/^\[General\]/,/^\[.*\]/ s%launch_browser =.*%launch_browser = 0%" \
      -e "/^\[General\]/,/^\[.*\]/ s%web_host =.*%web_host = ${lan_ip}%" \
      -e "/^\[General\]/,/^\[.*\]/ s%root_dirs =.*%root_dirs = 0|${tv_dirs//,/|}%" \
      -e "/^\[General\]/,/^\[.*\]/ s%tv_download_dir =.*%tv_download_dir = ${tv_complete_dir}%" \
      -e "/^\[General\]/,/^\[.*\]/ s%auto_update =.*%auto_update = 0%" \
      -e "/^\[General\]/,/^\[.*\]/ s%notify_on_update =.*%notify_on_update = 0%" \
      -e "/^\[General\]/,/^\[.*\]/ s%web_username = \".*\"%web_username = \"${stack_user}\"%" \
      -e "/^\[General\]/,/^\[.*\]/ s%web_password = \".*\"%web_password = \"${stack_password}\"%" \
      -e "/^\[General\]/,/^\[.*\]/ s%allowed_hosts = \".*\"%allowed_hosts = \"${HOSTNAME}\"%" \
      -e "/^\[General\]/,/^\[.*\]/ s%allow_anyip =.*%allow_anyip = 0%" \
      "${config_dir}/sickgear.ini"
   if [ ! -z "${media_access_domain}" ]; then
      sed -i \
         -e "/^\[General\]/,/^\[.*\]/ s%allowed_hosts = \".*\"%allowed_hosts = \"${HOSTNAME}, ${media_access_domain}\"%" \
         "${config_dir}/sickgear.ini"
   fi
   if [ ! -z "${global_api_key}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Enable API key usage"
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Set API key sabnzbd:::${global_api_key}"
      sed -i \
         -e "/^\[General\]/,/^\[.*\]/ s%use_api =.*%use_api = 1%" \
         -e "/^\[General\]/,/^\[.*\]/ s%api_keys =.*%api_keys = sabnzbd:::${global_api_key}%" \
         "${config_dir}/sickgear.ini"
   fi
   if [ ! -z "${sickgear_enabled}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Set web root for reverse proxying"
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Enable handling of reverse proxy headers"
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Enable handling of security headers"
      sed -i \
         -e "/^\[General\]/,/^\[.*\]/ s%web_root =.*%web_root = /sickgear%" \
         -e "/^\[General\]/,/^\[.*\]/ s%handle_reverse_proxy =.*%handle_reverse_proxy = 1%" \
         -e "/^\[General\]/,/^\[.*\]/ s%send_security_headers =.*%send_security_headers = 1%" \
         "${config_dir}/sickgear.ini"
   fi
   if [ ! -z "${kodi_headless_group_id}" ]; then
      if [ "$(grep -c use_kodi "${config_dir}/sickgear.ini")" = 0 ]; then
         echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Configuring kodi-headless"
         sed -i \
            -e "s%metadata_kodi =.*%metadata_kodi = 1|1|0|0|0|0|0|0|0|0%" \
            "${config_dir}/sickgear.ini"
         sed -i \
            -e "/^\[Kodi\]/a kodi_update_library = 1" \
            -e "/^\[Kodi\]/a kodi_update_full = 1" \
            -e "/^\[Kodi\]/a kodi_notify_ondownload = 1" \
            -e "/^\[Kodi\]/a kodi_host = kodi:8080" \
            -e "/^\[Kodi\]/a kodi_password = ${kodi_password}" \
            -e "/^\[Kodi\]/a kodi_username = kodi" \
            -e "/^\[Kodi\]/a use_kodi = 1" \
            "${config_dir}/sickgear.ini"
      else
         echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Configuring kodi-headless"
         sed -i \
            -e "/^\[Kodi\]/,/^\[.*\]/ s%kodi_host =.*%kodi_host = kodi:8080%" \
            -e "/^\[Kodi\]/,/^\[.*\]/ s%kodi_password =.*%kodi_password = ${kodi_password}%" \
            -e "/^\[Kodi\]/,/^\[.*\]/ s%kodi_username =.*%kodi_username = kodi%" \
            -e "/^\[Kodi\]/,/^\[.*\]/ s%use_kodi =.*%use_kodi = 1%" \
            -e "/^\[Kodi\]/,/^\[.*\]/ s%kodi_always_on =.*%kodi_always_on = 1%" \
            -e "/^\[Kodi\]/,/^\[.*\]/ s%kodi_notify_ondownload =.*%kodi_notify_ondownload = 1%" \
            -e "/^\[Kodi\]/,/^\[.*\]/ s%kodi_update_full =.*%kodi_update_full = 1%" \
            -e "/^\[Kodi\]/,/^\[.*\]/ s%kodi_update_library =.*%kodi_update_library = 1%" \
            "${config_dir}/sickgear.ini"
      fi
   fi
   if [ ! -z "${sabnzbd_enabled}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Enable SABnzbd"
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Setting SABnzbd host to https://sabnzbd:9090/"
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Setting SABnzbd category to: tv"
      sed -i \
         -e "/^\[General\]/,/^\[.*\]/ s%use_nzbs = 0%use_nzbs = 1%" \
         -e "/^\[General\]/,/^\[.*\]/ s%nzb_method =.*%nzb_method = sabnzbd%" \
         -e "/^\[General\]/,/^\[.*\]/ s%process_automatically =.*%process_automatically = 0%" \
         -e "/^\[SABnzbd\]/,/^\[.*\]/ s%sab_category =.*%sab_category = tv%" \
         "${config_dir}/sickgear.ini"
      if [ "$(grep -c sab_username "${config_dir}/sickgear.ini")" = 0 ]; then
         sed -i \
            -e "/^\[SABnzbd\]/a sab_username = ${stack_user}" \
            "${config_dir}/sickgear.ini"
      else
         sed -i \
            -e "/^\[SABnzbd\]/,/^\[.*\]/ s%sab_username =.*%sab_username = ${stack_user}%" \
            "${config_dir}/sickgear.ini"
      fi
      if [ "$(grep -c "sab_password" "${config_dir}/sickgear.ini")" = 0 ]; then
         sed -i \
            -e "/^\[SABnzbd\]/a sab_password = ${stack_password}" \
            "${config_dir}/sickgear.ini"
      else
         sed -i \
            -e "/^\[SABnzbd\]/,/^\[.*\]/ s%sab_password =.*%sab_password = ${stack_password}%" \
            "${config_dir}/sickgear.ini"
      fi
      if [ "$(grep -c sab_host "${config_dir}/sickgear.ini")" = 0 ]; then
         sed -i \
            -e "/^\[SABnzbd\]/a sab_host = https://sabnzbd:9090/" \
            "${config_dir}/sickgear.ini"
      else
         sed -i \
            -e "/^\[SABnzbd\]/,/^\[.*\]/ s%sab_host =.*%sab_host = https://sabnzbd:9090/%" \
            "${config_dir}/sickgear.ini"
      fi
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Setting SABnzbd API Key"
      if [ "$(grep -c sab_apikey "${config_dir}/sickgear.ini")" = 0 ]; then
         sed -i \
            -e "/^\[SABnzbd\]/a sab_apikey = ${global_api_key}" \
            "${config_dir}/sickgear.ini"
      else
         sed -i \
            -e "/^\[SABnzbd\]/,/^\[.*\]/ s%sab_apikey =.*%sab_apikey = ${global_api_key}%" \
            "${config_dir}/sickgear.ini"
      fi
   fi
   if [ ! -z "${deluge_enabled}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Config Deluge MORE ECHO EXPLANATIONS NEEDED***************************************"
      sed -i \
         -e "/^\[General\]/,/^\[.*\]/ s%use_torrents =.*%use_torrents = 1%" \
         -e "/^\[General\]/,/^\[.*\]/ s%torrent_method =.*%torrent_method = deluge%" \
         "${config_dir}/sickgear.ini"
      if [ "$(grep -c "\[TORRENT\]" "${config_dir}/sickgear.ini")" = 0 ]; then
         echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Configuring Deluge"
         echo "[TORRENT]" >> "${config_dir}/sickgear.ini"
         sed -i \
            -e "/^\[TORRENT\]/a torrent_password = ${stack_password}" \
            -e "/^\[TORRENT\]/a torrent_host = https://deluge:8112/" \
            -e "/^\[TORRENT\]/a torrent_path = ${tv_complete_dir}" \
            -e "/^\[TORRENT\]/a torrent_label = tv" \
            "${config_dir}/sickgear.ini"
      else
         sed -i \
            -e "/^\[TORRENT\]/,/^\[.*\]/ s%torrent_password =.*%torrent_password = ${stack_password}%" \
            -e "/^\[TORRENT\]/,/^\[.*\]/ s%torrent_host =.*%torrent_host = https://deluge:8112/%" \
            -e "/^\[TORRENT\]/,/^\[.*\]/ s%torrent_path = ${tv_complete_dir}.*%torrent_path = ${tv_complete_dir}%" \
            -e "/^\[TORRENT\]/,/^\[.*\]/ s%torrent_label =.*%torrent_label = tv%" \
            "${config_dir}/sickgear.ini"
      fi
   fi
   if [ ! -z "${prowl_api_key}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Configuring Prowl notifications"
      sed -i \
         -e "/^\[Prowl\]/,/^\[.*\]/ s%^use_prowl =.*%use_prowl = 1%" \
         -e "/^\[Prowl\]/,/^\[.*\]/ s%^prowl_api =.*%prowl_api = ${prowl_api_key}%" \
         -e "/^\[Prowl\]/,/^\[.*\]/ s%^prowl_notify_onsnatch =.*%prowl_notify_onsnatch = 1%" \
         -e "/^\[Prowl\]/,/^\[.*\]/ s%^prowl_notify_ondownload =.*%prowl_notify_ondownload = 1%" \
         "${config_dir}/sickgear.ini"
   else
      sed -i \
         -e "/^\[Prowl\]/,/^\[.*\]/ s%^use_prowl =.*%use_prowl = 0%" \
         "${config_dir}/sickgear.ini"
   fi
   if [ ! -z "${OMGWTFNZBS}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Configuring OMGWTFNZBs search provider"
      sed -i \
         -e "/^\[OMGWTFNZBS\]/,/^\[.*\]/ s%^omgwtfnzbs_username =.*%omgwtfnzbs_username = ${omgwtfnzbs_user}%" \
         -e "/^\[OMGWTFNZBS\]/,/^\[.*\]/ s%^omgwtfnzbs_api_key =.*%omgwtfnzbs_api_key = ${omgwtfnzbs_api_key}%" \
         "${config_dir}/sickgear.ini"
   else
      sed -i \
         -e "/^\[OMGWTFNZBS\]/,/^\[.*\]/ s%^omgwtfnzbs_username =.*%omgwtfnzbs_username = \"\"%" \
         -e "/^\[OMGWTFNZBS\]/,/^\[.*\]/ s%^omgwtfnzbs_api_key =.*%omgwtfnzbs_api_key = \"\"%" \
         "${config_dir}/sickgear.ini"
   fi
}

SetOwnerAndGroup(){
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Correct owner and group of application files, if required"
   find "${config_dir}" ! -user "${stack_user}" -exec chown "${stack_user}" {} \;
   find "${config_dir}" ! -group "${group}" -exec chgrp "${group}" {} \;
   find "${app_base_dir}" ! -user "${stack_user}" -exec chown "${stack_user}" {} \;
   find "${app_base_dir}" ! -group "${group}" -exec chgrp "${group}" {} \;
}

LaunchSickGear(){
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Starting SickGear as ${stack_user}"
   su -m "${stack_user}" -c "/usr/bin/python ${app_base_dir}/sickgear.py --config ${config_dir}/sickgear.ini --datadir ${config_dir}"
}

##### Script #####
Initialise
CreateGroup
CreateUser
if [ ! -f "${config_dir}/sickgear.ini" ]; then FirstRun; fi
if [ ! -d "${config_dir}/https" ]; then EnableSSL; fi
Configure
SetOwnerAndGroup
LaunchSickGear
