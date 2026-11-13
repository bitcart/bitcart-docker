FROM rust:1.100.0-alpine AS build

RUN apk add --no-cache musl-dev
WORKDIR /src
COPY bitcart/renderer .
RUN cargo build --release --locked && mkdir /socket

FROM scratch
LABEL org.bitcart.image=renderer
COPY --from=build /src/target/release/bitcart-renderer /renderer
COPY --from=build --chown=65534:65534 /socket /run/renderer
USER 65534:65534
ENTRYPOINT ["/renderer"]
