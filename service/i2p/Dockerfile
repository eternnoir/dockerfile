#
# Ubuntu 14.04 with quassel-core Dockerfile
#
# Pull base image.
FROM eternnoir/ubuntu-14.04-sshd
MAINTAINER Frank Wang <eternnoir@gmail.com>

#Update
RUN apt-get update && apt-get install -y software-properties-common
# Install i2p
RUN add-apt-repository -y ppa:i2p-maintainers/i2p && \
    apt-get update && \
    apt-get install -y i2p

ADD script /root/script

CMD ["sh","/root/script/run.sh","console"]

# WEB GUI
EXPOSE 7657
#PROXY
EXPOSE 4444

