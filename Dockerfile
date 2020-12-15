FROM alpine:3.12

ENV UID=1000 GID=1000
ENV DATA_DIR=/data

RUN apk --no-cache add \
  bash \
  coreutils \
  curl \
  findutils \
  su-exec

RUN mkdir /data
RUN chmod -R 777 /data

RUN mkdir /app
COPY run.sh /app/
COPY shift.sh /app/
RUN chmod +x /app/*.sh

VOLUME /data

CMD ["/app/run.sh"]
