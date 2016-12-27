#
# Ubuntu 14.04 with Golang Dockerfile
#
# Pull base image.
FROM ubuntu:16.04
MAINTAINER Frank Wang "eternnoir@gmail.com"

#update
RUN apt-get -y update && apt-get -y install wget net-tools && sudo apt-get -y clean

RUN mkdir /go
# set golang env
ENV VERSION 1.7.4
ENV OS linux
ENV ARCH amd64
RUN wget https://storage.googleapis.com/golang/go$VERSION.$OS-$ARCH.tar.gz -q -O - | tar -zxf - -C /usr/local
ENV GOPATH /go
ENV GOROOT /usr/local/go
ENV PATH $PATH:$GOPATH/bin:$GOROOT/bin

VOLUME [ "/go" ]
