# syntax=docker.io/docker/dockerfile:1.27.0

FROM debian:12.15-slim AS base-image
FROM node:22 AS web-builder

WORKDIR /app
COPY web/package.json web/package-lock.json ./

# Caching the `node_modules` folder as well causes trouble in some builders
# and causes the node_modules folder not to be present after install.
RUN --mount=type=cache,target=/root/.npm \
    npm install

COPY web/ ./

RUN npm run-script build && npm run-script check


FROM base-image AS builder

WORKDIR /app
USER 0

RUN apt-get update && apt-get install -y libpq-dev gcc git curl

ENV PATH="/root/.cargo/bin:${PATH}"
RUN curl https://sh.rustup.rs -sSf | bash -s -- -y

COPY . .
COPY --from=web-builder /app/build ./web/build
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/app/target \
    cargo build --release --locked && \
    mv target/release/stuufff .

FROM base-image

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y \
        libpq5 \
        ca-certificates \
        curl

COPY --from=builder app/stuufff /usr/bin/stuufff

ENTRYPOINT [ "/usr/bin/stuufff" ]
