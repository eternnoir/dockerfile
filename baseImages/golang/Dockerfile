# Pull base image.
FROM alpine:latest
MAINTAINER Frank Wang "eternnoir@gmail.com"

# Update

RUN apk update && apk --no-cache add ca-certificates openssl && update-ca-certificates 

# set golang env
RUN mkdir /go
ENV GOPATH /go
ENV GOROOT /usr/local/go
RUN wget https://storage.googleapis.com/golang/go1.8.3.linux-amd64.tar.gz -q -O - | tar -zxf - -C /usr/local

VOLUME [ "/go" ]
