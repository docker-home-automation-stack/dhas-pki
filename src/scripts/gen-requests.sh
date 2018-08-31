#!/bin/sh

CURRHOME="${HOME}"
CURRDIR=$(pwd)

PKI_HOME=${PKI_HOME:-${SVC_HOME:-/pki}}
PKI_PASSWD=${PKI_PASSWD:-${PKI_HOME}.passwd}
PKI_TMPL=${PKI_TMPL:-${PKI_HOME}.tmpl}
HOME="${PKI_HOME}"
REQS="${PKI_HOME}/fifo"
umask 0007

i=0

[ ! -s "${SVC_HOME}/easyrsa" ] && exit 1

for TYPE in client code email server; do

  while true; do
    CRT=$(eval "echo \${PKI_$(echo "${TYPE}" | tr '[:lower:]' '[:upper:]')CA_CRT_$i}")
    [ -z "${CRT}" ] && break

    REQUESTOR=$(echo "${CRT}" | cut -d ":" -f1)
    SAN=$(echo "${CRT}" | cut -d ":" -f2-)
    CN=$(echo "${SAN}" | cut -d ":" -f2 | cut -d "," -f1)
    CN=${CN//\*\./}

    [ "${CN}" = "ca" ] && continue # ensure one cannot do any processing on CA certificate files

    for ALGO in ecc rsa; do
      mkdir -p "${REQS}/${TYPE}/${ALGO}/${REQUESTOR}"
      chmod 770 "${REQS}/${TYPE}/${ALGO}/${REQUESTOR}"

      [[ -s "${REQS}/${TYPE}/${ALGO}/${REQUESTOR}/${CN}.req.signed" || -s "${REQS}/${TYPE}/${ALGO}/${REQUESTOR}/${CN}.csr.signed" ]] && continue

      cd "${SVC_HOME}/${TYPE}-${ALGO}-ca"

      echo "Generating ${ALGO} request '${CN}' with SAN '${SAN}'"

      RET_TXT=$(./easyrsa --batch --subject-alt-name="${SAN}" --req-cn="${CN}" gen-req "${CN}" nopass)
      RET_CODE=$?

      if [ "${RET_CODE}" = '0' ]; then
        mv data/reqs/${CN}.req "${REQS}/${TYPE}/${ALGO}/${REQUESTOR}/"
        mv data/private/${CN}.key "${REQS}/${TYPE}/${ALGO}/${REQUESTOR}/${CN}.nopasswd.key"
      fi

    done

    i=$(expr $i + 1)
  done
done

HOME="${CURRHOME}"
cd "${CURRDIR}"
exit 0
