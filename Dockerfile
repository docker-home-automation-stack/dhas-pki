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
COPY ./src/pki/* ./src/pki/server-rsa-ca/ ./src/pki/server-ec-ca/ ./src/pki/client-rsa-ca/ ./src/pki/client-ec-ca/ ${SVC_HOME}/

RUN apk add --no-cache \
      dumb-init \
      easy-rsa \
      su-exec \
      jq \
    \
    && ln -s /usr/share/easy-rsa/easyrsa /usr/bin/ \
    && /harden.sh \
    && /entry.sh init

WORKDIR ${SVC_HOME}
VOLUME ${SVC_HOME}

ENTRYPOINT [ "/usr/bin/dumb-init", "--" ]
CMD [ "sh", "-c", "/entry.sh start ash -c 'trap : TERM INT; (while true; do sleep 1000; done) & wait'" ]
