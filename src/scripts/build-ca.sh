#!/bin/sh

echo -e "\n\n\nNOW GENERATING NEW PKI\n=====================\n"

echo "[Build PKI Audit] Printing script run parameters ..."
echo "$0 $@"

echo "[Build PKI Audit] Printing the script file itself ..."
echo "$(cat $0 | sed -e 's/^/     /')"

echo -e "\n\n[Build PKI Audit] Printing system environment details ..."
echo "uname: $(uname --all)"
echo "version: $(cat /proc/version)"
echo -e "release:\n$(cat /etc/*-release | sed -e 's/^/     /')"
echo "id: $(id)"
echo -e "environment:\n$(env | sed -e 's/^/     /')"
echo "date: $(date --utc)"
echo -e "cgroup:\n$(cat /proc/1/cgroup | sed -e 's/^/     /')"
echo "openssl: $(type openssl), $(openssl version)"

HOME="${SVC_HOME}"
REQS="${SVC_HOME}/fifo"
umask 0077

cd "${SVC_HOME}"

echo -e "[Build PKI] General initialization ..."
cp -rfv /pki.tmpl/* ./
cp -rfv /pki.tmpl/.gitignore ./

if [ -s ./easyrsa ]; then
  rm -v easyrsa
  ln -sfv /pki.tmpl/easyrsa .
else
  ln -sfv /usr/share/easy-rsa/easyrsa .
fi

LIST="$(ls ${SVC_HOME}/ | grep -E "^.*-ca$" | grep root-)"
LIST="${LIST} $(ls ${SVC_HOME}/ | grep -E "^.*-ca$" | grep -v root-)"

for CA in ${LIST}; do
  type=$(echo "${CA}" | cut -d "-" -f 1)
  TYPE=$(echo "${type}" | tr '[:lower:]' '[:upper:]')
  algo=$(echo "${CA}" | cut -d "-" -f 2)
  algo_openssl=${algo}
  [ "${algo_openssl}" = 'ecc' ] && algo_openssl="ec"
  ALGO=$(echo "${algo}" | tr '[:lower:]' '[:upper:]')
  CN=$(eval "echo \${PKI_${TYPE}CA_CN:-$CA}")

  # Initialize CA
  echo -e "[Build PKI: ${CA}] Initializing ..."
  cd "${SVC_HOME}/${CA}"
  ln -sfv ../easyrsa .
  ./easyrsa --batch init-pki

  # If Root CA, create CA with self-signed certificate
  if [ "${type}" = 'root' ]; then
    echo -e "[Build PKI: ${CA}] Creating CA private key and self-signed certificate ..."
    ./easyrsa --batch --req-cn="${CN} (${ALGO})" build-ca nopass

  # If Sub CA, create CA private key and signing request
  else
    echo -e "[Build PKI: ${CA}] Creating CA private key and certificate signing request ..."
    ./easyrsa --batch --req-cn="${CN} (${ALGO})" --subca-len=0 build-ca nopass subca
  fi


  # Encrypt private key with password
  echo -e "[Build PKI: ${CA}] Protecting private key with password in data/private/ca.passwd ..."
  [ -s "${SVC_HOME}/${type}-${algo}-ca.passwd" ] && mv -f "${SVC_HOME}/${type}-${algo}-ca.passwd" "data/private/ca.passwd" || pwgen -1sy 42 1 > "data/private/ca.passwd"
  openssl ${algo_openssl} -out "data/private/ca.key" -aes256 -in "data/private/ca.nopasswd.key" -passout file:data/private/ca.passwd

  # Sub CA specific only
  if [ "${type}" != 'root' ]; then

    # create DH file
    echo -e "[Build PKI: ${CA}] Creating Diffie-Hellman file ..."
    [ -s dh.pem ] && mv -fv dh.pem data/
    [ ! -s data/dh.pem ] && ./easyrsa --batch gen-dh

    # Sign Sub CA with Root CA
    echo -e "[Build PKI: ${CA}] Generating signed CA certificate with Root ${ALGO} CA ..."
    cd "${SVC_HOME}/root-${algo}-ca"
    ./easyrsa --batch import-req "${SVC_HOME}/${CA}/data/reqs/ca.req" "${CA}"
    ./easyrsa --batch sign-req ca "${CA}"
    cp -fv "data/issued/${CA}.crt" "${SVC_HOME}/${CA}/data/ca.crt"
    cat "data/issued/${CA}.crt" "data/ca.crt" > "${SVC_HOME}/${CA}/data/ca-chain.crt"

  fi

  cd "${SVC_HOME}/${CA}"

  # Create PKCS#12 public certificate + private key file variants
  echo -e "[Build PKI: ${CA}] Generating CA file in PKCS#12 format ..."
  openssl pkcs12 -export -out "data/private/ca.nopasswd.p12" -inkey "data/private/ca.nopasswd.key" -in "data/ca.crt" -passout pass:
  openssl pkcs12 -export -out "data/ca.p12" -inkey "data/private/ca.nopasswd.key" -in "data/ca.crt" -passout file:data/private/ca.passwd

  # Create public certificate file variants
  echo -e "[Build PKI: ${CA}] Generating other public certificate file variants ..."
  openssl x509 -out "data/ca.der" -outform der -in "data/ca.crt"
  if [ "${type}" = 'root' ]; then
    openssl crl2pkcs7 -out "data/ca-bundle.der.p7b" -nocrl -outform der -certfile "data/ca.crt"
    openssl crl2pkcs7 -out "data/ca-bundle.pem.p7c" -nocrl -outform pem -certfile "data/ca.crt"
  else
    openssl crl2pkcs7 -out "data/ca-bundle.der.p7b" -nocrl -outform der -certfile "data/ca.crt" -certfile "${SVC_HOME}/root-${algo}-ca/data/ca.crt"
    openssl crl2pkcs7 -out "data/ca-bundle.pem.p7c" -nocrl -outform pem -certfile "data/ca.crt" -certfile "${SVC_HOME}/root-${algo}-ca/data/ca.crt"
  fi

  # Create OCSP responder certificate
  echo -e "[Build PKI: ${CA}] Generating OCSP responder private key and signing request ..."
  ./easyrsa --batch --req-cn="${CN} (${ALGO}), OCSP Responder" gen-req ca-ocsp nopass
  echo -e "[Build PKI: ${CA}] Generating signed OCSP Responder certificate ..."
  ./easyrsa --batch sign-req ocsp-signing "ca-ocsp"

  # create fifo directory
  echo -e "[Build PKI: ${CA}] Creating file exchange directory for automated sign request handling ..."
  mkdir -pv "${REQS}/${type}/${algo}"
done

cd "${SVC_HOME}"
