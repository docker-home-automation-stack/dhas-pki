#!/bin/sh

REQS="${SVC_HOME}/fifo"
umask 0027

for TYPE in root client code email server; do
  for ALGO in ecc rsa; do
    
    [ "${TYPE}" = 'root' ] && SUDO=sudo
    ${SUDO} /usr/local/bin/gen-crl.sh ${TYPE} ${ALGO}    
    [ "${TYPE}" = 'root' ] && continue 

    # search per requestor directory
    for REQUESTOR in $(cd "${REQS}/${TYPE}/${ALGO}"; ls); do

      # search requests
      for REQ in $(find "${REQS}/${TYPE}/${ALGO}/${REQUESTOR}" -type f -regex "^.*\.csr$" -o -regex "^.*\.req$"); do
        [ -s "${REQ%.*}".crt ] && continue # ignore already signed certificate
        FILENAME="${REQ##*/}"
        BASENAME="${REQUESTOR}--${FILENAME%.*}"

        cd "${SVC_HOME}/${TYPE}-${ALGO}-ca"

        # import into PKI
        echo "Importing '${REQ}' as '${BASENAME}' to PKI ${TYPE}-${ALGO}-ca"
        RET_TXT=$(./easyrsa --batch import-req "${REQ}" "${BASENAME}" 2>&1)
        RET_CODE=$?

        # sign request
        if [ "${RET_CODE}" = '0' ]; then
          SAN=$(./easyrsa show-req "${BASENAME}" | grep -A 1 "Subject Alternative Name:" | tail -n +2 | sed -e "s/ //g")
          [ ! "${SAN}" = "" ] && SAN="--subject-alt-name=\"${SAN}\""
          echo "[${TYPE}-${ALGO}-ca] Signing '${BASENAME}'"
          RET_TXT=$(./easyrsa --batch ${SAN} sign-req ${TYPE} "${BASENAME}" 2>&1)
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
        chmod 644 "${REQ%.*}.crt"

        # copy CA chain
        cp -f "data/ca.crt" "${REQS}/${TYPE}/${ALGO}/${REQUESTOR}/ca.crt"
        cp -f "data/ca-chain.crt" "${REQS}/${TYPE}/${ALGO}/${REQUESTOR}/ca-chain.crt"
        
        # copy DH file
        cp -f "data/dh.pem" "${REQS}/${TYPE}/${ALGO}/${REQUESTOR}/dh.pem"

        # generate password file
        if [ ! -s "${REQ%.*}".passwd ]; then
          if [ "${TYPE}" = 'client' ] || [ "${TYPE}" = 'email' ]; then
            pwgen -1Bcn 12 1 > "${REQ%.*}".passwd
          else
            pwgen -1sy 42 1 > "${REQ%.*}".passwd
          fi
        fi

        # certificate variants
        cat "data/issued/${BASENAME}.crt" "data/ca-chain.crt" > "${REQ%.*}".full.crt
        openssl pkcs12 -export -out "${REQ%.*}".nopasswd.pfx -inkey "${REQ%.*}".key -in "data/issued/${BASENAME}.crt" -certfile "data/ca-chain.crt" -passout pass:
        openssl pkcs12 -export -out "${REQ%.*}".pfx -inkey "${REQ%.*}".key -in "data/issued/${BASENAME}.crt" -certfile "data/ca-chain.crt" -passout file:"${REQ%.*}".passwd

        # finishing
        echo "$RET_TXT" > "${REQ}.signed.txt"
        mv "${REQ}" "${REQ}.signed"
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
