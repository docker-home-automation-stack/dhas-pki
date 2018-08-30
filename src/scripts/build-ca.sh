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

echo "hostname: $(hostname)"
echo "id: $(id)"
echo "date: $(date --utc)"
echo -e "cgroup:\n$(cat /proc/1/cgroup | sed -e 's/^/     /')"
echo "openssl: $(type openssl), $(openssl version)"

cd "${SVC_HOME}/root-ecc-ca"
ln -sf ../easyrsa .
./easyrsa --batch init-pki
./easyrsa --batch --req-cn="${PKI_ROOTCA_CN} (ECC)" build-ca nopass
pwgen -1sy 42 1 > "data/private/ca.passwd"
chmod 400 "data/private/ca.passwd"
openssl pkcs12 -export -out "data/private/ca.nopasswd.p12" -inkey "data/private/ca.key" -in "data/ca.crt" -passout pass:
chmod 400 "data/private/ca.nopasswd.p12"
openssl pkcs12 -export -out "data/ca.p12" -inkey "data/private/ca.key" -in "data/ca.crt" -passout file:data/private/ca.passwd
chmod 440 "data/ca.p12"
openssl x509 -out "data/ca.der" -outform der -in "data/ca.crt"
openssl crl2pkcs7 -out "data/ca-bundle.der.p7b" -nocrl -outform der -certfile "data/ca.crt"
openssl crl2pkcs7 -out "data/ca-bundle.pem.p7c" -nocrl -outform pem -certfile "data/ca.crt"
chmod 444 "data/ca.der" "data/ca-bundle.der.p7b" "data/ca-bundle.pem.p7c"
./easyrsa --batch --req-cn="${PKI_ROOTCA_CN} (ECC), OCSP Responder" gen-req ca-ocsp nopass
./easyrsa --batch sign-req ocsp-signing "ca-ocsp"
mkdir -p "${REQS}/root/ecc"
chmod 755 "${REQS}" "${REQS}/root"
chmod 710 "${REQS}/root/ecc"

cd "${SVC_HOME}/root-rsa-ca"
ln -sf ../easyrsa .
./easyrsa --batch init-pki
./easyrsa --batch --req-cn="${PKI_ROOTCA_CN} (RSA)" build-ca nopass
pwgen -1sy 42 1 > "data/private/ca.passwd"
chmod 400 "data/private/ca.passwd"
openssl pkcs12 -export -out "data/private/ca.nopasswd.p12" -inkey "data/private/ca.key" -in "data/ca.crt" -passout pass:
chmod 400 "data/private/ca.nopasswd.p12"
openssl pkcs12 -export -out "data/ca.p12" -inkey "data/private/ca.key" -in "data/ca.crt" -passout file:data/private/ca.passwd
chmod 440 "data/ca.p12"
openssl x509 -out "data/ca.der" -outform der -in "data/ca.crt"
openssl crl2pkcs7 -out "data/ca-bundle.der.p7b" -nocrl -outform der -certfile "data/ca.crt"
openssl crl2pkcs7 -out "data/ca-bundle.pem.p7c" -nocrl -outform pem -certfile "data/ca.crt"
chmod 444 "data/ca.der" "data/ca-bundle.der.p7b" "data/ca-bundle.pem.p7c"
./easyrsa --batch --req-cn="${PKI_ROOTCA_CN} (RSA), OCSP Responder" gen-req ca-ocsp nopass
./easyrsa --batch sign-req ocsp-signing "ca-ocsp"
mkdir -p "${REQS}/root/rsa"
chmod 755 "${REQS}" "${REQS}/root"
chmod 710 "${REQS}/root/rsa"

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
  cat "${SVC_HOME}/${SUBCA}/data/ca.crt" "data/ca.crt" > "${SVC_HOME}/${SUBCA}/data/ca-chain.crt"

  cd "${SVC_HOME}/${SUBCA}"

  # Create public certificate + private key file variants
  pwgen -1sy 42 1 > "data/private/ca.passwd"
  chmod 400 "data/private/ca.passwd"
  openssl pkcs12 -export -out "data/private/ca.nopasswd.p12" -inkey "data/private/ca.key" -in "data/ca.crt" -passout pass:
  chmod 400 "data/private/ca.nopasswd.p12"
  openssl pkcs12 -export -out "data/ca.p12" -inkey "data/private/ca.key" -in "data/ca.crt" -passout file:data/private/ca.passwd
  chmod 440 "data/ca.p12"

  # Create public certificate file variants
  openssl x509 -out "data/ca.der" -outform der -in "data/ca.crt"
  openssl crl2pkcs7 -out "data/ca-bundle.der.p7b" -nocrl -outform der -certfile "data/ca.crt" -certfile "${SVC_HOME}/root-${algo}-ca/data/ca.crt"
  openssl crl2pkcs7 -out "data/ca-bundle.pem.p7c" -nocrl -outform pem -certfile "data/ca.crt" -certfile "${SVC_HOME}/root-${algo}-ca/data/ca.crt"
  chmod 444 "data/ca.der" "data/ca-bundle.der.p7b" "data/ca-bundle.pem.p7c"

  # Create OCSP responder certificate
  ./easyrsa --batch --req-cn="${CN} (${ALGO}), OCSP Responder" gen-req ca-ocsp nopass
  ./easyrsa --batch sign-req ocsp-signing "ca-ocsp"

  # create fifo directory
  mkdir -p "${REQS}/${type}/${algo}"
  chown ${SVC_USER}:${SVC_GROUP} "${REQS}/${type}/${algo}"
  chmod 755 "${REQS}" "${REQS}/${type}"
  chmod 710 "${REQS}/${type}/${algo}"
done

cd "${SVC_HOME}"
