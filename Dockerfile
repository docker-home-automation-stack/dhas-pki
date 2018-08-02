FROM alpine

ARG SVC_USER
ARG SVC_USER_ID
ARG SVC_GROUP
ARG SVC_GROUP_ID
ARG SVC_HOME

ARG PKI_CN_ROOT
ARG PKI_CN_SERVER
ARG PKI_CN_CLIENT
ARG PKI_CN_CODE
ARG PKI_REQ_COUNTRY
ARG PKI_REQ_PROVINCE
ARG PKI_REQ_CITY
ARG PKI_REQ_ORG
ARG PKI_REQ_EMAIL
ARG PKI_REQ_OU
ARG CRT_SERVER
ARG CRT_CLIENT
ARG CRT_CODE

ENV SVC_USER ${SVC_USER:-pki}
ENV SVC_USER_ID ${SVC_USER_ID:-40443}
ENV SVC_GROUP ${SVC_USER:-pki}
ENV SVC_GROUP_ID ${SVC_GROUP_ID:-40443}
ENV SVC_HOME ${SVC_HOME:-/${SVC_USER}}

ENV PKI_CN_ROOT ${PKI_CN_ROOT:-Root Certificate Authority}
ENV PKI_CN_SERVER ${PKI_CN_SERVER:-Server Sub CA}
ENV PKI_CN_CLIENT ${PKI_CN_CLIENT:-Client Sub CA}
ENV PKI_CN_CODE ${PKI_CN_CODE:-Code Signing Sub CA}
ENV PKI_REQ_COUNTRY	${PKI_REQ_COUNTRY}
ENV PKI_REQ_PROVINCE ${PKI_REQ_PROVINCE}
ENV PKI_REQ_CITY ${PKI_REQ_CITY}
ENV PKI_REQ_ORG	${PKI_REQ_ORG}
ENV PKI_REQ_EMAIL	${PKI_REQ_EMAIL:-pki@example.net}
ENV PKI_REQ_OU ${PKI_REQ_OU}
ENV CRT_SERVER ${CRT_SERVER:-server-default-crt}
ENV CRT_CLIENT ${CRT_CLIENT:-client-default-crt}
ENV CRT_CODE ${CRT_CODE:-code-default-crt}

ENV PATH .:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

COPY ./src/harden.sh ./src/entry.sh /
COPY ./src/scripts/*.sh /usr/local/bin/
COPY ./src/pki/openssl-rootca.cnf ./src/pki/vars /pki.tmpl/
COPY ./src/pki/x509-types/ /pki.tmpl/x509-types/
COPY ./src/pki/client-ec-ca/ /pki.tmpl/client-ec-ca/
COPY ./src/pki/client-rsa-ca/ /pki.tmpl/client-rsa-ca/
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
CMD [ "sh", "-c", "/entry.sh start ash -c 'trap : TERM INT; (while true; do sleep 1000; done) & wait'" ]
