#!/bin/sh
set +e

cd "${SVC_HOME}"
mkdir -p fifo
chown -R -h root:${SVC_GROUP} . .rnd
chown -R -h ${SVC_USER}:${SVC_GROUP} fifo
chmod 751 fifo
chmod 555 easyrsa
chmod 660 .rnd

# enforce directory and file permissions for Root CA
for TYPE in ecc rsa; do
  cd "${SVC_HOME}/root-${TYPE}-ca"
  chown -R -h root:root .
  chown root:${SVC_GROUP} . data
  find . -type d -exec chmod 700 {} \;
  find . -type f -exec chmod 600 {} \;
  chmod 750 . data
  chmod 444 data/ca.crt
  chmod 644 data/crl.pem
done

for SUBCA in $(ls ${SVC_HOME}/ | grep -E "^.*-ca$" | grep -v root-); do
  
  # fifo directory for Sub CA
  mkdir -p "${SVC_HOME}/fifo/${SUBCA/-*}" "${SVC_HOME}/fifo/${SUBCA/-*}/$(echo ${SUBCA} | cut -d - -f 2)"
  chown -R -h ${SVC_USER}:${SVC_GROUP} "${SVC_HOME}/fifo/${SUBCA/-*}/$(echo ${SUBCA} | cut -d - -f 2)"
  chmod 755 "${SVC_HOME}/fifo/${SUBCA/-*}"
  chmod 710 "${SVC_HOME}/fifo/${SUBCA/-*}/$(echo ${SUBCA} | cut -d - -f 2)"
  find "${SVC_HOME}/fifo/${SUBCA/-*}/$(echo ${SUBCA} | cut -d - -f 2)" -mindepth 1 -type d -exec chmod 770 {} \;
  find "${SVC_HOME}/fifo/${SUBCA/-*}/$(echo ${SUBCA} | cut -d - -f 2)" -type f -name "*.key" -exec chmod 660 {} \;

  # enforce directory and file permissions for Sub CA
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
