#!/bin/sh -e
. /etc/profile
PATH=".:${PATH}"

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
mkdir -vp "${PKI_HOME}" "${PKI_PASSWD}"
cd "${PKI_HOME}"
if [ -d "${PKI_TMPL}" ]; then
  set +e
  cp -rfv "${PKI_TMPL}"/* ./
  cp -rfv "${PKI_TMPL}"/.gitignore ./
  set -e

  if [ -e ./easyrsa ]; then
    rm -v easyrsa
    ln -sfv /pki.tmpl/easyrsa .
  else
    ln -sfv /usr/share/easy-rsa/easyrsa .
  fi
elif [ ! -e ./easyrsa ]; then
  ln -sfv /usr/share/easy-rsa/easyrsa .
fi

LIST_ROOT="$(ls ${PKI_HOME}/ | grep -E "^.*-ca$" | grep ^root-)"
if [ "${LIST_ROOT}" = '' ]; then
  echo "ERROR: ${PKI_HOME} does not contain any initial Root CA data structure"
  exit 1
fi

LIST="${LIST_ROOT} $(ls ${PKI_HOME}/ | grep -E "^.*-ca$" | grep -v ^root-)"
TMPDIR="$(mktemp -d /dev/shm/XXXXXXXXXXXXXXXXXXX)"

for CA in ${LIST}; do
  type=$(echo "${CA}" | cut -d "-" -f 1)
  TYPE=$(echo "${type}" | tr '[:lower:]' '[:upper:]')
  algo=$(echo "${CA}" | cut -d "-" -f 2)
  algo_openssl=${algo}
  [ "${algo_openssl}" = 'ecc' ] && algo_openssl="ec"
  ALGO=$(echo "${algo}" | tr '[:lower:]' '[:upper:]')
  CN=$(eval "echo \${PKI_${TYPE}CA_CN:-$CA}")
  DIR="${PKI_HOME}/${CA}"

  # Initialize CA
  echo -e "\n\n[Build PKI: ${CA}] Initializing ..."
  cd "${DIR}"
  ln -sfv ../easyrsa .
  ./easyrsa --batch init-pki

  # If Root CA, create CA with self-signed certificate
  if [ "${type}" = 'root' ]; then
    echo -e "[Build PKI: ${CA}] Creating CA private key and self-signed certificate ..."
    ./easyrsa --batch --req-cn="${CN} (${ALGO})" build-ca nopass

    # #TODO ... and cross-sign Root RSA CA with ECC CA
    # if [ "${ALGO}" = 'RSA' ]; then
    #   echo -e "[Build PKI: ${CA}] Cross-signing with Root ECC CA ..."
    #   openssl req -utf8 -new -key data/private/ca.key -out data/reqs/root-ecc-ca.req
    #   cd "${PKI_HOME}"/root-ecc-ca
    #
    #   cd "${DIR}"
    # fi

  # If Sub CA, create CA private key and signing request
  else
    echo -e "[Build PKI: ${CA}] Creating CA private key and certificate signing request ..."
    ./easyrsa --batch --req-cn="${CN} (${ALGO})" --subca-len=0 build-ca nopass subca
  fi

  # Encrypt CA private key with password
  if [ -s "data/private/ca.key" ] && [ -z "$(cat data/private/ca.key | grep "Proc-Type: 4,ENCRYPTED")" ]; then
    echo -e "[Build PKI: ${CA}] Protecting private key using password from file '${PKI_PASSWD}/${CA}/${CA}.passwd' ..."
    [ ! -s "${PKI_PASSWD}/${CA}/${CA}.passwd" ] && mkdir -pv "${PKI_PASSWD}/${CA}" && pwgen -1sy 42 1 > "${PKI_PASSWD}/${CA}/${CA}.passwd"
    CA_KEY=$(mktemp ${TMPDIR}/XXXXXXXXXXXXXXXXXXX)
    cat "data/private/ca.key" > "${CA_KEY}" # copy unencrypted key into memory
    rm -v "data/private/ca.key" #TODO: this should be srm or shred or something similar to delete securely
    openssl ${algo_openssl} -out "data/private/ca.key" -aes256 -in "${CA_KEY}" -passout file:"${PKI_PASSWD}/${CA}/${CA}.passwd"
    ln -sfv "${CA_KEY}" "data/private/ca.nopasswd.key"
  fi

  # Unlock CA private key
  if [ ! -s "data/private/ca.nopasswd.key" ]; then
    echo -e "[Build PKI: ${CA}] Creating unprotected key file using password from file '${PKI_PASSWD}/${CA}/${CA}.passwd' ..."
    if [ ! -s "${PKI_PASSWD}/${CA}/${CA}.passwd" ]; then
      echo -e "[Build PKI: ${CA}] ERROR - Private key is encrypted and password file was not found in ${PKI_PASSWD}/${CA}/${CA}.passwd"
      exit 1
    fi
    CA_KEY=$(mktemp ${TMPDIR}/XXXXXXXXXXXXXXXXXXX)
    openssl ${algo_openssl} -out "${CA_KEY}" -in "data/private/ca.key" -passin file:"${PKI_PASSWD}/${CA}/${CA}.passwd" -passout pass:
    ln -sfv "${CA_KEY}" "data/private/ca.nopasswd.key" # use unencrypted key from memory
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
    ./easyrsa --batch import-req "${DIR}/data/reqs/ca.req" "${CA}"
    ./easyrsa --batch sign-req ca "${CA}"
    cp -fv "data/issued/${CA}.crt" "${DIR}/data/ca.crt"
    cat "data/issued/${CA}.crt" "data/ca.crt" > "${DIR}/data/ca-chain.crt"

  fi

  cd "${DIR}"

  # Create full CA bundle file in PKCS#12 format
  echo -e "[Build PKI: ${CA}] Generating full CA bundle file in PKCS#12 format ..."
  if [ "${type}" = 'root' ]; then
    openssl pkcs12 -out "data/private/ca.p12" -export -inkey "data/private/ca.nopasswd.key" -in "data/ca.crt" -passout file:"${PKI_PASSWD}/${CA}/${CA}.passwd"
  else
    openssl pkcs12 -out "data/private/ca.p12" -export -inkey "data/private/ca.nopasswd.key" -in "data/ca.crt" -certfile "${PKI_HOME}/root-${algo}-ca/data/ca.crt" -passout file:"${PKI_PASSWD}/${CA}/${CA}.passwd"
  fi

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

echo -e "[Build PKI] Cleaning up temp dir from memory ..."
rm -rfv "${TMPDIR}"

HOME="${CURRHOME}"
cd "${CURRDIR}"
exit 0
