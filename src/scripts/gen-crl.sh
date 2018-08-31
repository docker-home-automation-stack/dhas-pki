#!/bin/sh

CURRHOME="${HOME}"
CURRDIR=$(pwd)

PKI_HOME=${PKI_HOME:-${SVC_HOME:-/pki}}
PKI_PASSWD=${PKI_PASSWD:-${PKI_HOME}.passwd}
PKI_TMPL=${PKI_TMPL:-${PKI_HOME}.tmpl}
HOME="${PKI_HOME}"
REQS="${PKI_HOME}/fifo"
umask 0033

TMPDIR="$(mktemp -d /dev/shm/XXXXXXXXXXXXXXXXXXX)"
TYPE=$1
ALGO=$2
algo_openssl=${ALGO}
[ "${algo_openssl}" = 'ecc' ] && algo_openssl="ec"

[ "${TYPE}" = 'root' ] && [ $(id -u) != 0 ] && exit 1

# re-generate CRL every 3 days with 6 days validity
# to allow overlap period
cd "${SVC_HOME}/${TYPE}-${ALGO}-ca"
if [ -s data/crl.pem ]; then
  nextUpdate=$(date --date="$(openssl crl -in data/crl.pem -noout -nextupdate | cut -d = -f 2)" '+%s')
  dateNow=$(date +"%s")
  delta=$(( $nextUpdate - $dateNow ))
else
  delta=0
fi
if [ $delta -le 259200 ]; then
  echo "Re-generating CRL for ${TYPE}-${ALGO}-ca"

  # Unlock CA private key
  if [ ! -s "data/private/ca.nopasswd.key" ] && [ -s "${PKI_PASSWD}/${TYPE}-${ALGO}-ca/${TYPE}-${ALGO}-ca.passwd" ]; then
    echo " - unlocking CA private key"
    CA_KEY=$(mktemp ${TMPDIR}/XXXXXXXXXXXXXXXXXXX)
    openssl ${algo_openssl} -out "${CA_KEY}" -in "data/private/ca.key" -passin file:"${PKI_PASSWD}/${TYPE}-${ALGO}-ca/${TYPE}-${ALGO}-ca.passwd" -passout pass:
    ln -sfv "${CA_KEY}" "data/private/ca.nopasswd.key" # use unencrypted key from memory
  fi

  ./easyrsa --batch gen-crl
  openssl crl -in data/crl.pem -out data/crl.der -outform der
fi

rm -rfv "${TMPDIR}"
exit 0
