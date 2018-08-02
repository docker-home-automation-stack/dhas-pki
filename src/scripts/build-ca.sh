#!/bin/sh

HOME="${SVC_HOME}"

cd "${SVC_HOME}"
ln -sf /usr/share/easy-rsa/easyrsa .
./easyrsa --batch init-pki
./easyrsa --batch --req-cn="${PKI_CN_ROOT}" build-ca nopass

for SUBCA in $(ls ${SVC_HOME}/ | grep -E "^.*-ca$"); do
  TYPE=$(echo "${SUBCA}" | cut -d "-" -f 1 | tr '[:lower:]' '[:upper:]')
  ALGO=$(echo "${SUBCA}" | cut -d "-" -f 2 | tr '[:lower:]' '[:upper:]')
  CN=$(eval "echo \${PKI_CN_$TYPE:-$SUBCA}")

  cd "${SVC_HOME}/${SUBCA}"
  ln -sf /usr/share/easy-rsa/easyrsa .
  ./easyrsa --batch init-pki
  ./easyrsa --batch --req-cn="${CN} (${ALGO})" --subca-len=0 build-ca nopass subca
  [ -s dh.pem ] && cp dh.pem data/ || ./easyrsa --batch gen-dh
  chmod 444 "data/dh.pem"

  cd "${SVC_HOME}"
  ./easyrsa --batch import-req "${SUBCA}/data/reqs/ca.req" "${SUBCA}"
  ./easyrsa --batch sign-req ca "${SUBCA}"
  #cp "data/issued/${SUBCA}.crt" "${SUBCA}/data/ca.crt"
  #cat "data/ca.crt" "${SUBCA}/data/ca.crt" > "${SUBCA}/data/ca-chain.crt"
  #chmod 444 "${SUBCA}/data/ca.crt" "${SUBCA}/data/ca-chain.crt"
  cat "data/ca.crt" "data/issued/${SUBCA}.crt" > "${SUBCA}/data/ca.crt"
  chmod 444 "${SUBCA}/data/ca.crt"
done

cd "${SVC_HOME}"
