#!/bin/sh

HOME="${SVC_HOME}"

cd "${SVC_HOME}"

cp -r /pki.tmpl/* ./

if [ -s ./easyrsa ]; then
  rm easyrsa
  ln -sf /pki.tmpl/easyrsa .
else
  ln -sf /usr/share/easy-rsa/easyrsa .
fi
./easyrsa --batch init-pki
./easyrsa --batch --req-cn="${PKI_ROOTCA_CN}" build-ca nopass

for SUBCA in $(ls ${SVC_HOME}/ | grep -E "^.*-ca$"); do
  TYPE=$(echo "${SUBCA}" | cut -d "-" -f 1 | tr '[:lower:]' '[:upper:]')
  ALGO=$(echo "${SUBCA}" | cut -d "-" -f 2 | tr '[:lower:]' '[:upper:]')
  CN=$(eval "echo \${PKI_${TYPE}CA_CN:-$SUBCA}")

  cd "${SVC_HOME}/${SUBCA}"
  ln -sf ../easyrsa .
  ./easyrsa --batch init-pki
  ./easyrsa --batch --req-cn="${CN} (${ALGO})" --subca-len=0 build-ca nopass subca
  [ -s dh.pem ] && cp dh.pem data/ || ./easyrsa --batch gen-dh

  cd "${SVC_HOME}"
  ./easyrsa --batch import-req "${SUBCA}/data/reqs/ca.req" "${SUBCA}"
  ./easyrsa --batch sign-req ca "${SUBCA}"
  cp "data/issued/${SUBCA}.crt" "${SUBCA}/data/ca.crt"
  cat "${SUBCA}/data/ca.crt" "data/ca.crt" > "${SUBCA}/data/ca-chain.crt"
done

cd "${SVC_HOME}"
