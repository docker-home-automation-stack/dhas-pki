FROM alpine

RUN apk add --no-cache easy-rsa

CMD exec /bin/bash -c "trap : TERM INT; sleep infinity & wait"
