#!/bin/sh +e
. /etc/profile
PATH=".:${PATH}"

PKI_HOME=${PKI_HOME:-${SVC_HOME:-/pki}}
PKI_PASSWD=${PKI_PASSWD:-${PKI_HOME}.passwd}
REQS="${PKI_HOME}/fifo"

find "${PKI_HOME}" -xdev -type l -exec test ! -e {} \; -delete
chown root:${SVC_GROUP} "${PKI_HOME}"
chown -R -h root:${SVC_GROUP} "${PKI_PASSWD}" "${PKI_HOME}/.gitignore" "${PKI_HOME}/.rnd"
chown -R -h ${SVC_USER}:${SVC_GROUP} "${REQS}"
chmod 751 "${REQS}"
chmod 710 "${PKI_PASSWD}"
chmod 751 "${PKI_HOME}"
chmod 555 "${PKI_HOME}/easyrsa"
chmod 660 "${PKI_HOME}/.rnd"
chmod 644 "${PKI_HOME}/.gitignore"
find "${PKI_HOME}/web" -type d -exec chmod 755 {} \;
find "${PKI_HOME}/web" -type f -exec chmod 644 {} \;

for CA in $(ls "${PKI_HOME}/" | grep -E "^.*-ca$"); do
  type=$(echo "${CA}" | cut -d "-" -f 1)
  algo=$(echo "${CA}" | cut -d "-" -f 2)
  DIR="${PKI_HOME}/${CA}"
  DIRPASSWD="${PKI_PASSWD}/${CA}"

  if [ "${type}" = 'root' ]; then
    chown -R -h root:root "${DIR}"
    chown -R -h root:root "${DIRPASSWD}"
    chown root:${SVC_GROUP} "${DIR}" "${DIR}/data"
  else
    chown -R -h ${SVC_USER}:${SVC_GROUP} "${DIR}"
    chown -R -h ${SVC_USER}:root "${DIRPASSWD}"
    chmod 700 "${DIRPASSWD}"
    chmod 600 "${DIRPASSWD}"/*.passwd
  fi
  chown -R -h ${SVC_USER}:${SVC_GROUP} "${REQS}/${CA/-*}/$(echo ${CA} | cut -d - -f 2)"

  chmod 751 "${DIR}" "${DIR}/data"
  chmod 444 "${DIR}"/data/ca*.crt "${DIR}"/data/ca*.der
  chmod 444 "${DIR}/data/ca-bundle."* "${DIR}/data/ca.crt" "${DIR}/data/ca.der"
  [ -e "${DIR}/data/dh.pem" ] && chmod 444 "${DIR}/data/dh."*
  [ -e "${DIR}/data/ca-chain.crt" ] && chmod 444 "${DIR}/data/ca-chain."*
  [ -e "${DIR}/data/crl.pem" ] && chmod 644 "${DIR}/data/crl."*
  if [ -e "${DIR}"/data/ecparams ]; then
    chmod 755 "${DIR}"/data/ecparams
    chmod 444 "${DIR}"/data/ecparams/*.pem
  fi
  chmod 600 "${DIR}"/data/private/*

  # fifo directory
  mkdir -p "${REQS}/${CA/-*}" "${REQS}/${CA/-*}/$(echo ${CA} | cut -d - -f 2)"
  chmod 755 "${REQS}/${CA/-*}"
  chmod 710 "${REQS}/${CA/-*}/$(echo ${CA} | cut -d - -f 2)"
  find "${REQS}/${CA/-*}/$(echo ${CA} | cut -d - -f 2)" -mindepth 1 -type d -exec chmod 770 {} \;
  find "${REQS}/${CA/-*}/$(echo ${CA} | cut -d - -f 2)" -type f -name "*.key" -exec chmod 660 {} \;
done

exit 0
