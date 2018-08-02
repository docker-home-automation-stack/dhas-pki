FROM alpine

ARG SVC_USER
ARG SVC_USER_ID
ARG SVC_GROUP
ARG SVC_GROUP_ID
ARG SVC_HOME

ENV SVC_USER ${SVC_USER:-pki}
ENV SVC_USER_ID ${SVC_USER_ID:-40443}
ENV SVC_GROUP ${SVC_USER:-pki}
ENV SVC_GROUP_ID ${SVC_GROUP_ID:-40443}
ENV SVC_HOME ${SVC_HOME:-/${SVC_USER}}

COPY ./src/harden.sh ./src/entry.sh /
COPY ./src/pki/easyrsa ./src/pki/openssl-rootca.cnf ./src/pki/vars /pki.tmpl/
COPY ./src/pki/x509-types/ /pki.tmpl/x509-types/
COPY ./src/pki/client-ec-ca/ /pki.tmpl/client-ec-ca/
COPY ./src/pki/client-rsa-ca/ /pki.tmpl/client-rsa-ca/
COPY ./src/pki/server-ec-ca/ /pki.tmpl/server-ec-ca/
COPY ./src/pki/server-rsa-ca/ /pki.tmpl/server-rsa-ca/

RUN apk add --no-cache \
      dumb-init \
      su-exec \
      jq \
    \
    && /harden.sh \
    && /entry.sh init

WORKDIR ${SVC_HOME}
VOLUME ${SVC_HOME}

ENTRYPOINT [ "/usr/bin/dumb-init", "--" ]
CMD [ "sh", "-c", "/entry.sh start ash -c 'trap : TERM INT; (while true; do sleep 1000; done) & wait'" ]
