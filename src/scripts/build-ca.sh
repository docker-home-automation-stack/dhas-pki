#!/bin/sh -e

echo -e "\n\n\nNOW GENERATING NEW PKI\n======================\n"

echo "[Build PKI Audit] Printing script run parameters ..."
echo " $0 $@"

echo "[Build PKI Audit] Printing the script file itself ..."
echo "$(cat $0 | sed -e 's/^/     /')"

echo -e "\n\n[Build PKI Audit] Printing system environment details ..."
echo " uname: $(uname --all)"
echo " version: $(cat /proc/version)"
echo -e "release:\n$(cat /etc/*-release | sed -e 's/^/     /')"
echo " id: $(id)"
echo -e " environment:\n$(env | sed -e 's/^/     /')"
echo " date: $(date --utc)"
echo -e " cgroup:\n$(cat /proc/1/cgroup | sed -e 's/^/     /')"
echo " openssl: $(type openssl), $(openssl version)"

CURRHOME="${HOME}"
CURRDIR=$(pwd)

PKI_HOME=${PKI_HOME:-${SVC_HOME:-/pki}}
PKI_PASSWD=${PKI_PASSWD:-${PKI_HOME}.passwd}
PKI_TMPL=${PKI_TMPL:-${PKI_HOME}.tmpl}
HOME="${PKI_HOME}"
REQS="${PKI_HOME}/fifo"
umask 0077

echo -e "[Build PKI] General initialization ..."
mkdir -vp "${PKI_HOME}"
cd "${PKI_HOME}"
if [ -d "${PKI_TMPL}" ]; then
  cp -rfv "${PKI_TMPL}"/* ./
  cp -rfv "${PKI_TMPL}"/.gitignore ./

  if [ -e ./easyrsa ]; then
    rm -v easyrsa
    ln -sfv /pki.tmpl/easyrsa .
  else
    ln -sfv /usr/share/easy-rsa/easyrsa .
  fi
elif [ ! -e ./easyrsa ]; then
  ln -sfv /usr/share/easy-rsa/easyrsa .
fi

LIST="$(ls ${PKI_HOME}/ | grep -E "^.*-ca$" | grep ^root-)"
if [ "${LIST}" = '' ]; then
  echo "ERROR: ${PKI_HOME} does not contain any initial Root CA data structure"
  exit 1
fi

LIST="${LIST} $(ls ${PKI_HOME}/ | grep -E "^.*-ca$" | grep -v ^root-)"

for CA in ${LIST}; do
  type=$(echo "${CA}" | cut -d "-" -f 1)
  TYPE=$(echo "${type}" | tr '[:lower:]' '[:upper:]')
  algo=$(echo "${CA}" | cut -d "-" -f 2)
  algo_openssl=${algo}
  [ "${algo_openssl}" = 'ecc' ] && algo_openssl="ec"
  ALGO=$(echo "${algo}" | tr '[:lower:]' '[:upper:]')
  CN=$(eval "echo \${PKI_${TYPE}CA_CN:-$CA}")

  # Initialize CA
  echo -e "\n\n[Build PKI: ${CA}] Initializing ..."
  cd "${PKI_HOME}/${CA}"
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
  if [ -s "data/private/ca.key" ] && [ -z "$(cat data/private/ca.key | grep "Proc-Type: 4,ENCRYPTED")" ]; then
    echo -e "[Build PKI: ${CA}] Protecting private key using password from file '${PKI_PASSWD}/${type}-${algo}-ca.passwd' ..."
    [ ! -s "${PKI_PASSWD}/${type}-${algo}-ca.passwd" ] && pwgen -1sy 42 1 > "${PKI_PASSWD}/${type}-${algo}-ca.passwd"
    mv -v "data/private/ca.key" "data/private/ca.nopasswd.key"
    openssl ${algo_openssl} -out "data/private/ca.key" -aes256 -in "data/private/ca.nopasswd.key" -passout file:"${PKI_PASSWD}/${type}-${algo}-ca.passwd"
  fi
  if [ ! -s "data/private/ca.nopasswd.key" ]; then
    echo -e "[Build PKI: ${CA}] Creating unprotected keyfile using password from file '${PKI_PASSWD}/${type}-${algo}-ca.passwd' ..."
    if [ ! -s "${PKI_HOME}/${type}-${algo}-ca.passwd" ]; then
      echo -e "[Build PKI: ${CA}] ERROR - Private key is encrypted and password file was not found in ${PKI_HOME}/${type}-${algo}-ca.passwd"
      exit 1
    fi
    openssl ${algo_openssl} -out "data/private/ca.nopasswd.key" -aes256 -in "data/private/ca.key" -passin file:"${PKI_PASSWD}/${type}-${algo}-ca.passwd" -passout pass:
  fi

  # Sub CA specific only
  if [ "${type}" != 'root' ]; then

    # create DH file
    echo -e "[Build PKI: ${CA}] Creating Diffie-Hellman file ..."
    [ -s dh.pem ] && mv -fv dh.pem data/
    [ ! -s data/dh.pem ] && ./easyrsa --batch gen-dh

    # Sign Sub CA with Root CA
    echo -e "[Build PKI: ${CA}] Generating signed CA certificate with Root ${ALGO} CA ..."
    cd "${PKI_HOME}/root-${algo}-ca"
    ./easyrsa --batch import-req "${PKI_HOME}/${CA}/data/reqs/ca.req" "${CA}"
    ./easyrsa --batch sign-req ca "${CA}"
    cp -fv "data/issued/${CA}.crt" "${PKI_HOME}/${CA}/data/ca.crt"
    cat "data/issued/${CA}.crt" "data/ca.crt" > "${PKI_HOME}/${CA}/data/ca-chain.crt"

  fi

  cd "${PKI_HOME}/${CA}"

  # Create full CA bundle file in PKCS#12 format
  echo -e "[Build PKI: ${CA}] Generating full CA bundle file in PKCS#12 format ..."
  openssl pkcs12 -export -out "data/ca.p12" -inkey "data/private/ca.key" -in "data/ca.crt" -passin file:"${PKI_PASSWD}/${type}-${algo}-ca.passwd" -passout file:"${PKI_PASSWD}/${type}-${algo}-ca.passwd"

  # Create public certificate file variants
  echo -e "[Build PKI: ${CA}] Generating other public certificate file variants ..."
  openssl x509 -out "data/ca.der" -outform der -in "data/ca.crt"
  if [ "${type}" = 'root' ]; then
    openssl crl2pkcs7 -out "data/ca-bundle.der.p7b" -nocrl -outform der -certfile "data/ca.crt"
    openssl crl2pkcs7 -out "data/ca-bundle.pem.p7c" -nocrl -outform pem -certfile "data/ca.crt"
  else
    openssl crl2pkcs7 -out "data/ca-bundle.der.p7b" -nocrl -outform der -certfile "data/ca.crt" -certfile "${PKI_HOME}/root-${algo}-ca/data/ca.crt"
    openssl crl2pkcs7 -out "data/ca-bundle.pem.p7c" -nocrl -outform pem -certfile "data/ca.crt" -certfile "${PKI_HOME}/root-${algo}-ca/data/ca.crt"
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

HOME="${CURRHOME}"
cd "${CURRDIR}"
