FROM alpine

RUN apk add --no-cache \
      bash \
      easy-rsa

VOLUME ["/root-ca"]
VOLUME ["/server-ca"]

CMD exec /bin/bash -c "trap : TERM INT; sleep infinity & wait"
