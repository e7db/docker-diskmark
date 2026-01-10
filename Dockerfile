FROM alpine:latest AS builder
RUN apk add --no-cache bash coreutils fio findmnt grep ncurses ncurses-terminfo-base perl procps sed util-linux
RUN mkdir -p /dist/usr/bin /dist/lib /dist/usr/lib /dist/etc /dist/disk && \
    for bin in bash cat cut dd df grep ls mkdir rm sed awk basename dirname env expr fio findmnt free head lsblk numfmt perl printf tail tput tr wc; do cp $(which $bin) /dist/usr/bin/; done && \
    cp /lib/ld-musl-*.so.1 /dist/lib/ && cp -a /lib/*.so* /dist/usr/lib/ 2>/dev/null || true && \
    cp -a /usr/lib/*.so* /dist/usr/lib/ 2>/dev/null || true && \
    cp /usr/lib/perl5/core_perl/CORE/libperl.so /dist/usr/lib/ && \
    cp -r /etc/terminfo /dist/etc/ && \
    echo "nobody:x:65534:65534:Nobody:/:" > /dist/etc/passwd && \
    chown 65534:65534 /dist/disk

FROM scratch
COPY --from=builder /dist/ /
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
