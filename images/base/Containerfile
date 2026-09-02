FROM docker.io/library/debian:bookworm-slim AS meter-builder

ARG SVDO_METER_REPO=https://github.com/brianofrokk3r/svdo-meter.git
ARG SVDO_METER_REF=main
ARG SVDO_METER_INSTALL_METHOD=release

ENV RUSTUP_HOME=/opt/rustup \
    CARGO_HOME=/opt/cargo \
    PATH=/opt/cargo/bin:${PATH}

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        curl \
        git \
        python3 \
        python3-pip \
        python3-venv \
        nodejs \
        npm \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://sh.rustup.rs -o /tmp/rustup-init.sh \
    && sh /tmp/rustup-init.sh -y --profile minimal --default-toolchain stable \
    && rm /tmp/rustup-init.sh

COPY scripts/install-svdo-meter.sh /usr/local/bin/install-svdo-meter
RUN chmod +x /usr/local/bin/install-svdo-meter \
    && /usr/local/bin/install-svdo-meter

FROM docker.io/library/debian:bookworm-slim

ARG USER_NAME=svdo
ARG USER_UID=1000
ARG USER_GID=1000

LABEL org.opencontainers.image.title="svdo-worker" \
      org.opencontainers.image.description="Container-side runtime for metered SVDO work units" \
      org.opencontainers.image.source="https://github.com/brianofrokk3r/svdo-worker"

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        git \
        jq \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid "${USER_GID}" "${USER_NAME}" \
    && useradd --uid "${USER_UID}" --gid "${USER_GID}" --create-home --home-dir "/home/${USER_NAME}" --shell /bin/bash "${USER_NAME}" \
    && mkdir -p /workspace /tmp/svdo-worker /etc/svdo-worker \
    && chown -R "${USER_NAME}:${USER_NAME}" "/home/${USER_NAME}" /workspace /tmp/svdo-worker

COPY --from=meter-builder /usr/local/bin/svdo-meter /usr/local/bin/svdo-meter
COPY config/meter.yaml /etc/svdo-worker/meter.yaml
COPY scripts/entrypoint.sh /usr/local/bin/svdo-worker-entrypoint

RUN chmod +x /usr/local/bin/svdo-worker-entrypoint /usr/local/bin/svdo-meter

ENV SVDO_WORKSPACE=/workspace \
    SVDO_HOME=/home/svdo \
    SVDO_TMPDIR=/tmp/svdo-worker \
    SVDO_METER_BIN=/usr/local/bin/svdo-meter \
    SVDO_METER_CONFIG=/etc/svdo-worker/meter.yaml \
    SVDO_WORKER_MODE=harness \
    HOME=/home/svdo \
    TMPDIR=/tmp/svdo-worker

WORKDIR /workspace
USER svdo
ENTRYPOINT ["/usr/local/bin/svdo-worker-entrypoint"]
CMD ["bash", "-lc", "pwd && echo svdo-worker ready"]
