#
# Ubuntu 14.04
#
# Pull base image.
FROM ubuntu:14.04
MAINTAINER Frank Wang "eternnoir@gmail.com"


WORKDIR /tmp

#update
# RUN apt-get -y update && apt-get install -y curl openjdk-6-jre-headless docker.io
#ENV MESOS_VERSION 0.21.1
#ENV PKG 1.1
#RUN curl -s -O https://downloads.mesosphere.io/master/ubuntu/14.04/mesos_${MESOS_VERSION}-${PKG}.ubuntu1404_amd64.deb
#RUN dpkg --unpack mesos_${MESOS_VERSION}-${PKG}.ubuntu1404_amd64.deb && apt-get install -f -y 
#RUN rm mesos_* && apt-get clean
RUN sudo apt-key adv --keyserver keyserver.ubuntu.com --recv E56151BF
RUN echo "deb http://repos.mesosphere.io/ubuntu trusty main" | tee /etc/apt/sources.list.d/mesosphere.list
RUN apt-get -y update && apt-get -y install mesos

EXPOSE 5050
