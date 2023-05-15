FROM lukemathwalker/cargo-chef:latest-rust-1 AS chef
# planner
FROM chef AS planner
WORKDIR /app
COPY src/ src/
COPY Cargo.lock .
COPY Cargo.toml .
RUN cargo chef prepare --recipe-path recipe.json
# builder
FROM chef AS builder 
WORKDIR /app
# hydrate
COPY --from=planner /app/recipe.json recipe.json
RUN cargo chef cook --recipe-path recipe.json
# build
COPY src/ src/
COPY Cargo.lock .
COPY Cargo.toml .
RUN cargo build
# runtime
FROM debian:stable-slim AS runtime
# copy app from builder
WORKDIR /app
COPY --from=builder /app/target/debug/rust-poc-app /app/rust-poc-app
# entrypoint
ENTRYPOINT ["/app/rust-poc-app"]
