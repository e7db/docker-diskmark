FROM alpine:latest AS builder
RUN apk add --no-cache bash coreutils fio findmnt grep ncurses ncurses-terminfo-base perl procps sed util-linux
RUN mkdir -p /diskmark/usr/bin /diskmark/lib /diskmark/usr/lib /diskmark/etc /diskmark/disk && \
    for bin in bash cat cut dd df grep ls mkdir rm sed awk basename dirname env expr fio findmnt free head lsblk numfmt perl printf ssl_client tail tput tr wc wget; do cp $(which $bin) /diskmark/usr/bin/; done && \
    cp /lib/ld-musl-*.so.1 /diskmark/lib/ && cp -a /lib/*.so* /diskmark/usr/lib/ 2>/dev/null || true && \
    cp -a /usr/lib/*.so* /diskmark/usr/lib/ 2>/dev/null || true && \
    cp /usr/lib/perl5/core_perl/CORE/libperl.so /diskmark/usr/lib/ && \
    cp -r /etc/terminfo /diskmark/etc/ && \
    echo "nobody:x:65534:65534:Nobody:/:" > /diskmark/etc/passwd && \
    chown 65534:65534 /diskmark/disk

FROM alpine:latest AS version
ARG VERSION=unknown
RUN echo "$VERSION" > /etc/diskmark-version

FROM scratch
COPY --from=builder /diskmark/ /
COPY --from=version /etc/diskmark-version /etc/diskmark-version
COPY diskmark.sh /usr/bin/diskmark
VOLUME /disk
WORKDIR /disk
USER 65534:65534
ENV TERM="xterm" \
    TARGET="/disk" \
    PROFILE="auto" \
    IO="direct" \
    DATA="random" \
    SIZE="1G" \
    WARMUP="1" \
    WARMUP_SIZE="" \
    RUNTIME="5s"
ENTRYPOINT ["/usr/bin/bash", "/usr/bin/diskmark"]
