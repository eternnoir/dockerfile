#
# Python Dockerfile
#

# Pull base image.
FROM ubuntu:14.04

RUN apt-get update --fix-missing
RUN  apt-get install -y software-properties-common
RUN apt-add-repository ppa:bitcoin/bitcoin
RUN apt-get update
RUN apt-get install -y bitcoind
RUN mkdir /.bitcoin
ADD ./bitcoin.conf /.bitcoin/
