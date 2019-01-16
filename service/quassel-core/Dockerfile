FROM alpine:latest
MAINTAINER Frank Wang <eternnoir@gmail.com>

RUN apk update && apk --no-cache add quassel-core sqlite qt-sqlite

EXPOSE 4242
VOLUME [ "/var/lib/quassel" ]
ENTRYPOINT ["quasselcore", "--configdir=/var/lib/quassel"]
