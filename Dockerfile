FROM golang:1.25-alpine AS go-builder

RUN apk --no-cache add --update git

# Pritunl Install into /go/bin
ENV GOPATH=/go
RUN go install github.com/pritunl/pritunl-dns@latest \
    && go install github.com/pritunl/pritunl-web@latest

FROM alpine:3.20
LABEL maintainer="red <red.avtovo@gmail.com>"

ENV VERSION="1.34.4575.42"

RUN apk -U upgrade

# Build & runtime deps
RUN apk --no-cache add --update wget py3-pip \
    gcc python3 python3-dev cargo make musl-dev linux-headers libffi-dev openssl-dev \
    py3-setuptools openssl procps ca-certificates openvpn iptables ip6tables bash

RUN pip install --break-system-packages --upgrade pip

COPY --from=go-builder /go/bin/* /usr/bin/

RUN wget https://github.com/pritunl/pritunl/archive/refs/tags/${VERSION}.tar.gz \
    && ls -lh \
    && tar -zxvf ${VERSION}.tar.gz \
    && cd pritunl-${VERSION} \
    # Fix dedicated server subscription URL
    && sed -i "s|url = x(b'aHR0cHM6Ly9hcHAucHJpdHVubC5jb20vc3Vic2NyaXB0aW9u')|url = settings.app.dedicated + '/subscription' if settings.app.dedicated else x(b'aHR0cHM6Ly9hcHAucHJpdHVubC5jb20vc3Vic2NyaXB0aW9u')|" pritunl/subscription.py \
    && python3 setup.py build \
    && pip install --break-system-packages -r requirements.txt \
    && python3 setup.py install \
    && cd .. \
    && rm -rf *${VERSION}* \
    && rm -rf /tmp/* /var/cache/apk/*

RUN sed -i -e '/^attributes/a prompt\t\t\t= yes' /etc/ssl/openssl.cnf
RUN sed -i -e '/countryName_max/a countryName_value\t\t= US' /etc/ssl/openssl.cnf

ADD rootfs /

EXPOSE 80
EXPOSE 443
EXPOSE 1194
ENTRYPOINT ["/init"]
