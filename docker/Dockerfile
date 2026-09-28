FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ffmpeg \
        curl \
        ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Standalone yt-dlp binary (no Python needed)
RUN curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux \
      -o /usr/local/bin/yt-dlp && \
    chmod +x /usr/local/bin/yt-dlp

WORKDIR /app

COPY start.sh .
COPY overlay.png .
COPY font.ttf .

RUN chmod +x start.sh

CMD ["./start.sh"]
