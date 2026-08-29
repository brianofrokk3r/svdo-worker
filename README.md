# svdo-worker

`svdo-worker` is the standardized container-side runtime for SVDO work units. It provides a small, isolated OCI environment for CLI-based coding agents and executes every command through `svdo-meter` by default.

```text
SVDO -> podman run -> svdo-worker -> svdo-meter -> agent CLI
```

This repository is intentionally only the runtime contract. It does not create worktrees, schedule jobs, manage tickets, run queues, expose an API, register workers, or integrate with GitHub.

## Runtime Contract

The base image expects:

| Setting | Default | Purpose |
| --- | --- | --- |
| `SVDO_WORKSPACE` | `/workspace` | Mounted repository or work unit directory |
| `SVDO_HOME` | `/home/svdo` | Isolated user home for agent state |
| `SVDO_TMPDIR` | `/tmp/svdo-worker` | Runtime temp and meter output root |
| `SVDO_METER_CONFIG` | `/etc/svdo-worker/meter.yaml` | Meter configuration |
| `SVDO_METER_BIN` | `/usr/local/bin/svdo-meter` | Meter executable |
| `SVDO_WORKER_MODE` | `harness` | Meter invocation mode. `harness` matches the current `svdo-meter run` CLI. |
| `SVDO_METER_EXTRA_ARGS` | empty | Extra flags appended to `svdo-meter run` before the prompt |

In default `harness` mode, container arguments are treated as the prompt/work instruction. The entrypoint runs:

```bash
svdo-meter run \
  --ticket "${SVDO_TICKET_ID:-${SVDO_WORK_UNIT_ID:-local}}" \
  --harness "${SVDO_HARNESS:-${SVDO_AGENT:-codex}}" \
  --workspace "${SVDO_WORKSPACE}" \
  ${SVDO_METER_EXTRA_ARGS} \
  "$*"
```

This matches the current `svdo-meter` contract: the meter selects a supported harness such as `codex` or `claude`, starts the agent CLI itself, and records telemetry under `<workspace>/.svdo/meter/`.

The entrypoint validates that the workspace, home directory, temp directory, meter config, and meter binary exist before launching the command.

## Build

Build the base image with rootless Podman:

```bash
podman build -t svdo-worker-base:latest -f images/base/Containerfile .
```

Build variants:

```bash
podman build -t svdo-worker-node:latest -f images/node/Containerfile .
podman build -t svdo-worker-python:latest -f images/python/Containerfile .
podman build -t svdo-worker-rust:latest -f images/rust/Containerfile .
```

The root `Containerfile` builds the same base image as `images/base/Containerfile`; use whichever path best fits your build workflow.

## svdo-meter Integration

The base image installs `svdo-meter` from:

```text
https://github.com/brianofrokk3r/svdo-meter
```

`images/base/Containerfile` runs `scripts/install-svdo-meter.sh`. By default the script uses the upstream release installer from `svdo-meter`. If release installation is unavailable, or if `SVDO_METER_INSTALL_METHOD=source` is set, it builds from the Rust workspace package at `crates/svdo-meter` and places the executable at `/usr/local/bin/svdo-meter`.

Maintainers can pin a different revision at build time:

```bash
podman build \
  --build-arg SVDO_METER_REF=<git-ref> \
  -t svdo-worker-base:latest \
  -f images/base/Containerfile .
```

The expected meter CLI contract is:

```bash
svdo-meter run --ticket <work-id> --harness <codex|claude> --workspace <workspace> "<prompt>"
```

The current `svdo-meter` CLI is flag-driven and does not consume `config/meter.yaml` directly. The bundled config file documents the worker metadata contract and is reserved for meter config support as it evolves.

If `svdo-meter` adds a generic subprocess wrapper later, `SVDO_WORKER_MODE=raw` can be used with:

```bash
svdo-meter ${SVDO_METER_ARGS} -- <command> [args...]
```

## Run

Run a local workspace:

```bash
podman run --rm -it \
  --userns=keep-id \
  --security-opt=no-new-privileges \
  --cap-drop=all \
  --network=slirp4netns \
  --memory=2g \
  --cpus=2 \
  --volume "$PWD:/workspace:Z" \
  svdo-worker-base:latest \
  "Inspect the workspace and summarize the current repository status."
```

Run an agent CLI:

```bash
podman run --rm -it \
  --userns=keep-id \
  --security-opt=no-new-privileges \
  --cap-drop=all \
  --env SVDO_TICKET_ID=ENG-142 \
  --env SVDO_AGENT=codex \
  --volume "$PWD:/workspace:Z" \
  svdo-worker-node:latest \
  "Implement ENG-142 using the current workspace."
```

Use `:Z` on SELinux hosts. Use `:z` instead when the same workspace must be shared by multiple containers.

## SVDO Metadata

SVDO can pass metadata as environment variables. The worker does not interpret orchestration semantics, but the default meter config allowlists these values for telemetry enrichment:

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

Example:

```bash
podman run --rm \
  --userns=keep-id \
  --env SVDO_WORK_UNIT_ID=wu_123 \
  --env SVDO_RUN_ID=run_456 \
  --env SVDO_AGENT=codex \
  --volume "$PWD:/workspace:Z" \
  svdo-worker-base:latest \
  "Run the test suite and fix any failures."
```

`SVDO_PROVIDER_SESSION_ID` is special: when set, the worker passes it to `svdo-meter run --session` as a provider session/thread override. `SVDO_SESSION_ID` remains SVDO metadata and is not used for provider resume.

## Image Variants

- `svdo-worker-base`: Debian slim, `bash`, `ca-certificates`, `curl`, `git`, `jq`, and `svdo-meter`.
- `svdo-worker-node`: base plus Debian `nodejs` and `npm`.
- `svdo-worker-python`: base plus `python3`, `python3-pip`, and `python3-venv`.
- `svdo-worker-rust`: base plus `cargo`, `rustc`, `pkg-config`, and `build-essential`.

The base image deliberately excludes large SDKs and language toolchains. Add agent-specific tooling in variants or downstream images.

## Examples

- `examples/run-local-workspace.sh`: mount a local workspace and run a measured prompt.
- `examples/run-codex.sh`: invoke the Codex harness through `svdo-meter`.
- `examples/run-with-metadata.sh`: pass SVDO metadata into a metered command.

## Validation

Validate entrypoint argument translation locally without Podman:

```bash
bash tests/validate-entrypoint.sh
```

Validate image builds and the installed `svdo-meter` binary where Podman and network access are available:

```bash
bash tests/validate-image-build.sh
```

The image build validation installs `svdo-meter`, so it requires network access unless your Podman build environment has cached or mirrored release/source assets. Full measured Codex or Claude runs also require the selected agent CLI to be installed and authenticated in the image.

## Extension Points

- Set `SVDO_METER_EXTRA_ARGS` for current `svdo-meter run` flags such as `--emit ndjson` or `--codex-sandbox workspace-write`.
- Set `SVDO_WORKER_MODE=raw` and override `SVDO_METER_ARGS` only for a future or downstream generic subprocess wrapper.
- Override `SVDO_METER_CONFIG` and mount a different config file.
- Build downstream images from a variant to add a specific agent CLI.
- Add new language variants under `images/<variant>/Containerfile`.

## Non-Goals

This repository must not include ticket management, worktree creation, branch management, queues, schedulers, HTTP APIs, worker registries, GitHub integration, always-running daemons, Docker Compose, Kubernetes manifests, or other orchestration logic.
