#
# Ubuntu 14.04 with Golang Dockerfile
#
# Pull base image.
FROM ubuntu:14.04
MAINTAINER Frank Wang "eternnoir@gmail.com"

#update
RUN apt-get -y update
RUN apt-get -y install wget net-tools

WORKDIR /root
RUN mkdir /go
# set golang env
ENV HOME /root
ENV VERSION 1.2.2
ENV OS linux
ENV ARCH amd64
RUN wget http://golang.org/dl/go$VERSION.$OS-$ARCH.tar.gz -q -O - | tar -zxf - -C /usr/local
ENV GOPATH /go
ENV GOROOT /usr/local/go
ENV PATH $PATH:$GOROOT/bin

VOLUME [ "/go" ]
