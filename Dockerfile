FROM ubuntu:focal-20210217 as go-builder

RUN apt-get update \
    && export DEBIAN_FRONTEND=noninteractive \
    && apt install -yq git curl \
    && curl -LO https://get.golang.org/$(uname)/go_installer \
    && chmod +x go_installer \
    && SHELL=bash ./go_installer \
    && rm go_installer

RUN /bin/bash -c "source /root/.bash_profile; export GOPATH=/go; go get github.com/pritunl/pritunl-dns; go get github.com/pritunl/pritunl-web"


#----- Runtime
FROM ubuntu:focal-20210217
MAINTAINER red <red.avtovo@gmail.com>
ENV VERSION="1.29.2664.67"

COPY --from=go-builder /go/bin/* /usr/bin/

RUN apt-get update \
    && apt install -yq wget \
    python2 python-setuptools \
    python-dev gcc openvpn openssl net-tools iptables psmisc ca-certificates

RUN wget https://github.com/pritunl/pritunl/archive/refs/tags/${VERSION}.tar.gz \
    && tar zxf ${VERSION}.tar.gz \
    && cd pritunl-${VERSION} \
    && python2 setup.py build \
    && wget https://bootstrap.pypa.io/pip/2.7/get-pip.py \
    && python2 ./get-pip.py \
    && rm -f ./get-pip.py \
    && pip2 install --upgrade pip \
    && pip2 install -r requirements.txt \
    && pip2 install pymongo[srv] \
    && python2 setup.py install \
    && cd .. \
    && rm -rf *${VERSION}* \
    && apt remove -y wget gcc python-dev \
    && apt autoremove -y \
    && rm -rf /tmp/* /var/cache/apt/*

RUN sed -i -e '/^attributes/a prompt\t\t\t= yes' /etc/ssl/openssl.cnf
RUN sed -i -e '/countryName_max/a countryName_value\t\t= US' /etc/ssl/openssl.cnf

ENV PYTHONWARNINGS="ignore"

ADD rootfs /

EXPOSE 80
EXPOSE 443
EXPOSE 1194
ENTRYPOINT ["/init"]
