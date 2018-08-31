#!/bin/sh +e

PKI_HOME=${PKI_HOME:-${SVC_HOME:-/pki}}
PKI_PASSWD=${PKI_PASSWD:-${PKI_HOME}.passwd}
REQS="${PKI_HOME}/fifo"

for DIR in $(find "${PKI_HOME}" -mindepth 1 -maxdepth 1 -type d | grep -v "^${REQS}") "${PKI_HOME}/.gitignore" "${PKI_HOME}/.rnd"; do
  chown -R -h root:${SVC_GROUP} "${DIR}"
done
chown -R -h ${SVC_USER}:${SVC_GROUP} "${REQS}"
chmod 751 "${REQS}"
chmod 555 "${PKI_HOME}/easyrsa"
chmod 660 "${PKI_HOME}/.gitignore" "${PKI_HOME}/.rnd"

# enforce directory and file permissions for Root CA
for ROOTCA in $(ls "${PKI_HOME}/" | grep -E "^.*-ca$" | grep ^root-); do
  chown -R -h root:root "${ROOTCA}"
  chown root:${SVC_GROUP} "${ROOTCA}" "${ROOTCA}/data"
  find "${ROOTCA}" -type d -exec chmod 700 {} \;
  find "${ROOTCA}" -type f -exec chmod 600 {} \;
  chmod 750 "${ROOTCA}" "${ROOTCA}/data"
  chmod 444 "${ROOTCA}/data/ca-bundle."* "${ROOTCA}/data/ca.crt" "${ROOTCA}/data/ca.der"
  chmod 644 "${ROOTCA}/data/crl.pem" "${ROOTCA}/data/crl.der"
done

for SUBCA in $(ls "${PKI_HOME}/" | grep -E "^.*-ca$" | grep -v ^root-); do

  # fifo directory for Sub CA
  mkdir -p "${REQS}/${SUBCA/-*}" "${REQS}/${SUBCA/-*}/$(echo ${SUBCA} | cut -d - -f 2)"
  chown -R -h ${SVC_USER}:${SVC_GROUP} "${REQS}/${SUBCA/-*}/$(echo ${SUBCA} | cut -d - -f 2)"
  chmod 755 "${REQS}/${SUBCA/-*}"
  chmod 710 "${REQS}/${SUBCA/-*}/$(echo ${SUBCA} | cut -d - -f 2)"
  find "${REQS}/${SUBCA/-*}/$(echo ${SUBCA} | cut -d - -f 2)" -mindepth 1 -type d -exec chmod 770 {} \;
  find "${REQS}/${SUBCA/-*}/$(echo ${SUBCA} | cut -d - -f 2)" -type f -name "*.key" -exec chmod 660 {} \;

  # enforce directory and file permissions for Sub CA
  chown -R -h ${SVC_USER}:${SVC_GROUP} "${PKI_HOME}/${SUBCA}"
  chmod 755 "${PKI_HOME}/${SUBCA}" "${PKI_HOME}/${SUBCA}/data"
  chmod 444 "${PKI_HOME}/${SUBCA}"/data/ca*.crt "${PKI_HOME}/${SUBCA}"/data/ca*.der "${PKI_HOME}/${SUBCA}"/data/dh.pem

  chmod 444 "${PKI_HOME}/${SUBCA}/data/ca-bundle."* "${PKI_HOME}/${SUBCA}/data/ca-chain."* "${PKI_HOME}/${SUBCA}/data/ca.crt" "${PKI_HOME}/${SUBCA}/data/ca.der"
  chmod 644 "${PKI_HOME}/${SUBCA}/data/crl.pem" "${PKI_HOME}/${SUBCA}/data/crl.der"
  if [ -e "${PKI_HOME}/${SUBCA}"/data/ecparams ]; then
    chmod 755 "${PKI_HOME}/${SUBCA}"/data/ecparams
    chmod 444 "${PKI_HOME}/${SUBCA}"/data/ecparams/*.pem
  fi
  chmod 600 "${PKI_HOME}/${SUBCA}"/data/private/*
done

exit 0
