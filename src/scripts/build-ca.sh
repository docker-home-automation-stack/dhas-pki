#!/bin/sh

HOME="${SVC_HOME}"
REQS="${SVC_HOME}/fifo"

cd "${SVC_HOME}"

cp -r /pki.tmpl/* ./
cp -r /pki.tmpl/.gitignore ./

if [ -s ./easyrsa ]; then
  rm easyrsa
  ln -sf /pki.tmpl/easyrsa .
else
  ln -sf /usr/share/easy-rsa/easyrsa .
fi

cd "${SVC_HOME}/root-ecc-ca"
ln -sf ../easyrsa .
./easyrsa --batch init-pki
./easyrsa --batch --req-cn="${PKI_ROOTCA_CN} (ECC)" build-ca nopass
./easyrsa --batch gen-crl

cd "${SVC_HOME}/root-rsa-ca"
ln -sf ../easyrsa .
./easyrsa --batch init-pki
./easyrsa --batch --req-cn="${PKI_ROOTCA_CN} (RSA)" build-ca nopass
./easyrsa --batch gen-crl

for SUBCA in $(ls ${SVC_HOME}/ | grep -E "^.*-ca$" | grep -v root-); do
  type=$(echo "${SUBCA}" | cut -d "-" -f 1)
  TYPE=$(echo "${type}" | tr '[:lower:]' '[:upper:]')
  algo=$(echo "${SUBCA}" | cut -d "-" -f 2)
  ALGO=$(echo "${algo}" | tr '[:lower:]' '[:upper:]')
  CN=$(eval "echo \${PKI_${TYPE}CA_CN:-$SUBCA}")

  # create CA and signing request
  cd "${SVC_HOME}/${SUBCA}"
  ln -sf ../easyrsa .
  ./easyrsa --batch init-pki
  ./easyrsa --batch --req-cn="${CN} (${ALGO})" --subca-len=0 build-ca nopass subca
  [ -s dh.pem ] && mv dh.pem data/
  [ ! -s data/dh.pem ] && ./easyrsa --batch gen-dh
  chmod 444 data/dh.pem

  # sign Sub CA with Root CA
  cd "${SVC_HOME}/root-${algo}-ca"
  ./easyrsa --batch import-req "${SVC_HOME}/${SUBCA}/data/reqs/ca.req" "${SUBCA}"
  ./easyrsa --batch sign-req ca "${SUBCA}"
  cp "data/issued/${SUBCA}.crt" "${SVC_HOME}/${SUBCA}/data/ca.crt"
  openssl x509 -in "${SVC_HOME}/${SUBCA}/data/ca.crt" -out "${SVC_HOME}/${SUBCA}/data/ca.der" -outform der
  cat "${SVC_HOME}/${SUBCA}/data/ca.crt" "data/ca.crt" > "${SVC_HOME}/${SUBCA}/data/ca-chain.crt"

  # Generate CRL for Sub CA
  cd "${SVC_HOME}/${SUBCA}"
  ./easyrsa --batch gen-crl
  openssl crl -in crl.pem -out crl.der -outform der

  # create fifo directory
  mkdir -p "${REQS}/${type}/${algo}"
  chown ${PKI_USER}:${PKI_GROUP} "${REQS}/${type}/${algo}"
  chmod 755 "${REQS}" "${REQS}/${type}"
  chmod 710 "${REQS}/${type}/${algo}"
done

cd "${SVC_HOME}"
