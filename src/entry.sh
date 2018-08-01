#!/bin/sh
set -e

CMD="$1"; shift

if [ "$CMD" = 'start' -a "$(id -u)" = '0' ]; then
  SVC_USER="$1"; shift
  SVC_USER_ID="$1"; shift
  SVC_GROUP="$1"; shift
  SVC_GROUP_ID="$1"; shift
  SVC_HOME="$1"; shift

  [ ! -s /etc/passwd.default ] && cp /etc/passwd /etc/passwd.orig
  [ ! -s /etc/shadow.default ] && cp /etc/shadow /etc/shadow.orig
  [ ! -s /etc/group.default ] && cp /etc/group /etc/group.orig
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

  exec su-exec ${SVC_USER} "$@"
fi
