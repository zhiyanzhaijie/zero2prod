# stage - Building
FROM lukemathwalker/cargo-chef:latest-rust-1.83.0 as chef
WORKDIR /app
# 添加正确的源
RUN echo "deb http://mirrors.aliyun.com/debian bullseye main contrib non-free" > /etc/apt/sources.list \
    && echo "deb http://mirrors.aliyun.com/debian-security bullseye-security main contrib non-free" >> /etc/apt/sources.list \
    && echo "deb http://mirrors.aliyun.com/debian bullseye-updates main contrib non-free" >> /etc/apt/sources.list

RUN apt update && apt install lld clang -y

FROM chef as planner
COPY . .
# compiler a lock-file for project
RUN cargo chef prepare --recipe-path recipe.json

FROM chef as builder
COPY --from=planner /app/recipe.json recipe.json
# build our project dependencieds rather than application!
# so the cache work

COPY . .
ENV SQLX_OFFLINE true
RUN cargo build --release --bin zero2prod

# stage - Runtime
FROM debian:bookworm-slim  AS runtime
WORKDIR /app

RUN apt-get update -y \
  && apt-get install -y --no-install-recommends ca-certificates \
  && apt-get autoremove -y \
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/target/release/zero2prod zero2prod
COPY configuration configuration
ENV APP_ENVIRONMENT=production

ENTRYPOINT ["./zero2prod"]
