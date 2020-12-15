# shift-hls-stream

Time-shift an HLS stream

### Example docker-compose.yml:
```
version: "3.7"
services:
  shift-hls-stream:
    image: nhkrecord/shift-hls-stream:latest
    restart: unless-stopped
    volumes:
      - "data:/data/"
    environment:
      - "STREAM_URL=https://b-nhkwlive-ojp.webcdn.stream.ne.jp/hls/live/2003459-b/nhkwlive-ojp-en/index_4M.m3u8"
      - "STREAM_DELAY=3600"
      - "MAX_AGE=7200"

  nginx:
    image: nginx
    restart: unless-stopped
    ports:
      - "9898:80"
    volumes:
      - "./nginx.conf:/etc/nginx/nginx.conf"
      - "data:/docroot/"
      
volumes:
  data:
```

### Example nginx.conf
```
events {
}

http {
  gzip on;
  gzip_types application/x-mpegurl;
  keepalive_timeout 300;

  types {
    application/x-mpegurl m3u8;
    video/mp2t ts;
  }

  server {
    listen 80;

    location / {
      root /docroot/;
    }
  }
}
```
