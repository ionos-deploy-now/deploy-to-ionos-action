FROM alpine:3.11

RUN set -ex \
  && apk add --no-cache rsync sshpass openssh-client jq httpie pwgen coreutils

COPY entrypoint.sh /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
