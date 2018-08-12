#!/usr/bin/dumb-init /bin/sh
set -e

CMD="$1"; shift

if [ "${CMD}" = 'init' ] || [ "${CMD}" = 'start' ]; then
  echo "Setting permissions ..."
  [ ! -s /etc/passwd.orig ] && cp /etc/passwd /etc/passwd.orig
  [ ! -s /etc/shadow.orig ] && cp /etc/shadow /etc/shadow.orig
  [ ! -s /etc/group.orig ] && cp /etc/group /etc/group.orig
  cp -f /etc/passwd.orig /etc/passwd
  cp -f /etc/shadow.orig /etc/shadow
  cp -f /etc/group.orig /etc/group

  mkdir -p "${SVC_HOME}"
  addgroup -g ${SVC_GROUP_ID} ${SVC_GROUP}
  adduser -h "${SVC_HOME}" -s /bin/nologin -u ${SVC_USER_ID} -D -H -G ${SVC_GROUP} ${SVC_USER}
  #addgroup ${SVC_USER} bluetooth
  #addgroup ${SVC_USER} dialout
  #addgroup ${SVC_USER} tty

  [ "${CMD}" = 'init' ] && exit 0
fi

if [ "${CMD}" = 'start' ]; then
  SUEXEC="su-exec ${SVC_USER}"

  [ ! -s "${SVC_HOME}/easyrsa" ] && /usr/local/bin/build-ca.sh

  # enforce directory and file permissions for Root CA
  cd "${SVC_HOME}"
  mkdir -p fifo
  chown -R -h root:root $(ls -A | grep -v fifo)
  chown -R -h root:${SVC_GROUP} . .rnd
  chown -R -h ${SVC_USER}:${SVC_GROUP} fifo
  find $(ls -A | grep -v fifo) -type d -exec chmod 700 {} \;
  find $(ls -A | grep -v fifo) -type f -exec chmod 600 {} \;
  chmod 751 . fifo
  chmod 555 easyrsa
  chmod 660 .rnd

  # enforce directory and file permissions for every Sub CA
  for SUBCA in $(ls ${SVC_HOME}/ | grep -E "^.*-ca$"); do
    mkdir -p "${SVC_HOME}/fifo/${SUBCA/-*}" "${SVC_HOME}/fifo/${SUBCA/-*}/$(echo ${SUBCA} | cut -d - -f 2)"
    chown -R -h ${SVC_USER}:${SVC_GROUP} "${SVC_HOME}/fifo/${SUBCA/-*}/$(echo ${SUBCA} | cut -d - -f 2)"
    chmod 751 "${SVC_HOME}/fifo/${SUBCA/-*}"
    chmod 711 "${SVC_HOME}/fifo/${SUBCA/-*}/$(echo ${SUBCA} | cut -d - -f 2)"
    find "${SVC_HOME}/fifo/${SUBCA/-*}/$(echo ${SUBCA} | cut -d - -f 2)" -maxdepth 0 -type d -exec chmod 777 {} \;

    cd "${SVC_HOME}/${SUBCA}"
    chown -R -h ${SVC_USER}:${SVC_GROUP} .
    chmod 755 . data
    chmod 644 data/dh.pem data/ca.crt data/ca-chain.crt
    chmod 444 data/ca*.crt data/dh.pem
    if [ -e data/ecparams ]; then
      chmod 755 data/ecparams
      chmod 444 data/ecparams/*.pem
    fi
  done

  # generate requests based on environment variables
  ${SUEXEC} /usr/local/bin/gen-certs.sh

  echo "Starting process as user '${SVC_USER}' with UID ${SVC_USER_ID} ..."
  exec ${SUEXEC} "$@"
  exit $?
fi

exit 1
