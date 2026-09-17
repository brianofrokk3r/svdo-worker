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
  --output-dir "${SVDO_TMPDIR}/meter" \
  ${SVDO_METER_EXTRA_ARGS} \
  "$*"
```

This matches the current `svdo-meter` contract: the meter selects a supported harness such as `codex`, `claude`, or `opencode`, starts the agent CLI itself, and records durable run telemetry under `${SVDO_TMPDIR}/meter` by default. If operators intentionally provide `--output-dir` in `SVDO_METER_EXTRA_ARGS`, the worker does not add its default output directory.

The entrypoint validates that the workspace, home directory, temp directory, meter config, and meter binary exist before launching the command.

## Reusable Runtime Model

Podman, Kubernetes, and future infrastructure integrations should all treat the worker image as the same single-work-unit runtime:

- Use a worker image whose launch path is `scripts/entrypoint.sh` and whose default execution path is `svdo-meter run`.
- Provide one project source mount at `SVDO_WORKSPACE`. This is the only required source mount.
- Provide a writable `SVDO_HOME` for isolated agent state, credentials, caches, and provider session files. This may be a bind mount, named volume, PVC, or ephemeral volume depending on the runtime.
- Provide a writable `SVDO_TMPDIR` for transient files and meter output. The default harness mode passes `--output-dir ${SVDO_TMPDIR}/meter` to `svdo-meter run`.
- Provide a readable meter config file at `SVDO_METER_CONFIG`. The bundled config documents the worker metadata contract; operators may inject an environment-specific config with a bind mount, ConfigMap, Secret, or equivalent runtime primitive without mounting another source tree.
- Provide an executable meter binary at `SVDO_METER_BIN`. The base image installs this by default.
- Leave `SVDO_WORKER_MODE=harness` unless intentionally targeting a downstream or future raw subprocess wrapper.
- Use `SVDO_METER_EXTRA_ARGS` for explicit operator-controlled `svdo-meter run` flags.

Infrastructure integrations map this contract into their own primitives. A local Podman run uses bind mounts and environment variables. A Kubernetes Job uses volumes, ConfigMaps or Secrets, container env, and a pod security context. Future targets should follow the same model instead of adding target-specific launch semantics to the worker entrypoint.

The expected security posture is non-privileged execution: run as a regular user, avoid privileged containers, disable privilege escalation, drop Linux capabilities where possible, and grant write access only to the workspace, `SVDO_HOME`, and `SVDO_TMPDIR` paths needed by the work unit. CPU, memory, network, credential, and filesystem policies are owned by the invoking runtime or orchestrator.

Runtime integrations may add manifests, wrapper scripts, image variants, or deployment examples, but they should keep the worker contract stable. Scheduling, retries, queue selection, repository checkout, ticket assignment, worker registration, and result collection belong outside this repository.

Runtime failures are intentionally loud. The entrypoint exits non-zero with a readable `svdo-worker:` error when no work instruction is supplied, the workspace is missing or unreadable, `SVDO_HOME` is missing or unwritable, `SVDO_TMPDIR` or its meter output directory is unwritable, `SVDO_METER_CONFIG` is missing or unreadable, `SVDO_METER_BIN` is missing or not executable, or `SVDO_WORKER_MODE` is unsupported. It must not silently bypass `svdo-meter`.

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

The current `svdo-meter` CLI is flag-driven and does not consume `config/meter.yaml` directly. The bundled config file documents the worker metadata contract and is reserved for meter config support as it evolves. The worker uses `svdo-meter run --output-dir` to keep durable meter telemetry in `${SVDO_TMPDIR}/meter` by default.

If `svdo-meter` adds a generic subprocess wrapper later, `SVDO_WORKER_MODE=raw` can be used with:

```bash
svdo-meter ${SVDO_METER_ARGS} -- <command> [args...]
```

## Run

Run a local workspace through `svdo-meter` with isolated agent state and temp output:

```bash
examples/run-local-workspace.sh "$PWD" \
  "Inspect the workspace and summarize the current repository status."
```

The script mounts only the selected workspace as project source at `/workspace`.
Agent state is written to `${XDG_STATE_HOME:-$HOME/.local/state}/svdo-worker/home` by default and mounted as `/home/svdo`.
Transient files and meter output are written to `${TMPDIR:-/tmp}/svdo-worker` by default and mounted as `/tmp/svdo-worker`.
Override those host locations with `SVDO_WORKER_STATE_DIR` and `SVDO_WORKER_TMP_DIR`.

Inject a meter config without mounting additional project source:

```bash
SVDO_METER_CONFIG_FILE="$PWD/config/meter.yaml" \
  examples/run-local-workspace.sh "$PWD" \
  "Run the local smoke checks."
```

Intentionally pass additional `svdo-meter run` flags with `SVDO_METER_EXTRA_ARGS`:

```bash
SVDO_METER_EXTRA_ARGS="--emit ndjson --codex-sandbox workspace-write" \
  examples/run-local-workspace.sh "$PWD" \
  "Run the test suite and report failures."
```

Override the default meter output directory only when the invoking runtime owns another durable artifact path:

```bash
SVDO_METER_EXTRA_ARGS="--output-dir /workspace/.svdo/meter --emit ndjson" \
  examples/run-local-workspace.sh "$PWD" \
  "Run the test suite and report failures."
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
- `examples/kubernetes/README.md`: explain the Kubernetes work-unit model, volume assumptions, ConfigMap/Secret guidance, and security posture.
- `examples/kubernetes/job.yaml`: show the same runtime contract as a non-privileged Kubernetes Job-style work-unit container.

## Validation

Validate entrypoint argument translation locally without Podman:

```bash
bash tests/validate-entrypoint.sh
```

Validate image builds and the default metered-run path where Podman is available:

```bash
bash tests/validate-image-build.sh
```

For release gates or CI jobs that must prove the container build/run contract, require a working Podman engine instead of accepting the local skip path:

```bash
SVDO_REQUIRE_PODMAN=1 bash tests/validate-image-build.sh
```

By default the image validation builds with a test fixture meter so it can prove the container entrypoint invokes `svdo-meter run` without reaching the `svdo-meter` upstream installer or requiring agent authentication. To exercise the real installer, run:

```bash
SVDO_IMAGE_TEST_METER_INSTALL_METHOD=release bash tests/validate-image-build.sh
```

The real installer requires network access unless your Podman build environment has cached or mirrored release/source assets. Missing or invalid meter config and meter binary failures are covered by `tests/validate-entrypoint.sh`. Full measured Codex or Claude runs also require the selected agent CLI to be installed and authenticated in the image.

## Extension Points

- Set `SVDO_METER_EXTRA_ARGS` for current `svdo-meter run` flags such as `--emit ndjson` or `--codex-sandbox workspace-write`.
- Set `SVDO_WORKER_MODE=raw` and override `SVDO_METER_ARGS` only for a future or downstream generic subprocess wrapper.
- Override `SVDO_METER_CONFIG` and mount a different config file.
- Build downstream images from a variant to add a specific agent CLI.
- Add new language variants under `images/<variant>/Containerfile`.
- Add infrastructure-specific manifests or wrapper scripts that preserve the runtime contract.

## Non-Goals

This repository must not include ticket management, worktree creation, branch management, queues, schedulers, HTTP APIs, worker registries, GitHub integration, always-running daemons, Docker Compose stacks, Kubernetes controllers, CRDs, or other orchestration logic.

Kubernetes files in `examples/` are runtime-manifest examples for a single work-unit container. They are not scheduling logic and do not make this repository responsible for cluster operations, workspace provisioning, worker registration, or ticket orchestration.
