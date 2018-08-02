#!/usr/bin/dumb-init /bin/sh
set -e

CMD="$1"; shift

if [ "${CMD}" = 'init' ] || [ "$(id -u)" = '0' -a "${CMD}" = 'start' ]; then
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
  chown -R -h ${SVC_USER}:${SVC_GROUP} "${SVC_HOME}"

  [ "${CMD}" = 'init' ] && exit 0
fi

if [ "${CMD}" = 'start' ]; then

  if [ -z "$(find "${SVC_HOME}" -maxdepth 1 | tail -n +2)" ]; then
    cp -r /pki.tmpl/* "${SVC_HOME}/"
    chown -R -h ${SVC_USER}:${SVC_GROUP} "${SVC_HOME}"
    /usr/local/bin/build-ca.sh
  fi

  if [ "$(id -u)" = '0' ]; then
    echo "Starting process as user '${SVC_USER}' with UID ${SVC_USER_ID} ..."
    exec su-exec ${SVC_USER} "$@"
  else
    echo "Starting process as user '$(id -un)' with UID $(id -u) ..."
    exec ${SVC_USER} "$@"
  fi
  
  exit $?
fi

exit 1
