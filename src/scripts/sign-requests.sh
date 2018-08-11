#!/bin/sh

REQS="${SVC_HOME}/fifo"

for TYPE in client code email server; do
  for ALGO in ec rsa; do
    mkdir -p "${REQS}/${TYPE}/${ALGO}"
    chmod 751 "${REQS}" "${REQS}/${TYPE}" "${REQS}/${TYPE}/${ALGO}"

    # search per requestor directory
    for REQUESTOR in $(cd "${REQS}/${TYPE}/${ALGO}"; ls); do
      chmod 777 "${REQS}/${TYPE}/${ALGO}/${REQUESTOR}"

      # search requests
      for REQ in $(find "${REQS}/${TYPE}/${ALGO}/${REQUESTOR}" -type f -regex "^.*\.csr$" -o -regex "^.*\.req$"); do
        [ -s "${REQ%.*}".crt ] && continue # ignore already signed certificate
        FILENAME="${REQ##*/}"
        BASENAME="${REQUESTOR}-${FILENAME%.*}"

        cd "${SVC_HOME}/${TYPE}-${ALGO}-ca"

        # import into PKI
        echo "Importing '${REQ}' as '${BASENAME}' to PKI ${TYPE}-${ALGO}-ca"
        RET_TXT=$(./easyrsa --batch import-req "${REQ}" "${BASENAME}" 2>&1)
        RET_CODE=$?

        # sign request
        if [ "${RET_CODE}" = '0' ]; then
          echo "[${TYPE}-${ALGO}-ca] Signing '${BASENAME}'"
          RET_TXT=$(./easyrsa --batch sign-req ${TYPE} "${BASENAME}" 2>&1)
          RET_CODE=$?
        fi

        # if signing failed, rename request
        if [ ${RET_CODE} != 0 ]; then
          rm -f "data/reqs/${BASENAME}.req"
          echo "${RET_TXT}" > "${REQ}.error.txt"
          mv "${REQ}" "${REQ}.error"
          continue
        fi

        # copy certificate
        echo "[${TYPE}-${ALGO}-ca] Exporting '${BASENAME}.crt' to '${REQ%.*}.crt'"
        cp -f "data/issued/${BASENAME}.crt" "${REQ%.*}.crt"

        # copy CA chain
        cp -f "data/ca.crt" "${REQ%.*}".ca.crt
        cp -f "data/ca-chain.crt" "${REQ%.*}".ca-chain.crt

        echo "$RET_TXT" > "${REQ}.signed.txt"
        mv "${REQ}" "${REQ}.signed"
        chmod 664 "${REQ}.signed" "${REQ}.signed.txt" "${REQ%.*}".crt "${REQ%.*}".ca.crt "${REQ%.*}".ca-chain.crt
      done

      # search for signed requests
      for REQ_SIGNED in $(find "${REQS}/${TYPE}/${ALGO}/${REQUESTOR}" -type f -regex "^.*\.csr.signed$" -o -regex "^.*\.req.signed$"); do
        FILENAME_SIGNED="${REQ_SIGNED##*/}"
        FILENAME="${FILENAME_SIGNED%.*}"
        REQ="${REQ_SIGNED%/*}${FILENAME}"
        BASENAME="${REQUESTOR}-${FILENAME%.*}"

        [ -s "${REQ%.*}".crt ] || continue # continue only when cert file still exists

        #TODO: renew (almost) expired certificates
      done

    done
  done
done

cd "${SVC_HOME}"

exit 0
