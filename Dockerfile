FROM alpine

ARG SVC_USER
ARG SVC_USER_ID
ARG SVC_GROUP
ARG SVC_GROUP_ID
ARG SVC_HOME

ARG PKI_ROOTCA_CN
ARG PKI_CLIENTCA_CN
ARG PKI_CODECA_CN
ARG PKI_SERVERCA_CN
ARG PKI_REQ_COUNTRY
ARG PKI_REQ_PROVINCE
ARG PKI_REQ_CITY
ARG PKI_REQ_ORG
ARG PKI_REQ_EMAIL
ARG PKI_REQ_OU
# ARG CRT_CLIENT
# ARG CRT_CODE
# ARG CRT_SERVER

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
ENV PKI_SERVERCA_CN ${PKI_SERVERCA_CN:-Server Sub CA}
ENV PKI_SERVERCA_UNIQUE_SUBJECT ${PKI_SERVERCA_UNIQUE_SUBJECT:-no}

ENV PKI_REQ_COUNTRY	${PKI_REQ_COUNTRY}
ENV PKI_REQ_PROVINCE ${PKI_REQ_PROVINCE}
ENV PKI_REQ_CITY ${PKI_REQ_CITY}
ENV PKI_REQ_ORG	${PKI_REQ_ORG}
ENV PKI_REQ_EMAIL	${PKI_REQ_EMAIL:-pki@example.net}
ENV PKI_REQ_OU ${PKI_REQ_OU}
# ENV CRT_SERVER ${CRT_SERVER:-server-default-crt}
# ENV CRT_CLIENT ${CRT_CLIENT:-client-default-crt}
# ENV CRT_CODE ${CRT_CODE:-code-default-crt}

ENV PATH .:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

COPY ./src/harden.sh ./src/entry.sh /
COPY ./src/scripts/*.sh /usr/local/bin/
COPY ./src/pki/.gitignore ./src/pki/openssl-rootca.cnf ./src/pki/vars /pki.tmpl/
COPY ./src/pki/x509-types/ /pki.tmpl/x509-types/
COPY ./src/pki/client-ec-ca/ /pki.tmpl/client-ec-ca/
COPY ./src/pki/client-rsa-ca/ /pki.tmpl/client-rsa-ca/
COPY ./src/pki/code-ec-ca/ /pki.tmpl/code-ec-ca/
COPY ./src/pki/code-rsa-ca/ /pki.tmpl/code-rsa-ca/
COPY ./src/pki/server-ec-ca/ /pki.tmpl/server-ec-ca/
COPY ./src/pki/server-rsa-ca/ /pki.tmpl/server-rsa-ca/

RUN apk add --no-cache \
      dumb-init \
      easy-rsa \
      gettext \
      openssl \
      su-exec \
      jq \
    \
    && /harden.sh \
    && /entry.sh init

WORKDIR ${SVC_HOME}
VOLUME ${SVC_HOME}

ENTRYPOINT [ "/usr/bin/dumb-init", "--" ]
CMD [ "sh", "-c", "/entry.sh start ash -c 'trap : TERM INT; (while true; do /usr/local/bin/sign-requests.sh 2>&1 >/dev/null; sleep 10; done) & wait'" ]
