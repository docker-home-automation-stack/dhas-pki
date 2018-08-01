FROM alpine

RUN apk add --no-cache \
      easy-rsa \
      jq

VOLUME ["/root-ca"]
VOLUME ["/server-ca"]

CMD exec /bin/sh -c "trap : TERM INT; (while true; do sleep 1000; done) & wait"
