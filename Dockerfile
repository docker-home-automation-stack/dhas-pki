FROM alpine

ARG SVC_USER
ARG SVC_USER_ID
ARG SVC_GROUP
ARG SVC_GROUP_ID
ARG SVC_HOME

ARG PKI_ROOTCA_CN
ARG PKI_CLIENTCA_CN
ARG PKI_CODECA_CN
ARG PKI_EMAILCA_CN
ARG PKI_SERVERCA_CN
ARG PKI_SERVERCA_CRT_0

ARG PKI_CRL_BASEURLS
ARG PKI_OCSP_BASEURLS

ARG PKI_REQ_COUNTRY
ARG PKI_REQ_PROVINCE
ARG PKI_REQ_CITY
ARG PKI_REQ_ORG
ARG PKI_REQ_EMAIL
ARG PKI_REQ_OU

ENV SVC_USER ${SVC_USER:-pki}
ENV SVC_USER_ID ${SVC_USER_ID:-40443}
ENV SVC_GROUP ${SVC_USER:-pki}
ENV SVC_GROUP_ID ${SVC_GROUP_ID:-40443}
ENV SVC_HOME ${SVC_HOME:-/${SVC_USER}}

ENV PKI_ROOTCA_CN ${PKI_ROOTCA_CN:-Root Certificate Authority}
ENV PKI_ROOTCA_UNIQUE_SUBJECT ${PKI_ROOTCA_UNIQUE_SUBJECT:-yes}
ENV PKI_CLIENTCA_CN ${PKI_CLIENTCA_CN:-Client Sub CA}
ENV PKI_CLIENTCA_UNIQUE_SUBJECT ${PKI_CLIENTCA_UNIQUE_SUBJECT:-no}
ENV PKI_CODECA_CN ${PKI_CODECA_CN:-Code Signing Sub CA}
ENV PKI_CODECA_UNIQUE_SUBJECT ${PKI_CODECA_UNIQUE_SUBJECT:-no}
ENV PKI_EMAILCA_CN ${PKI_SERVERCA_CN:-Email Sub CA}
ENV PKI_EMAILCA_UNIQUE_SUBJECT ${PKI_SERVERCA_UNIQUE_SUBJECT:-no}
ENV PKI_SERVERCA_CN ${PKI_SERVERCA_CN:-Server Sub CA}
ENV PKI_SERVERCA_UNIQUE_SUBJECT ${PKI_SERVERCA_UNIQUE_SUBJECT:-no}
ENV PKI_SERVERCA_CRT_0 ${PKI_SERVERCA_CRT_0:-server1:DNS:*.server.lan,DNS:server.lan}

ENV PKI_CRL_BASEURLS ${PKI_CRL_BASEURLS:-http://server.lan/pki/,http://example.com/pki/}
ENV PKI_OCSP_BASEURLS ${PKI_OCSP_BASEURLS:-http://server.lan/ocsp/,http://example.com/ocsp/}

ENV PKI_REQ_COUNTRY	${PKI_REQ_COUNTRY}
ENV PKI_REQ_PROVINCE ${PKI_REQ_PROVINCE}
ENV PKI_REQ_CITY ${PKI_REQ_CITY}
ENV PKI_REQ_ORG	${PKI_REQ_ORG}
ENV PKI_REQ_EMAIL	${PKI_REQ_EMAIL}
ENV PKI_REQ_OU ${PKI_REQ_OU}

ENV PATH .:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

COPY ./src/harden.sh ./src/entry.sh /
COPY ./src/scripts/*.sh /usr/local/bin/
COPY ./src/easyrsa ./src/pki/.gitignore /pki.tmpl/
COPY ./src/pki/root-ecc-ca/ /pki.tmpl/root-ecc-ca/
COPY ./src/pki/root-rsa-ca/ /pki.tmpl/root-rsa-ca/
COPY ./src/pki/client-ecc-ca/ /pki.tmpl/client-ecc-ca/
COPY ./src/pki/client-rsa-ca/ /pki.tmpl/client-rsa-ca/
COPY ./src/pki/code-ecc-ca/ /pki.tmpl/code-ecc-ca/
COPY ./src/pki/code-rsa-ca/ /pki.tmpl/code-rsa-ca/
COPY ./src/pki/email-ecc-ca/ /pki.tmpl/email-ecc-ca/
COPY ./src/pki/email-rsa-ca/ /pki.tmpl/email-rsa-ca/
COPY ./src/pki/server-ecc-ca/ /pki.tmpl/server-ecc-ca/
COPY ./src/pki/server-rsa-ca/ /pki.tmpl/server-rsa-ca/

RUN apk add --no-cache \
      coreutils \
      dumb-init \
      easy-rsa \
      gettext \
      openssl \
      pwgen \
      su-exec \
      sudo \
      jq \
    \
    && /harden.sh \
    && /entry.sh init

WORKDIR ${SVC_HOME}
VOLUME ${SVC_HOME}

ENTRYPOINT [ "/usr/bin/dumb-init", "--" ]
CMD [ "sh", "-c", "/entry.sh start ash -c 'trap : TERM INT; (while true; do /usr/local/bin/sign-requests.sh 2>&1 >/dev/null; sleep 10; done) & wait'" ]
