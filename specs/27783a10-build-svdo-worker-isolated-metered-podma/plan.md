# Implementation Plan: svdo-worker

## Approach

Create a greenfield runtime repository in the current directory. Keep the repository as a focused container runtime artifact with no orchestrator components. Use Spec Kit artifacts to capture principles, behavior, plan, and implementation tasks.

## Technical Decisions

- Use Debian bookworm slim for the base image.
- Use rootless-friendly user `svdo` with UID/GID `1000`.
- Use `/workspace`, `/home/svdo`, and `/tmp/svdo-worker` as runtime paths.
- Copy `config/meter.yaml` into `/etc/svdo-worker/meter.yaml`.
- Install `svdo-meter` from `https://github.com/brianofrokk3r/svdo-meter` during image build through a dedicated installer script.
- Prefer the upstream release installer and fall back to source builds from the actual Rust workspace package at `crates/svdo-meter`.
- Make meter invocation configurable with `SVDO_METER_BIN`, `SVDO_METER_CONFIG`, `SVDO_WORKER_MODE`, and `SVDO_METER_EXTRA_ARGS`.
- Keep variants as separate Containerfiles extending the base image.
- Use shell validation tests that can run locally without external services.

## Repository Layout

```text
.
├── Containerfile
├── README.md
├── config/meter.yaml
├── scripts/entrypoint.sh
├── scripts/install-svdo-meter.sh
├── images/base/Containerfile
├── images/node/Containerfile
├── images/python/Containerfile
├── images/rust/Containerfile
├── examples/run-local-workspace.sh
├── examples/run-codex.sh
├── examples/run-with-metadata.sh
└── tests/
    ├── validate-entrypoint.sh
    └── validate-image-build.sh
```

## Validation

1. Run `bash tests/validate-entrypoint.sh` to confirm the entrypoint validates paths and wraps commands with a fake `svdo-meter`.
2. Run `bash tests/validate-image-build.sh` where rootless Podman and network access are available.
3. Inspect the repository for prohibited orchestration artifacts.

## Risks

- The current `svdo-meter` CLI is harness/prompt oriented, not a generic `-- <command>` wrapper. The worker defaults to the current CLI and reserves raw mode for future/downstream wrapper support.
- Full image build validation requires Podman and network access to clone `svdo-meter`.
