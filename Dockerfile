FROM alpine:latest
MAINTAINER boredazfcuk
# sickgear_version not used, just increment to force a rebuild
ARG sickgear_version="Develop 0.21.30 @ Commit ec3668e"
ARG app_repo="SickGear/SickGear"
ARG build_dependencies="py3-pip gcc python3-dev libxml2-dev libxslt-dev musl-dev"
ARG app_dependencies="git ca-certificates python3 libxml2 libxslt tzdata unrar unzip p7zip openssl wget"
ENV app_base_dir="/SickGear" \
   config_dir="/config"

RUN echo "$(date '+%d/%m/%Y - %H:%M:%S') | ***** BUILD STARTED *****" && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Create application directory" && \
   mkdir -p "${app_base_dir}" && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Install build dependencies" && \
   apk add --no-cache --no-progress --virtual=build-deps ${build_dependencies} && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Install dependencies" && \
   apk add --no-cache --no-progress ${app_dependencies} && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Install ${app_repo} version ${sickgear_version}" && \
   git clone -b develop "https://github.com/${app_repo}.git" "${app_base_dir}" && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Install Python requirements" && \
   echo -e "\nlxml\nregex\nscandir" >> "${app_base_dir}/requirements.txt" && \
   pip3 install --upgrade pip --no-cache-dir --requirement "${app_base_dir}/requirements.txt" && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Clean up" && \
   apk del --purge build-deps

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY healthcheck.sh /usr/local/bin/healthcheck.sh

RUN echo "$(date '+%d/%m/%Y - %H:%M:%S') | Set permissions on scripts" && \
   chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/healthcheck.sh && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | ***** BUILD COMPLETE *****"

HEALTHCHECK --start-period=10s --interval=1m --timeout=10s \
  CMD /usr/local/bin/healthcheck.sh

VOLUME "${config_dir}"
WORKDIR "${app_base_dir}"

ENTRYPOINT /usr/local/bin/entrypoint.sh
