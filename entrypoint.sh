#!/bin/ash

##### Functions #####
Initialise(){
   lan_ip="$(hostname -i)"
   echo -e "\n"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    ***** Configuring SickGear container launch environment *****"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Local user: ${stack_user:=stackman}:${user_id:=1000}"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Local group: ${sickgear_group:=sickgear}:${sickgear_group_id:=1000}"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Password: ${stack_password:=Skibidibbydibyodadubdub}"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    SickGear application directory: ${app_base_dir:=/SickGear}"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    SickGear configuration directory: ${config_dir:=/config}"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Listening IP Address: ${lan_ip}"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    TV Show location(s): ${tv_dirs:=/storage/tvshows/}"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Download directory: ${tv_complete_dir:=/storage/downloads/complete/tv/}"
}

CreateGroup(){
   if [ -z "$(getent group "${sickgear_group}" | cut -d: -f3)" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Group ID available, creating group"
      addgroup -g "${sickgear_group_id}" "${sickgear_group}"
   elif [ ! "$(getent group "${sickgear_group}" | cut -d: -f3)" = "${sickgear_group_id}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') ERROR:   Group SickGear group id mismatch - exiting"
      exit 1
   fi
}

CreateUser(){
   if [ -z "$(getent passwd "${stack_user}" | cut -d: -f3)" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    User ID available, creating user"
      adduser -s /bin/ash -H -D -G "${sickgear_group}" -u "${user_id}" "${stack_user}"
   elif [ ! "$(getent passwd "${stack_user}" | cut -d: -f3)" = "${user_id}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') ERROR:   User ID already in use - exiting"
      exit 1
   fi
}

FirstRun(){
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    First run detected. Initialisation required"
   find "${config_dir}" ! -user "${stack_user}" -exec chown "${stack_user}" {} \;
   find "${config_dir}" ! -group "${sickgear_group}" -exec chgrp "${sickgear_group}" {} \;
   su -p "${stack_user}" -c "/usr/bin/python ${app_base_dir}/sickgear.py --config ${config_dir}/sickgear.ini --datadir ${config_dir} --quiet --nolaunch --daemon --pidfile=/tmp/sickgear.pid"
   sleep 15
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Default configuration created - restarting"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    ***** Reload SickGear launch environment *****"
   pkill python
   sleep 5
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Configure update interval to 48hr"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Enable notifications for available updates"
   sed -i \
      -e "/^\[General\]/,/^\[.*\]/ s%update_frequency =.*%update_frequency = 48%" \
      -e "/^\[General\]/,/^\[.*\]/ s%version_notify =.*%version_notify = 1%" \
      -e "/^\[General\]/,/^\[.*\]/ s%update_shows_on_start =.*%update_shows_on_start = 1%" \
      -e "/^\[General\]/,/^\[.*\]/ s%keep_processed_dir =.*%keep_processed_dir = 0%" \
      -e "/^\[General\]/,/^\[.*\]/ s%unpack =.*%unpack = 1%" \
      -e "/^\[GUI\]/,/^\[.*\]/ s%default_home =.*%default_home = shows%" \
      -e "/^\[GUI\]/,/^\[.*\]/ s%home_layout =.*%home_layout = small%" \
      -e "/^\[FailedDownloads\]/,/^\[.*\]/ s%use_failed_downloads = 0%use_failed_downloads = 1%" \
      -e "/^\[FailedDownloads\]/,/^\[.*\]/ s%delete_failed = 0%delete_failed = 1%" \
      "${config_dir}/sickgear.ini"
   sleep 1
}

EnableSSL(){
   if [ ! -d "${config_dir}/https" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Initialise HTTPS"
      mkdir -p "${config_dir}/https"
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Generate server key"
      openssl ecparam -genkey -name secp384r1 -out "${config_dir}/https/sickgear.key"
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Generate certificate request"
      openssl req -new -subj "/C=NA/ST=Global/L=Global/O=SickGear/OU=SickGear/CN=SickGear/" -key "${config_dir}/https/sickgear.key" -out "${config_dir}/https/sickgear.csr"
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Generate certificate"
      openssl x509 -req -sha256 -days 3650 -in "${config_dir}/https/sickgear.csr" -signkey "${config_dir}/https/sickgear.key" -out "${config_dir}/https/sickgear.crt" >/dev/null 2>&1
   fi
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Configure SickGear to use HTTPS"
   if [ -f "${config_dir}/https/sickgear.key" ] && [ -f "${config_dir}/https/sickgear.crt" ]; then
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
      -e "/^\[General\]/,/^\[.*\]/ s%allowed_hosts = \".*\"%allowed_hosts = \"$(hostname),sickgear)\"%" \
      -e "/^\[General\]/,/^\[.*\]/ s%allow_anyip =.*%allow_anyip = 0%" \
      -e "/^\[General\]/,/^\[.*\]/ s%provider_order = \"\"%provider_order = drunkenslug ninjacentral nzbgeek omgwtfnzbs sick_beard_index alpharatio bb bithdtv blutopia btn digitalhive ettv eztv fano filelist funfile grabtheinfo hdbits hdme hdspace hdtorrents immortalseed iptorrents limetorrents magnetdl milkie morethan ncore nebulance pisexy pretome privatehd ptfiles rarbg revtt scenehd scenetime shazbat showrss skytorrents snowfl speedcd the_pirate_bay torlock torrentday torrenting torrentleech tvchaosuk xspeeds zooqle horriblesubs nyaa tokyotoshokan%" \
      "${config_dir}/sickgear.ini"
   if [ "${media_access_domain}" ]; then
      sed -i \
         -e "/^\[General\]/,/^\[.*\]/ s%allowed_hosts = \".*\"%allowed_hosts = \"$(hostname),sickgear,${media_access_domain}\"%" \
         "${config_dir}/sickgear.ini"
   fi
   if [ "${global_api_key}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Enable API key usage"
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Set API key sabnzbd:::${global_api_key}"
      sed -i \
         -e "/^\[General\]/,/^\[.*\]/ s%use_api =.*%use_api = 1%" \
         -e "/^\[General\]/,/^\[.*\]/ s%api_keys =.*%api_keys = sabnzbd:::${global_api_key}%" \
         "${config_dir}/sickgear.ini"
   fi
   if [ "${sickgear_enabled}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Set web root for reverse proxying to /sickgear"
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Enable handling of reverse proxy headers"
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Enable handling of security headers"
      sed -i \
         -e "/^\[General\]/,/^\[.*\]/ s%web_root =.*%web_root = /sickgear%" \
         -e "/^\[General\]/,/^\[.*\]/ s%handle_reverse_proxy =.*%handle_reverse_proxy = 1%" \
         -e "/^\[General\]/,/^\[.*\]/ s%send_security_headers =.*%send_security_headers = 1%" \
         "${config_dir}/sickgear.ini"
   fi
}

Kodi(){
   if [ "${kodi_enabled}" ]; then
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
}

SABnzbd(){
   if [ "${sabnzbd_enabled}" ]; then
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
}

Deluge(){
   if [ "${deluge_enabled}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Enable Deluge for Torrents"
      sed -i \
         -e "/^\[General\]/,/^\[.*\]/ s%use_torrents =.*%use_torrents = 1%" \
         -e "/^\[General\]/,/^\[.*\]/ s%torrent_method =.*%torrent_method = deluge%" \
         "${config_dir}/sickgear.ini"
      if [ "$(grep -c "\[TORRENT\]" "${config_dir}/sickgear.ini")" = 0 ]; then
         echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Add Deluge host configuration"
         echo "[TORRENT]" >> "${config_dir}/sickgear.ini"
         sed -i \
            -e "/^\[TORRENT\]/a torrent_password = ${stack_password}" \
            -e "/^\[TORRENT\]/a torrent_host = https://deluge:8112/" \
            -e "/^\[TORRENT\]/a torrent_path = ${tv_complete_dir}" \
            -e "/^\[TORRENT\]/a torrent_label = tv" \
            "${config_dir}/sickgear.ini"
      else
         echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Configure Deluge host"
         sed -i \
            -e "/^\[TORRENT\]/,/^\[.*\]/ s%torrent_password =.*%torrent_password = ${stack_password}%" \
            -e "/^\[TORRENT\]/,/^\[.*\]/ s%torrent_host =.*%torrent_host = https://deluge:8112/%" \
            -e "/^\[TORRENT\]/,/^\[.*\]/ s%torrent_path =.*%torrent_path = ${tv_complete_dir}%" \
            -e "/^\[TORRENT\]/,/^\[.*\]/ s%torrent_label =.*%torrent_label = tv%" \
            "${config_dir}/sickgear.ini"
      fi
   fi
}

Prow(){
   if [ "${prowl_api_key}" ]; then
      if [ "$(grep -c "\[Prowl\]" "${config_dir}/sickgear.ini")" = 0 ]; then
         echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Add Prowl notification configuration"
         echo "[Prowl]" >> "${config_dir}/sickgear.ini"
         sed -i \
            -e "/^\[Prowl\]/a prowl_notify_ondownload = 1"\
            -e "/^\[Prowl\]/a prowl_api = ${prowl_api_key}" \
            -e "/^\[Prowl\]/a use_prowl = 1" \
            "${config_dir}/sickgear.ini"
      fi
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Configure Prowl notifications"
      sed -i \
         -e "/^\[Prowl\]/,/^\[.*\]/ s%^use_prowl =.*%use_prowl = 1%" \
         -e "/^\[Prowl\]/,/^\[.*\]/ s%^prowl_api =.*%prowl_api = ${prowl_api_key}%" \
         "${config_dir}/sickgear.ini"
   else
      sed -i \
         -e "/^\[Prowl\]/,/^\[.*\]/ s%^use_prowl =.*%use_prowl = 0%" \
         "${config_dir}/sickgear.ini"
   fi
}

OMGWTFNZBs(){
   if [ "${omgwtfnzbs_api_key}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Configuring OMGWTFNZBs search provider"
      sed -i \
         -e "/^\[OMGWTFNZBS\]/,/^\[.*\]/ s%^omgwtfnzbs =.*%omgwtfnzbs = 1%" \
         -e "/^\[OMGWTFNZBS\]/,/^\[.*\]/ s%^omgwtfnzbs_username =.*%omgwtfnzbs_username = ${omgwtfnzbs_user}%" \
         -e "/^\[OMGWTFNZBS\]/,/^\[.*\]/ s%^omgwtfnzbs_api_key =.*%omgwtfnzbs_api_key = ${omgwtfnzbs_api_key}%" \
         "${config_dir}/sickgear.ini"
   else
      sed -i \
         -e "/^\[OMGWTFNZBS\]/,/^\[.*\]/ s%^omgwtfnzbs =.*%omgwtfnzbs = 0%" \
         -e "/^\[OMGWTFNZBS\]/,/^\[.*\]/ s%^omgwtfnzbs_username =.*%omgwtfnzbs_username = \"\"%" \
         -e "/^\[OMGWTFNZBS\]/,/^\[.*\]/ s%^omgwtfnzbs_api_key =.*%omgwtfnzbs_api_key = \"\"%" \
         "${config_dir}/sickgear.ini"
   fi
}

Indexers(){
   if [ "$(grep -c "\[MAGNETDL\]" "${config_dir}/sickgear.ini")" = 0 ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Enable MagnetDL provider"
      echo "[MAGNETDL]" >> "${config_dir}/sickgear.ini"
      sed -i \
         -e "/^\[MAGNETDL\]/a magnetdl = 1" \
         "${config_dir}/sickgear.ini"
   fi
   if [ "$(grep -c "\[ETTV\]" "${config_dir}/sickgear.ini")" = 0 ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Enable ETTV provider"
      echo "[ETTV]" >> "${config_dir}/sickgear.ini"
      sed -i \
         -e "/^\[ETTV\]/a ettv = 1" \
         "${config_dir}/sickgear.ini"
   fi
   if [ "$(grep -c "\[EZTV\]" "${config_dir}/sickgear.ini")" = 0 ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Enable EZTV provider"
      echo "[EZTV]" >> "${config_dir}/sickgear.ini"
      sed -i \
         -e "/^\[EZTV\]/a eztv = 1" \
         "${config_dir}/sickgear.ini"
   fi
   if [ "$(grep -c "\[SKYTORRENTS\]" "${config_dir}/sickgear.ini")" = 0 ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Enable Sky Torrents provider"
      echo "[SKYTORRENTS]" >> "${config_dir}/sickgear.ini"
      sed -i \
         -e "/^\[SKYTORRENTS\]/a skytorrents = 1" \
         "${config_dir}/sickgear.ini"
   fi
   if [ "$(grep -c "\[SICK_BEARD_INDEX\]" "${config_dir}/sickgear.ini")" = 0 ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Enable SickBeard index provider"
      echo "[SICK_BEARD_INDEX]" >> "${config_dir}/sickgear.ini"
      sed -i \
         -e "/^\[SICK_BEARD_INDEX\]/a sick_beard_index = 1" \
         -e 's%^newznab_data =.*%newznab_data = Sick Beard Index|https://lolo.sickbeard.com/|0||1|eponly|0|1|1|1|0!!!NZBgeek|https://api.nzbgeek.info/|||0|eponly|0|1|1|1|0!!!DrunkenSlug|https://api.drunkenslug.com/|||0|eponly|0|1|1|1|0!!!NinjaCentral|https://ninjacentral.co.za/|||0|eponly|0|1|1|1|0%' \
         "${config_dir}/sickgear.ini"
   fi
}

SetOwnerAndGroup(){
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Correct owner and group of application files, if required"
   find "${config_dir}" ! -user "${stack_user}" -exec chown "${stack_user}" {} \;
   find "${config_dir}" ! -group "${sickgear_group}" -exec chgrp "${sickgear_group}" {} \;
   find "${app_base_dir}" ! -user "${stack_user}" -exec chown "${stack_user}" {} \;
   find "${app_base_dir}" ! -group "${sickgear_group}" -exec chgrp "${sickgear_group}" {} \;
}

LaunchSickGear(){
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    ***** Configuration of SickGear container launch environment complete *****"
   if [ -z "${1}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Starting SickGear as ${stack_user}"
      exec "$(which su)" -p "${stack_user}" -c "$(which python) ${app_base_dir}/sickgear.py --config ${config_dir}/sickgear.ini --datadir ${config_dir}"
   else
      exec "$@"
   fi
}

##### Script #####
Initialise
CreateGroup
CreateUser
if [ ! -f "${config_dir}/sickgear.ini" ]; then FirstRun; fi
EnableSSL
Configure
Kodi
SABnzbd
Deluge
Prowl
Telegram
OMBWTFNZBs
Indexers
SetOwnerAndGroup
LaunchSickGear
