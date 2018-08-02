#!/bin/sh

PKI_NAME="House Automation"

cd "${SVC_HOME}"
./easyrsa --batch init-pki
./easyrsa --batch --req-cn="${PKI_NAME} Cerficiate Authority" --subca-len=1 build-ca nopass
[ -s dh.pem ] && cp dh.pem data/ || ./easyrsa --batch gen-dh
chmod 444 "data/ca.crt" "data/dh.pem"

for SUBCA in $(ls ${SVC_HOME}/ | grep -E "^.*-ca$"); do
  cd "${SVC_HOME}/${SUBCA}"
  ln -sf ../easyrsa .
  ./easyrsa --batch init-pki
  ./easyrsa --batch --req-cn="${PKI_NAME} Sub CA: ${SUBCA}" --subca-len=0 build-ca nopass subca
  [ -s dh.pem ] && cp dh.pem data/ || ./easyrsa --batch gen-dh
  chmod 444 "data/dh.pem"
  
  cd "${SVC_HOME}"
  ./easyrsa --batch import-req "${SUBCA}/data/req/ca.req" "${SUBCA}"
  ./easyrsa --batch sign-req ca "${SUBCA}"
  cp "data/issued/${SUBCA}.crt" "${SUBCA}/data/ca.crt"
  chmod 444 "${SUBCA}/data/ca.crt"
done

cd "${SVC_HOME}"
