#!/bin/sh

i=0
REQS="${SVC_HOME}/fifo"

for TYPE in client code email server; do

  while true; do
    CRT=$(eval "echo \${PKI_$(echo "${TYPE}" | tr '[:lower:]' '[:upper:]')CA_CRT_$i}")
    [ -z "${CRT}" ] && break

    REQUESTOR=$(echo "${CRT}" | cut -d ":" -f1)
    NAMES=$(echo "${CRT}" | cut -d ":" -f2)
    CN=$(echo "${NAMES}" | cut -d "," -f1)
    CN=${CN//\*\./}
    SAN="DNS:${NAMES//,/,DNS:}"
    
    [ "${CN}" = "ca" ] && continue # ensure one cannot do any processing on CA certificate files

    for ALGO in ec rsa; do
      mkdir -p "${REQS}/${TYPE}/${ALGO}/${REQUESTOR}"
      chmod 751 "${REQS}" "${REQS}/${TYPE}" "${REQS}/${TYPE}/${ALGO}"
      
      [[ -s "${REQS}/${TYPE}/${ALGO}/${REQUESTOR}/${CN}.req.signed" || -s "${REQS}/${TYPE}/${ALGO}/${REQUESTOR}/${CN}.csr.signed" ]] && continue

      cd "${SVC_HOME}/${TYPE}-${ALGO}-ca"
      
      echo "Generating ${ALGO} request '${CN}' with SAN '${SAN}'"

      RET_TXT=$(./easyrsa --batch --subject-alt-name="${SAN}" --req-cn="${CN}" gen-req "${CN}" nopass)
      RET_CODE=$?

      if [ "${RET_CODE}" = '0' ]; then
        mv data/reqs/${CN}.req "${REQS}/${TYPE}/${ALGO}/${REQUESTOR}/"
        mv data/private/${CN}.key "${REQS}/${TYPE}/${ALGO}/${REQUESTOR}/"
        chmod 640 "${REQS}/${TYPE}/${ALGO}/${REQUESTOR}/${CN}.key"
      fi

    done

    i=$(expr $i + 1)
  done
done

exit 0
