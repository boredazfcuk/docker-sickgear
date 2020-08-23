#!/bin/ash

##### Functions #####
Initialise(){
   lan_ip="$(hostname -i)"
   echo
   echo "$(date '+%c') INFO:    ***** Configuring SickGear container launch environment *****"
   echo "$(date '+%c') INFO:    $(cat /etc/*-release | grep "PRETTY_NAME" | sed 's/PRETTY_NAME=//g' | sed 's/"//g')"
   echo "$(date '+%c') INFO:    Local user: ${stack_user:=stackman}:${user_id:=1000}"
   echo "$(date '+%c') INFO:    Local group: ${sickgear_group:=sickgear}:${sickgear_group_id:=1000}"
   echo "$(date '+%c') INFO:    Password: ${stack_password:=Skibidibbydibyodadubdub}"
   echo "$(date '+%c') INFO:    SickGear application directory: ${app_base_dir:=/SickGear}"
   echo "$(date '+%c') INFO:    SickGear configuration directory: ${config_dir:=/config}"
   echo "$(date '+%c') INFO:    Listening IP Address: ${lan_ip}"
   echo "$(date '+%c') INFO:    TV Show location(s): ${tv_dirs:=/storage/tvshows/}"
   echo "$(date '+%c') INFO:    Download directory: ${tv_complete_dir:=/storage/downloads/complete/tv/}"
   if [ "${sickgear_notifications}" ]; then
      if [ "${sickgear_notifications}" = "Prowl" ] && [ "${prowl_api_key}" ]; then
         echo "$(date '+%c') INFO:    Configure ${sickgear_notifications} notifications"
      elif  [ "${sickgear_notifications}" = "Pushbullet" ] && [ "${pushbullet_api_key}" ]; then
         echo "$(date '+%c') INFO:    Configure ${sickgear_notifications} notifications"
      elif [ "${sickgear_notifications}" = "Telegram" ] && [ "${telegram_token}" ] && [ "${telegram_chat_id}" ]; then
         echo "$(date '+%c') INFO:    Configure ${sickgear_notifications} notifications"
      else
         echo "$(date '+%c') WARINING ${sickgear_notifications} notifications enabled, but configured incorrectly - disabling notifications"
         unset sickgear_notifications prowl_api_key pushbullet_api_key telegram_token telegram_chat_id
      fi
   fi
}

CheckOpenVPNPIA(){
   if [ "${openvpnpia_enabled}" ]; then
      echo "$(date '+%c') INFO:    OpenVPNPIA is enabled. Wait for VPN to connect"
      vpn_adapter="$(ip addr | grep tun.$ | awk '{print $7}')"
      while [ -z "${vpn_adapter}" ]; do
         vpn_adapter="$(ip addr | grep tun.$ | awk '{print $7}')"
         sleep 5
      done
      echo "$(date '+%c') INFO:    VPN adapter available: ${vpn_adapter}"
   else
      echo "$(date '+%c') INFO:    OpenVPNPIA is not enabled"
   fi
}

CreateGroup(){
   if [ "$(grep -c "^${sickgear_group}:x:${sickgear_group_id}:" "/etc/group")" -eq 1 ]; then
      echo "$(date '+%c') INFO:    Group, ${sickgear_group}:${sickgear_group_id}, already created"
   else
      if [ "$(grep -c "^${sickgear_group}:" "/etc/group")" -eq 1 ]; then
         echo "$(date '+%c') ERROR:   Group name, ${sickgear_group}, already in use - exiting"
         sleep 120
         exit 1
      elif [ "$(grep -c ":x:${sickgear_group_id}:" "/etc/group")" -eq 1 ]; then
         if [ "${force_gid}" = "True" ]; then
            group="$(grep ":x:${sickgear_group_id}:" /etc/group | awk -F: '{print $1}')"
            echo "$(date '+%c') WARNING: Group id, ${sickgear_group_id}, already exists - continuing as force_gid variable has been set. Group name to use: ${sickgear_group}"
         else
            echo "$(date '+%c') ERROR:   Group id, ${sickgear_group_id}, already in use - exiting"
            sleep 120
            exit 1
         fi
      else
         echo "$(date '+%c') INFO:    Creating group ${sickgear_group}:${sickgear_group_id}"
         addgroup -g "${sickgear_group_id}" "${sickgear_group}"
      fi
   fi
}

CreateUser(){
   if [ "$(grep -c "^${stack_user}:x:${user_id}:${sickgear_group_id}" "/etc/passwd")" -eq 1 ]; then
      echo "$(date '+%c') INFO     User, ${stack_user}:${user_id}, already created"
   else
      if [ "$(grep -c "^${stack_user}:" "/etc/passwd")" -eq 1 ]; then
         echo "$(date '+%c') ERROR    User name, ${stack_user}, already in use - exiting"
         sleep 120
         exit 1
      elif [ "$(grep -c ":x:${user_id}:$" "/etc/passwd")" -eq 1 ]; then
         echo "$(date '+%c') ERROR    User id, ${user_id}, already in use - exiting"
         sleep 120
         exit 1
      else
         echo "$(date '+%c') INFO     Creating user ${stack_user}:${user_id}"
         adduser -s /bin/ash -D -G "${sickgear_group}" -u "${user_id}" "${stack_user}" -h "/home/${stack_user}"
      fi
   fi
}

FirstRun(){
   echo "$(date '+%c') INFO:    First run detected. Initialisation required"
   find "${config_dir}" ! -user "${stack_user}" -exec chown "${stack_user}" {} \;
   find "${config_dir}" ! -group "${sickgear_group}" -exec chgrp "${sickgear_group}" {} \;
   su -p "${stack_user}" -c "$(which python3) ${app_base_dir}/sickgear.py --config ${config_dir}/sickgear.ini --datadir ${config_dir} --quiet --nolaunch --daemon --pidfile=/tmp/sickgear.pid"
   sleep 15
   echo "$(date '+%c') INFO:    Default configuration created - restarting"
   echo "$(date '+%c') INFO:    ***** Reload SickGear launch environment *****"
   pkill python3
   sleep 5
   echo "$(date '+%c') INFO:    Configure update interval to 48hr"
   echo "$(date '+%c') INFO:    Enable notifications for available updates"
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

Configure(){
   echo "$(date '+%c') INFO:    Disable browser launch on startup"
   echo "$(date '+%c') INFO:    Configure host IP: ${lan_ip}"
   echo "$(date '+%c') INFO:    Enable failed download handling"
   echo "$(date '+%c') INFO:    Set TV Show library paths: ${tv_dirs}"
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
      echo "$(date '+%c') INFO:    Enable API key usage"
      echo "$(date '+%c') INFO:    Set API key sabnzbd:::${global_api_key}"
      sed -i \
         -e "/^\[General\]/,/^\[.*\]/ s%use_api =.*%use_api = 1%" \
         -e "/^\[General\]/,/^\[.*\]/ s%api_keys =.*%api_keys = sabnzbd:::${global_api_key}%" \
         "${config_dir}/sickgear.ini"
   fi
   if [ "${sickgear_enabled}" ]; then
      echo "$(date '+%c') INFO:    Set web root for reverse proxying to /sickgear"
      echo "$(date '+%c') INFO:    Enable handling of reverse proxy headers"
      echo "$(date '+%c') INFO:    Disable handling of security headers; leave it to the NGINX reverse proxy"
      sed -i \
         -e "/^\[General\]/,/^\[.*\]/ s%web_root =.*%web_root = /sickgear%" \
         -e "/^\[General\]/,/^\[.*\]/ s%handle_reverse_proxy =.*%handle_reverse_proxy = 1%" \
         -e "/^\[General\]/,/^\[.*\]/ s%send_security_headers =.*%send_security_headers = 0%" \
         "${config_dir}/sickgear.ini"
   fi
}

Kodi(){
   if [ "${kodi_enabled}" ]; then
      if [ "$(grep -c use_kodi "${config_dir}/sickgear.ini")" -eq 0 ]; then
         echo "$(date '+%c') INFO:    Configuring kodi-headless"
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
         echo "$(date '+%c') INFO:    Configuring kodi-headless"
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
      echo "$(date '+%c') INFO:    Enable SABnzbd"
      echo "$(date '+%c') INFO:    Setting SABnzbd host to http://sabnzbd:9090/"
      echo "$(date '+%c') INFO:    Setting SABnzbd category to: tv"
      sed -i \
         -e "/^\[General\]/,/^\[.*\]/ s%use_nzbs =.*%use_nzbs = 1%" \
         -e "/^\[General\]/,/^\[.*\]/ s%nzb_method =.*%nzb_method = sabnzbd%" \
         -e "/^\[General\]/,/^\[.*\]/ s%process_automatically =.*%process_automatically = 0%" \
         -e "/^\[SABnzbd\]/,/^\[.*\]/ s%sab_category =.*%sab_category = tv%" \
         "${config_dir}/sickgear.ini"
      if [ "$(grep -c sab_username "${config_dir}/sickgear.ini")" -eq 0 ]; then
         sed -i \
            -e "/^\[SABnzbd\]/a sab_username = ${stack_user}" \
            "${config_dir}/sickgear.ini"
      else
         sed -i \
            -e "/^\[SABnzbd\]/,/^\[.*\]/ s%sab_username =.*%sab_username = ${stack_user}%" \
            "${config_dir}/sickgear.ini"
      fi
      if [ "$(grep -c "sab_password" "${config_dir}/sickgear.ini")" -eq 0 ]; then
         sed -i \
            -e "/^\[SABnzbd\]/a sab_password = ${stack_password}" \
            "${config_dir}/sickgear.ini"
      else
         sed -i \
            -e "/^\[SABnzbd\]/,/^\[.*\]/ s%sab_password =.*%sab_password = ${stack_password}%" \
            "${config_dir}/sickgear.ini"
      fi
      if [ "$(grep -c sab_host "${config_dir}/sickgear.ini")" -eq 0 ]; then
         sed -i \
            -e "/^\[SABnzbd\]/a sab_host = http://sabnzbd:9090/" \
            "${config_dir}/sickgear.ini"
      else
         sed -i \
            -e "/^\[SABnzbd\]/,/^\[.*\]/ s%sab_host =.*%sab_host = http://sabnzbd:9090/%" \
            "${config_dir}/sickgear.ini"
      fi
      echo "$(date '+%c') INFO:    Setting SABnzbd API Key"
      if [ "$(grep -c sab_apikey "${config_dir}/sickgear.ini")" -eq 0 ]; then
         sed -i \
            -e "/^\[SABnzbd\]/a sab_apikey = ${global_api_key}" \
            "${config_dir}/sickgear.ini"
      else
         sed -i \
            -e "/^\[SABnzbd\]/,/^\[.*\]/ s%sab_apikey =.*%sab_apikey = ${global_api_key}%" \
            "${config_dir}/sickgear.ini"
      fi
   else
      echo "$(date '+%c') INFO:    SABnzbd not enabled"
      sed -i \
         -e "/^\[General\]/,/^\[.*\]/ s%use_nzbs =.*%use_nzbs = 0%" \
         "${config_dir}/sickgear.ini"
   fi
}

Deluge(){
   if [ "${deluge_enabled}" ]; then
      echo "$(date '+%c') INFO:    Enable Deluge for Torrents"
      sed -i \
         -e "/^\[General\]/,/^\[.*\]/ s%use_torrents =.*%use_torrents = 1%" \
         -e "/^\[General\]/,/^\[.*\]/ s%torrent_method =.*%torrent_method = deluge%" \
         "${config_dir}/sickgear.ini"
      if [ "$(grep -c "\[TORRENT\]" "${config_dir}/sickgear.ini")" -eq 0 ]; then
         echo "$(date '+%c') INFO:    Add Deluge host configuration"
         echo "[TORRENT]" >> "${config_dir}/sickgear.ini"
         sed -i \
            -e "/^\[TORRENT\]/a torrent_password = ${stack_password}" \
            -e "/^\[TORRENT\]/a torrent_host = http://deluge:8112/" \
            -e "/^\[TORRENT\]/a torrent_path = ${tv_complete_dir}" \
            -e "/^\[TORRENT\]/a torrent_label = tv" \
            "${config_dir}/sickgear.ini"
      else
         echo "$(date '+%c') INFO:    Configure Deluge host"
         sed -i \
            -e "/^\[TORRENT\]/,/^\[.*\]/ s%torrent_password =.*%torrent_password = ${stack_password}%" \
            -e "/^\[TORRENT\]/,/^\[.*\]/ s%torrent_host =.*%torrent_host = http://deluge:8112/%" \
            -e "/^\[TORRENT\]/,/^\[.*\]/ s%torrent_path =.*%torrent_path = ${tv_complete_dir}%" \
            -e "/^\[TORRENT\]/,/^\[.*\]/ s%torrent_label =.*%torrent_label = tv%" \
            "${config_dir}/sickgear.ini"
      fi
   else
      echo "$(date '+%c') INFO:    Deluge not enabled"
      sed -i \
         -e "/^\[General\]/,/^\[.*\]/ s%use_torrents =.*%use_torrents = 0%" \
         "${config_dir}/sickgear.ini"
   fi
}

Jellyfin(){
   if [ "${jellyfin_enabled}" ]; then
      echo "$(date '+%c') INFO:    Enable Jellyfin"
      if [ "$(grep -c "\[Emby\]" "${config_dir}/sickgear.ini")" -eq 0 ]; then
         echo "$(date '+%c') INFO:    Add Emby (Jellyfin compatible) configuration section"
         {
            echo "[Emby]"
            echo "use_emby = 1"
            echo "emby_apikey = ${global_api_key}"
            echo "emby_host = jellyfin:8096/jellyfin"
            echo "emby_update_library = 1"
            echo "emby_watchedstate_frequency = 10"
         } >> "${config_dir}/sickgear.ini"
      else
         echo "$(date '+%c') INFO:    Configure Emby (Jellyfin compatible) host"
         sed -i \
            -e "/^\[Emby\]/,/^\[.*\]/ s%use_emby =.*%use_emby = 1%" \
            -e "/^\[Emby\]/,/^\[.*\]/ s%emby_apikey =.*%emby_apikey = ${global_api_key}%" \
            -e "/^\[Emby\]/,/^\[.*\]/ s%emby_host = .*%emby_host = jellyfin:8096/jellyfin%" \
            -e "/^\[Emby\]/,/^\[.*\]/ s%emby_update_library =.*%emby_update_library = 1%" \
            "${config_dir}/sickgear.ini"
      fi
   else
      echo "$(date '+%c') INFO:    Jellyfin not enabled"
      sed -i \
         -e "/^\[Emby\]/,/^\[.*\]/ s%use_emby =.*%use_emby = 0%" \
         "${config_dir}/sickgear.ini"
   fi
}

Prowl(){
   if [ "${prowl_api_key}" ]; then
      if [ "$(grep -c "\[Prowl\]" "${config_dir}/sickgear.ini")" -eq 0 ]; then
         echo "$(date '+%c') INFO:    Add Prowl notification configuration"
         echo "[Prowl]" >> "${config_dir}/sickgear.ini"
         sed -i \
            -e "/^\[Prowl\]/a prowl_notify_ondownload = 1"\
            -e "/^\[Prowl\]/a prowl_api = ${prowl_api_key}" \
            -e "/^\[Prowl\]/a use_prowl = 1" \
            "${config_dir}/sickgear.ini"
      fi
      echo "$(date '+%c') INFO:    Configure Prowl notifications"
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

Telegram(){
   if [ "${telegram_token}" ]; then
      if [ "$(grep -c "\[Telegram\]" "${config_dir}/sickgear.ini")" -eq 0 ]; then
         echo "$(date '+%c') INFO:    Add default Telegram notification configuration"
         {
            echo "[Telegram]"
            echo "use_telegram = 1"
            echo "telegram_notify_ondownload = 1"
            echo "telegram_access_token = ${telegram_token}"
            echo "telegram_chatid = ${telegram_chat_id}"
         }  >> "${config_dir}/sickgear.ini"
      fi
      if [ "$(grep -c "telegram_chatid" "${config_dir}/sickgear.ini")" -eq 0 ]; then
         echo "$(date '+%c') INFO:    Add missing Chat ID"
         sed -i \
            -e "/^\[Telegram\]/a telegram_chatid = ${telegram_chat_id}" \
            "${config_dir}/sickgear.ini"
      fi
      echo "$(date '+%c') INFO:    Set Telegram Chat ID and Access Token"
      sed -i \
         -e "/^\[Telegram\]/,/^\[.*\]/ s%^use_telegram =.*%use_telegram = 1%" \
         -e "/^\[Telegram\]/,/^\[.*\]/ s%^telegram_chatid =.*%telegram_chatid = ${telegram_chat_id}%" \
         -e "/^\[Telegram\]/,/^\[.*\]/ s%^telegram_access_token =.*%telegram_access_token = ${telegram_token}%" \
         "${config_dir}/sickgear.ini"
      echo "$(date '+%c') INFO:    Disable send icon"
      sed -i \
         -e "/telegram_send_ico/d" \
         "${config_dir}/sickgear.ini"
   else
      echo "$(date '+%c') INFO:    Disable Telegram notifications"
      sed -i \
         -e "/^\[Telegram\]/,/^\[.*\]/ s%^use_telegram =.*%use_telegram = 0%" \
         "${config_dir}/sickgear.ini"
   fi
}

OMGWTFNZBs(){
   if [ "${omgwtfnzbs_api_key}" ]; then
      echo "$(date '+%c') INFO:    Configuring OMGWTFNZBs search provider"
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
   echo "$(date '+%c') INFO:    Configure indexers"
   if [ "$(grep -c "\[MAGNETDL\]" "${config_dir}/sickgear.ini")" -eq 0 ]; then
      echo "$(date '+%c') INFO:    Enable MagnetDL provider"
      echo "[MAGNETDL]" >> "${config_dir}/sickgear.ini"
      sed -i \
         -e "/^\[MAGNETDL\]/a magnetdl = 1" \
         "${config_dir}/sickgear.ini"
   fi
   if [ "$(grep -c "\[ETTV\]" "${config_dir}/sickgear.ini")" -eq 0 ]; then
      echo "$(date '+%c') INFO:    Enable ETTV provider"
      echo "[ETTV]" >> "${config_dir}/sickgear.ini"
      sed -i \
         -e "/^\[ETTV\]/a ettv = 1" \
         "${config_dir}/sickgear.ini"
   fi
   if [ "$(grep -c "\[EZTV\]" "${config_dir}/sickgear.ini")" -eq 0 ]; then
      echo "$(date '+%c') INFO:    Enable EZTV provider"
      echo "[EZTV]" >> "${config_dir}/sickgear.ini"
      sed -i \
         -e "/^\[EZTV\]/a eztv = 1" \
         "${config_dir}/sickgear.ini"
   fi
   if [ "$(grep -c "\[SKYTORRENTS\]" "${config_dir}/sickgear.ini")" -eq 0 ]; then
      echo "$(date '+%c') INFO:    Enable Sky Torrents provider"
      echo "[SKYTORRENTS]" >> "${config_dir}/sickgear.ini"
      sed -i \
         -e "/^\[SKYTORRENTS\]/a skytorrents = 1" \
         "${config_dir}/sickgear.ini"
   fi
   if [ "$(grep -c "\[SICK_BEARD_INDEX\]" "${config_dir}/sickgear.ini")" -eq 0 ]; then
      echo "$(date '+%c') INFO:    Enable SickBeard index provider"
      echo "[SICK_BEARD_INDEX]" >> "${config_dir}/sickgear.ini"
      sed -i \
         -e "/^\[SICK_BEARD_INDEX\]/a sick_beard_index = 1" \
         -e 's%^newznab_data =.*%newznab_data = Sick Beard Index|https://lolo.sickbeard.com/|0||1|eponly|0|1|1|1|0!!!NZBgeek|https://api.nzbgeek.info/|||0|eponly|0|1|1|1|0!!!DrunkenSlug|https://api.drunkenslug.com/|||0|eponly|0|1|1|1|0!!!NinjaCentral|https://ninjacentral.co.za/|||0|eponly|0|1|1|1|0%' \
         "${config_dir}/sickgear.ini"
   fi
}

SetOwnerAndGroup(){
   echo "$(date '+%c') INFO:    Correct owner and group of application files, if required"
   find "${config_dir}" ! -user "${stack_user}" -exec chown "${stack_user}" {} \;
   find "${config_dir}" ! -group "${sickgear_group}" -exec chgrp "${sickgear_group}" {} \;
   find "${app_base_dir}" ! -user "${stack_user}" -exec chown "${stack_user}" {} \;
   find "${app_base_dir}" ! -group "${sickgear_group}" -exec chgrp "${sickgear_group}" {} \;
}

LaunchSickGear(){
   echo "$(date '+%c') INFO:    ***** Configuration of SickGear container launch environment complete *****"
   if [ -z "${1}" ]; then
      echo "$(date '+%c') INFO:    Starting SickGear as ${stack_user}"
      exec "$(which su)" -p "${stack_user}" -c "$(which python3) ${app_base_dir}/sickgear.py --config ${config_dir}/sickgear.ini --datadir ${config_dir}"
   else
      exec "$@"
   fi
}

##### Script #####
Initialise
CheckOpenVPNPIA
CreateGroup
CreateUser
if [ ! -f "${config_dir}/sickgear.ini" ]; then FirstRun; fi
Configure
Kodi
SABnzbd
Deluge
Jellyfin
Prowl
Telegram
OMGWTFNZBs
Indexers
SetOwnerAndGroup
LaunchSickGear
