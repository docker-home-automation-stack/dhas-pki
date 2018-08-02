#!/bin/sh

REQS="${SVC_HOME}/csr-in"

for TYPE in client code server; do
  for ALGO in ec rsa; do
    mkdir -p "${REQS}/${TYPE}/${ALGO}"
    chmod 551 "${REQS}" "${REQS}/${TYPE}"
    chmod 751 "${REQS}/${TYPE}/${ALGO}"
    
    for REQUESTOR in $(cd "${REQS}/${TYPE}/${ALGO}"; ls); do
      chmod 777 "${REQS}/${TYPE}/${ALGO}/${REQUESTOR}"

      for REQ in $(find "${REQS}/${TYPE}/${ALGO}/${REQUESTOR}" -type f -regex "^.*\.csr$" -o -regex "^.*\.req$"); do
        cd "${SVC_HOME}/${TYPE}-${ALGO}-ca"
        FILENAME="${REQ##*/}"
        BASENAME="${REQUESTOR}-${FILENAME%.*}"
        
        [ -s "${REQ%.*}".crt ] && continue

        RET_TXT=$(./easyrsa --batch import-req "${REQ}" "${BASENAME}")
        RET_CODE=$?

        if [ "${RET_CODE}" = '0' ]; then
          RET_TXT=$(./easyrsa --batch sign-req "${BASENAME}")
          RET_CODE=$?
        fi

        if [ ${RET_CODE} != 0 ]; then
          rm -f "data/reqs/${BASENAME}.req"
          echo "$RET_TXT" > "${REQ}.error.txt"
          mv "${REQ}" "${REQ}.error"
          continue
        fi

        cp -f "data/issued/${BASENAME}.crt" "${REQ%.*}".crt
        cp -f "data/ca.crt" "${REQ%.*}".ca.crt
        cp -f "data/ca-chain.crt" "${REQ%.*}".ca-chain.crt
        chmod 444 "${REQ}.signed" "${REQ}.signed.txt" "${REQ%.*}".crt "${REQ%.*}".ca.crt "${REQ%.*}".ca-chain.crt

        echo "$RET_TXT" > "${REQ}.signed.txt"
        mv "${REQ}" "${REQ}.signed"

      done
    done
  done
done

cd "${SVC_HOME}"

exit 0
