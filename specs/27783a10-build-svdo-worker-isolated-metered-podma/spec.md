# Feature Spec: Build svdo-worker isolated metered Podman runtime

## Status

Drafted for initial implementation.

## User Need

SVDO needs a standardized container-side runtime that can run CLI-based coding agents inside lightweight isolated OCI environments. The runtime must be launchable with rootless Podman and must meter commands transparently with `svdo-meter`.

## Functional Requirements

1. The repository provides a Debian-based base worker image that can be built with rootless Podman.
2. The base image includes `bash`, `ca-certificates`, `curl`, `git`, `jq`, and `svdo-meter`.
3. The base image does not include large language SDKs or language toolchains.
4. Node, Python, and Rust variants extend the base image and add only their respective common toolchain/runtime packages.
5. The worker entrypoint establishes stable runtime paths:
   - workspace: `/workspace` by default
   - home: `/home/svdo` by default
   - temp: `/tmp/svdo-worker` by default
   - meter config: `/etc/svdo-worker/meter.yaml` by default
6. Commands passed to the container are executed through `svdo-meter` by default.
7. SVDO metadata can be supplied through environment variables and is preserved for telemetry enrichment.
8. A default `config/meter.yaml` exists without hard-coding orchestration assumptions.
9. Example scripts demonstrate local workspace execution, Codex/agent CLI execution, and metadata passing.
10. Validation scripts verify shell entrypoint behavior and image buildability when Podman is present.
11. Documentation covers responsibilities, non-goals, Podman usage, environment variables, workspace expectations, image variants, meter integration, and extension points.

## Runtime Contract

The container runs:

```text
SVDO -> podman run -> svdo-worker -> svdo-meter -> agent CLI
```

The current `svdo-meter` CLI owns harness execution. The entrypoint receives the requested prompt/work instruction as its arguments. It validates configured paths, exports worker metadata, and invokes:

```text
svdo-meter run --ticket <work-id> --harness <harness> --workspace <workspace> "<prompt>"
```

`SVDO_METER_EXTRA_ARGS` appends additional `svdo-meter run` flags. A reserved `SVDO_WORKER_MODE=raw` path can support a future generic subprocess wrapper, but it is not the default because the current `svdo-meter` repository does not expose that CLI contract.

## Metadata Environment

The worker recognizes these SVDO metadata variables when provided:

- `SVDO_TICKET_ID`
- `SVDO_WORK_UNIT_ID`
- `SVDO_REPOSITORY_ID`
- `SVDO_REPOSITORY_URL`
- `SVDO_AGENT`
- `SVDO_MODEL`
- `SVDO_RUN_ID`
- `SVDO_SESSION_ID`
- `SVDO_PROVIDER_SESSION_ID`
- `SVDO_ATTEMPT`
- `SVDO_PARENT_RUN_ID`

Unknown environment variables are not interpreted by the worker.

## Non-Goals

This repository must not implement orchestration, ticket management, worktree creation, branch management, queues, schedulers, HTTP APIs, registries, GitHub integration, always-running services, Docker Compose, or Kubernetes manifests.

## Acceptance Criteria Mapping

- Minimal documented runtime contract: README and this spec.
- Rootless Podman build/run: Containerfiles and validation script.
- Debian base with agreed dependencies: `images/base/Containerfile`.
- `svdo-meter` integration: install script, image build args, README.
- Isolated home/temp/workspace: entrypoint and Containerfiles.
- Transparent metering: entrypoint invocation.
- Default config: `config/meter.yaml`.
- Metadata support: entrypoint exports and config documents allowlisted metadata.
- Examples: `examples/`.
- Variants: `images/node`, `images/python`, `images/rust`.
- Tests/validation: `tests/validate-entrypoint.sh`, `tests/validate-image-build.sh`.
- No orchestration artifacts: repository scope excludes them.
