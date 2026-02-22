FROM rust:1.90-bookworm AS builder

WORKDIR /usr/src/app
COPY . .

RUN echo "$(rustc -vV | sed -n 's|host: ||p')" > rust_target

ENV CARGO_NET_GIT_FETCH_WITH_CLI true

RUN --mount=type=cache,target=/usr/local/cargo,from=rust:latest,source=/usr/local/cargo \
    --mount=type=cache,target=target \
    cargo build --target $(cat rust_target) -p marmotd --release && \
    mv ./target/$(cat rust_target)/release/marmotd ./marmotd

FROM node:22-bookworm-slim

RUN apt-get update && apt-get install -y python3 ca-certificates && rm -rf /var/lib/apt/lists/*
RUN useradd -ms /bin/bash app
RUN npm install -g @mariozechner/pi-coding-agent

USER app
WORKDIR /app

COPY --from=builder /usr/src/app/marmotd /app/marmotd
COPY bots/pi-bridge.py /app/pi-bridge.py
COPY crates/pika-bot/entrypoint.sh /app/entrypoint.sh

ENV RUST_LOG=info

CMD ["/app/entrypoint.sh"]
