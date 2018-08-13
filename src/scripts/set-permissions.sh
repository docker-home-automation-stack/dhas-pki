#!/bin/sh
set +e

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
chmod 444 data/ca.crt
chmod 644 data/crl.pem
chmod 600 data/private/*

# enforce directory and file permissions for every Sub CA
for SUBCA in $(ls ${SVC_HOME}/ | grep -E "^.*-ca$"); do
  mkdir -p "${SVC_HOME}/fifo/${SUBCA/-*}" "${SVC_HOME}/fifo/${SUBCA/-*}/$(echo ${SUBCA} | cut -d - -f 2)"
  chown -R -h ${SVC_USER}:${SVC_GROUP} "${SVC_HOME}/fifo/${SUBCA/-*}/$(echo ${SUBCA} | cut -d - -f 2)"
  chmod 751 "${SVC_HOME}/fifo/${SUBCA/-*}"
  chmod 711 "${SVC_HOME}/fifo/${SUBCA/-*}/$(echo ${SUBCA} | cut -d - -f 2)"
  find "${SVC_HOME}/fifo/${SUBCA/-*}/$(echo ${SUBCA} | cut -d - -f 2)" -maxdepth 0 -type d -exec chmod 777 {} \;
  find "${SVC_HOME}/fifo/${SUBCA/-*}/$(echo ${SUBCA} | cut -d - -f 2)" -maxdepth 0 -type f -name "*.key" -exec chmod 640 {} \;

  cd "${SVC_HOME}/${SUBCA}"
  chown -R -h ${SVC_USER}:${SVC_GROUP} .
  chmod 755 . data
  chmod 444 data/ca*.crt data/dh.pem
  if [ -e data/ecparams ]; then
    chmod 755 data/ecparams
    chmod 444 data/ecparams/*.pem
  fi
  chmod 644 data/crl.pem
  chmod 600 data/private/*
done

exit 0
