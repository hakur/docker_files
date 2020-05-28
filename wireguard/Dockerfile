FROM centos:7.5.1804 as build-wg
RUN mkdir /build && mkdir /dst
# RUN yum makecache fast
RUN yum -y install make gcc libmnl libmnl-devel
WORKDIR /build
COPY openresolv-openresolv-3.10.0.tar.gz /build
RUN tar -xf openresolv-openresolv-3.10.0.tar.gz
RUN cd openresolv-openresolv-3.10.0 \
 && chmod +x ./configure \
 && ./configure \
 && make \
 && make install
COPY wireguard-monolithic-historical-0.0.20191219.tar.gz /build
RUN tar -xf wireguard-monolithic-historical-0.0.20191219.tar.gz
RUN cd wireguard-monolithic-historical-0.0.20191219/src/tools \
 && cp wg-quick/linux.bash /dst/wg-quick \
 && make \
 && cp wg /dst/wg

FROM golang:1.14.3-stretch as build-go
RUN mkdir /build && mkdir /dst
WORKDIR /build
ENV GOPROXY=https://goproxy.cn,direct
COPY wireguard-go-0.0.20200320.tar.gz /build
RUN tar -xf wireguard-go-0.0.20200320.tar.gz \
 && cd wireguard-go-0.0.20200320 \
 && go build -ldflags "-s -w" -tags=netgo -o /dst/wireguard-go

FROM centos:7.5.1804
COPY init.sh /init.sh
RUN yum -y install iproute libmnl net-tools \
    && chmod +x /init.sh
COPY --from=build-wg /usr/sbin/resolvconf /usr/sbin/resolvconf
COPY --from=build-wg /usr/lib/resolvconf /usr/lib/resolvconf
COPY --from=build-wg /etc/resolvconf.conf /etc/resolvconf.conf
COPY --from=build-wg /dst/wg-quick /bin/wg-quick
COPY --from=build-wg /dst/wg /bin/wg
COPY --from=build-go /dst/wireguard-go /bin/wireguard-go
COPY config/* /etc/wireguard/
CMD ["/init.sh"]
