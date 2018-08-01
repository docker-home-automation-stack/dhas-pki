FROM alpine

# Optional Configuration Parameter
ARG SERVICE_USER
ARG SERVICE_USER_ID
ARG SERVICE_GROUP
ARG SERVICE_GROUP_ID
ARG SERVICE_HOME

# Default Settings
ENV SERVICE_USER ${SERVICE_USER:-pki}
ENV SERVICE_USER_ID ${SERVICE_USER:-40443}
ENV SERVICE_GROUP ${SERVICE_USER:-pki}
ENV SERVICE_GROUP_ID ${SERVICE_USER:-40443}
ENV SERVICE_HOME ${SERVICE_HOME:-/${SERVICE_USER}}

COPY ./src/harden.sh /root
COPY ./src/vars ./src/openssl-easyrsa.cnf ${SERVICE_HOME}

RUN \
  mkdir -p ${SERVICE_HOME} && \
  adduser -h ${SERVICE_HOME} -s /sbin/nologin -u ${SERVICE_USER_ID} -D ${SERVICE_USER} && \
  chown -R ${SERVICE_USER}:${SERVICE_USER} ${SERVICE_HOME} && \
  \
  apk add --no-cache \
    dumb-init \
    easy-rsa \
    jq && \
  \
  /root/harden.sh

USER ${SERVICE_USER}
WORKDIR ${SERVICE_HOME}
VOLUME ${SERVICE_HOME}

ENTRYPOINT [ "/usr/bin/dumb-init", "--" ]
CMD [ "ash" ]
