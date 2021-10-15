FROM alpine:3.13.6
COPY pgpool.conf /etc/pgpool/pgpool.conf
RUN apk update \
 && apk add pgpool \
 && mkdir /var/run/pgpool

CMD ["pgpool", "-n"]
