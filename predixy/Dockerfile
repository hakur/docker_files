FROM ubuntu:20.04 as builder
COPY sources.list /etc/apt/sources.list
ADD predixy-1.0.5.tar.gz /build
WORKDIR /build/predixy-1.0.5
RUN apt update
RUN apt -y install make gcc g++ clang
RUN make -j $(nproc) CXX=clang++ EV=epoll MT=true
RUN cp -r src/predixy /predixy

FROM ubuntu:20.04
COPY --from=builder /predixy /bin/predixy
COPY cmd.sh /cmd.sh
CMD /cmd.sh