#!/usr/bin/dumb-init /bin/sh
set -e
. /etc/profile

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

  echo "${SVC_USER} ALL=(root)NOPASSWD:SETENV:/usr/local/bin/gen-crl.sh ${TYPE}" > /etc/sudoers.d/gen-crl

  [ "${CMD}" = 'init' ] && exit 0
fi

if [ "${CMD}" = 'start' ]; then
  SUEXEC="su-exec ${SVC_USER}"

  if [ ! -s "${SVC_HOME}/easyrsa" ]; then
    echo "Building PKI, this may take a while ..."
    /usr/local/bin/build-ca.sh 2>&1 | tee -a "${SVC_HOME}/build-ca-audit.log"
  fi

  # generate requests based on environment variables
  ${SUEXEC} /usr/local/bin/gen-requests.sh

  /usr/local/bin/set-permissions.sh

  echo "Starting process as user '${SVC_USER}' with UID ${SVC_USER_ID} ..."
  exec ${SUEXEC} "$@"
  exit $?
fi

exit 1
