FROM alpine

ARG SVC_USER
ARG SVC_USER_ID
ARG SVC_GROUP
ARG SVC_GROUP_ID
ARG SVC_HOME

ENV SVC_USER ${SVC_USER:-pki}
ENV SVC_USER_ID ${SVC_USER:-40443}
ENV SVC_GROUP ${SVC_USER:-pki}
ENV SVC_GROUP_ID ${SVC_USER:-40443}
ENV SVC_HOME ${SVC_HOME:-/${SVC_USER}}

COPY ./src/entry.sh ./src/harden.sh /
COPY ./src/vars ./src/openssl-easyrsa.cnf ${SVC_HOME}

RUN apk add --no-cache \
      dumb-init \
      easy-rsa \
      su-exec \
      tini \
      jq && \
    \
    /harden.sh

USER ${SVC_USER}
WORKDIR ${SVC_HOME}
VOLUME ${SVC_HOME}

ENTRYPOINT [ "/sbin/tini", "--", "/entry.sh" ]
CMD ["start", "${SVC_USER}", "${SVC_USER_ID}", "${SVC_GROUP}", "${SVC_GROUP_ID}", "${SVC_HOME}", "ash", "-c", "trap : TERM INT; (while true; do sleep 1000; done) & wait"]
