#!/usr/bin/dumb-init /bin/sh
set -e

CMD="$1"; shift

if [ "${CMD}" = 'init' ] || [ "${CMD}" = 'start' ]; then

  if [ "${CMD}" = 'init' ] || [ "$(id -u)" = '0' ]; then
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

    [ "${CMD}" = 'start' ] && exec su-exec ${SVC_USER} "$@"
  else
    [ "${CMD}" = 'start' ] && exec "$@"
  fi

  exit 0
fi

exit 1
