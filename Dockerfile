FROM alpine:3.14.3
MAINTAINER boredazfcuk
# sickgear_version not used, just increment to force a rebuild
ARG sickgear_version="Master 0.25.22 @ Commit 043fe38"
# last_updated for automated rebuilds
ARG last_updated="2022-02-05T01:20:48Z"
ARG app_repo="SickGear/SickGear"
ARG build_dependencies="py3-pip gcc python3-dev libxml2-dev libxslt-dev musl-dev libffi-dev"
ARG app_dependencies="git ca-certificates python3 libxml2 libxslt tzdata unrar unzip p7zip openssl py3-lxml py3-regex py3-cheetah py3-cffi py3-cryptography"
ENV app_base_dir="/SickGear" \
   config_dir="/config"

RUN echo "$(date '+%d/%m/%Y - %H:%M:%S') | ***** BUILD STARTED FOR SICKGEAR *****" && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Create application directory" && \
   mkdir -p "${app_base_dir}" && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Install build dependencies" && \
   apk add --no-cache --no-progress --virtual=build-deps ${build_dependencies} && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Install dependencies" && \
   apk add --no-cache --no-progress ${app_dependencies} && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Install ${app_repo} version ${sickgear_version}" && \
   git clone -b master "https://github.com/${app_repo}.git" "${app_base_dir}" && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Install Python requirements" && \
   pip3 install --no-cache-dir wheel && \
   pip3 install --no-cache-dir --requirement "${app_base_dir}/requirements.txt" && \
   pip3 install --no-cache-dir --requirement "${app_base_dir}/recommended.txt" && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Clean up" && \
   apk del --purge build-deps && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | ***** BUILD COMPLETE *****"

COPY --chmod=0755 entrypoint.sh /usr/local/bin/entrypoint.sh
COPY --chmod=0755 healthcheck.sh /usr/local/bin/healthcheck.sh

HEALTHCHECK --start-period=10s --interval=1m --timeout=10s \
  CMD /usr/local/bin/healthcheck.sh

VOLUME "${config_dir}"
WORKDIR "${app_base_dir}"

ENTRYPOINT /usr/local/bin/entrypoint.sh
