FROM rust:1-buster as sysstat

WORKDIR /sysstat
RUN git clone https://github.com/sysstat/sysstat /sysstat
RUN CFLAGS=-static ./configure && CFLAGS=-static make -j$(nproc)

RUN wc -c /sysstat/iostat | numfmt --to=iec-i

FROM rust:1-buster as build

# create dummy application for dependency caching
RUN USER=root cargo new --bin throttled
WORKDIR /throttled

RUN rustup toolchain install nightly

# download + compile dependencies for caching
COPY Cargo.toml Cargo.lock ./
RUN cargo +nightly build --release
RUN rm src/*.rs

# build for real
COPY src ./src
RUN rm ./target/release/deps/throttled*
RUN cargo +nightly build --release

RUN wc -c target/release/throttled | numfmt --to=iec-i

# ------------------------------------------------------------------------------
# Final Stage
# ------------------------------------------------------------------------------

# FROM amd64/busybox:uclibc as busybox
# FROM gcr.io/distroless/cc:debug
# COPY --from=busybox /bin/busybox /busybox/busybox
# RUN ["/busybox/busybox", "--install", "/bin"]
FROM gcr.io/distroless/cc:latest

COPY --from=build /throttled/target/release/throttled .
COPY --from=sysstat /sysstat/iostat /sysstat/iostat

CMD ["/usr/local/bin/throttled"]
