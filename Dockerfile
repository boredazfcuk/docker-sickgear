FROM alpine:latest
MAINTAINER boredazfcuk
ENV APPBASE="/SickGear" \
   CONFIGDIR="/config" \
   REPO="SickGear/SickGear" \
   BUILDDEPENDENCIES="py-pip gcc python-dev libxml2-dev libxslt-dev musl-dev" \
   APPDEPENDENCIES="git python libxml2 libxslt tzdata unrar unzip p7zip openssl"

COPY start-sickgear.sh /usr/local/bin/start-sickgear.sh

RUN echo "$(date '+%d/%m/%Y - %H:%M:%S') | ***** BUILD STARTED *****" && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Create application directory" && \
   mkdir -p "${APPBASE}" && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Install build dependencies" && \
   apk add --no-cache --no-progress --virtual=build-deps ${BUILDDEPENDENCIES} && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Install dependencies" && \
   apk add --no-cache --no-progress ${APPDEPENDENCIES} && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Install ${REPO}" && \
   git clone -b develop "https://github.com/${REPO}.git" "${APPBASE}" && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Install Python requirements" && \
   echo -e "\nlxml\nregex\nscandir" >> "${APPBASE}/requirements.txt" && \
   pip install --no-cache-dir -r "${APPBASE}/requirements.txt" && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Clean up" && \
   chmod +x /usr/local/bin/start-sickgear.sh && \
   apk del --purge build-deps && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | ***** BUILD COMPLETE *****"

HEALTHCHECK --start-period=10s --interval=1m --timeout=10s \
  CMD wget --quiet --tries=1 --spider http://${HOSTNAME}:8081/sickgear/home || exit 1

VOLUME "${CONFIGDIR}"

CMD /usr/local/bin/start-sickgear.sh
