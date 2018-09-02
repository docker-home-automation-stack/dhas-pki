#!/bin/sh

CURRHOME="${HOME}"
CURRDIR=$(pwd)

PKI_HOME=${PKI_HOME:-${SVC_HOME:-/pki}}
PKI_PASSWD=${PKI_PASSWD:-${PKI_HOME}.passwd}
PKI_TMPL=${PKI_TMPL:-${PKI_HOME}.tmpl}
HOME="${PKI_HOME}"
REQS="${PKI_HOME}/fifo"
umask 0007

USERUID="$(id -u)"

if [ "${USERUID}" != 0 ] && [ "${USERUID}" != "${SVC_USER_ID}" ]; then
  echo "ERROR: Running this script with UID ${USERID} is prohibited."
  exit 1
fi

TMPDIR="$(mktemp -d /dev/shm/XXXXXXXXXXXXXXXXXXX)"

for TYPE in root client code email server; do

  # make sure root will only sign requests for Root CA
  if [ "${USERUID}" = 0 ] && [ "${TYPE}" != 'root' ]; then
    continue
  fi

  # make sure sign requests for Sub CA will only be handled
  # by non-root user
  if [ "${USERUID}" != 0 ] && [ "${TYPE}" = 'root' ]; then
    continue
  fi

  for ALGO in ecc rsa; do
    algo_openssl=${ALGO}
    [ "${algo_openssl}" = 'ecc' ] && algo_openssl="ec"

    SUDO="."
    [ "${TYPE}" = 'root' ] && SUDO="sudo -E"
    ${SUDO} /usr/local/bin/gen-crl.sh ${TYPE} ${ALGO}    

    # search per requestor directory
    for REQUESTOR in $(cd "${REQS}/${TYPE}/${ALGO}"; ls); do

      # search requests
      for REQ in $(find "${REQS}/${TYPE}/${ALGO}/${REQUESTOR}" -type f -regex "^.*\.csr$" -o -regex "^.*\.req$"); do
        [ -s "${REQ%.*}".crt ] && continue # ignore already signed certificate
        FILENAME="${REQ##*/}"
        BASENAME="${REQUESTOR}--${FILENAME%.*}"
        CA="${TYPE}-${ALGO}-ca"

        touch "${REQ}.processing"
        chmod 644 "${REQ}.processing"

        if [ "${TYPE}" = 'root' ] && [ "${USERUID}" != 0 ]; then
          echo "Pending signing request for Root CA requires manual attention: ${REQ}"
          echo "CA-manual-approval-wait" > "${REQ}.processing"
          continue
        fi

        rm -f "${REQ}.error" "${REQ}.error.txt" "${REQ}.signed" "${REQ}.signed.txt"

        cd "${PKI_HOME}/${CA}"

        echo "CA-unlock" > "${REQ}.processing"

        # Unlock CA private key
        if [ ! -s "data/private/ca.nopasswd.key" ] && [ -s "${PKI_PASSWD}/${CA}/${CA}.passwd" ]; then
          CA_KEY=$(mktemp ${TMPDIR}/XXXXXXXXXXXXXXXXXXX)
          RET_TXT=$(openssl ${algo_openssl} -out "${CA_KEY}" -in "data/private/ca.key" -passin file:"${PKI_PASSWD}/${CA}/${CA}.passwd" -passout pass:)
          RET_CODE=$?
          if [ "${RET_CODE}" = '0' ]; then
            ln -sfv "${CA_KEY}" "data/private/ca.nopasswd.key"

          # Skip processing if CA is currently "offline"
          else
            echo "CA-unlock-wait-offline: ${RET_TXT}" > "${REQ}.processing"
            continue
          fi
        fi

        # import into PKI
        echo "[${CA}] Importing '${REQ}' as '${BASENAME}'"
        echo "CA-import" > "${REQ}.processing"
        rm -f "data/reqs/${BASENAME}.req"
        RET_TXT=$(./easyrsa --batch import-req "${REQ}" "${BASENAME}" 2>&1)
        RET_CODE=$?

        # sign request
        if [ "${RET_CODE}" = '0' ]; then
          SAN=$(./easyrsa show-req "${BASENAME}" | grep -A 1 "Subject Alternative Name:" | tail -n +2 | sed -e "s/ //g")
          [ ! "${SAN}" = "" ] && SAN="--subject-alt-name=\"${SAN}\""
          echo "[${CA}] Signing '${BASENAME}'"
          CTYPE="${TYPE}"
          [ "${TYPE}" = 'root' ] && CTYPE="ca"
          echo "CA-signing" > "${REQ}.processing"
          RET_TXT=$(./easyrsa --batch ${SAN} sign-req ${CTYPE} "${BASENAME}" 2>&1)
          RET_CODE=$?
        fi

        # if signing failed, rename request
        if [ ${RET_CODE} != 0 ]; then
          rm -f "data/reqs/${BASENAME}.req" "${REQ}.processing"
          echo "${RET_TXT}" > "${REQ}.error.txt"
          mv "${REQ}" "${REQ}.error"
          continue
        fi

        # copy certificate
        echo "CA-finishing" > "${REQ}.processing"
        echo "[${CA}] Exporting '${BASENAME}.crt' to '${REQ%.*}.crt'"
        cp -f "data/issued/${BASENAME}.crt" "${REQ%.*}.crt"

        # copy CA chain
        [ -s "data/ca.crt" ] && cp --force --preserve=mode,timestamps "data/ca.crt" "${REQS}/${TYPE}/${ALGO}/${REQUESTOR}/ca.crt"
        [ -s "data/ca-chain.crt" ] && cp --force --preserve=mode,timestamps "data/ca-chain.crt" "${REQS}/${TYPE}/${ALGO}/${REQUESTOR}/ca-chain.crt"

        # copy DH file
        [ -s "data/dh.pem" ] && cp --force --preserve=mode,timestamps "data/dh.pem" "${REQS}/${TYPE}/${ALGO}/${REQUESTOR}/dh.pem"

        # generate password file
        if [ ! -s "${REQ%.*}".passwd ]; then
          if [ "${TYPE}" = 'client' ] || [ "${TYPE}" = 'email' ]; then
            pwgen -1Bcn 12 1 > "${REQ%.*}".passwd
          else
            pwgen -1sy 42 1 > "${REQ%.*}".passwd
          fi
        fi

        # Encrypt cert private key with password
        [ -s "${REQ%.*}".key ] && [ -z "$(cat data/private/ca.key | grep "Proc-Type: 4,ENCRYPTED")" ] && mv -vf "${REQ%.*}".key "${REQ%.*}".nopasswd.key
        [ ! -s "${REQ%.*}".key ] && [ -s "${REQ%.*}".nopasswd.key ] && openssl ${algo_openssl} -out "${REQ%.*}".key -aes256 -in "${REQ%.*}".nopasswd.key -passout file:"${REQ%.*}".passwd

        # Unlock cert private key
        if [ ! -s "${REQ%.*}.nopasswd.key" ] && [ -s "${REQ%.*}.passwd" ]; then
          KEY=$(mktemp ${TMPDIR}/XXXXXXXXXXXXXXXXXXX)
          RET_TXT=$(openssl ${algo_openssl} -out "${KEY}" -in "${REQ%.*}".key -passin file:"${REQ%.*}".passwd -passout pass:)
          RET_CODE=$?
          [ "${RET_CODE}" = '0' ] && ln -sfv "${KEY}" "${REQ%.*}.nopasswd.key"
        fi

        # public certificate variants
        [ -s "data/ca-chain.crt" ] && cat "data/issued/${BASENAME}.crt" "data/ca-chain.crt" > "${REQ%.*}".full.crt

        # private certificate variants
        if [ -s "${REQ%.*}.nopasswd.key" ]; then
          openssl pkcs12 -out "${REQ%.*}".p12 -export -inkey "${REQ%.*}.nopasswd.key" -in "data/issued/${BASENAME}.crt" -certfile "data/ca-chain.crt" -passout file:"${REQ%.*}".passwd "${REQ%.*}".p12
        fi

        # finishing
        echo "$RET_TXT" > "${REQ}.signed.txt"
        mv "${REQ}" "${REQ}.signed"
        rm -f "${REQ}.processing"
      done

      # # search for signed requests
      # for REQ_SIGNED in $(find "${REQS}/${TYPE}/${ALGO}/${REQUESTOR}" -type f -regex "^.*\.csr.signed$" -o -regex "^.*\.req.signed$"); do
      #   FILENAME_SIGNED="${REQ_SIGNED##*/}"
      #   FILENAME="${FILENAME_SIGNED%.*}"
      #   REQ="${REQ_SIGNED%/*}${FILENAME}"
      #   BASENAME="${REQUESTOR}-${FILENAME%.*}"
      #
      #   [ -s "${REQ%.*}".crt ] || continue # continue only when cert file still exists
      #
      #   #TODO: renew (almost) expired certificates
      # done

    done

  done
done

rm -rf "${TMPDIR}"
HOME="${CURRHOME}"
cd "${CURRDIR}"
exit 0
