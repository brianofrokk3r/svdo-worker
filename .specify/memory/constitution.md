# svdo-worker Constitution

## Principles

### Container-Side Runtime Only
`svdo-worker` is a narrow OCI runtime contract for SVDO work units. It must not own orchestration responsibilities such as queues, schedulers, worktree creation, ticket management, branch management, registries, HTTP APIs, GitHub integration, Kubernetes manifests, Compose stacks, or daemons.

### Metered by Default
Every command launched through the worker entrypoint must execute under `svdo-meter` unless a maintainer intentionally changes the runtime contract. Telemetry configuration must be explicit, file-based, and overrideable by environment variables.

### Rootless Podman First
The initial backend target is rootless Podman. Runtime examples and defaults must favor least privilege, mounted workspaces, read-only image contents where practical, explicit temp directories, and isolated container home directories.

### Minimal Base, Focused Variants
The base image must stay Debian-based and small. It may include only broadly useful worker dependencies plus `svdo-meter`. Language toolchains and large SDKs belong in separate variants.

### Predictable Runtime Contract
The worker must document and enforce stable conventions for workspace path, home path, temp path, meter configuration, metadata environment variables, and command execution.

## Quality Gates

- Functional specs, plans, and task lists live under `specs/`.
- Runtime shell must use strict mode and fail clearly for invalid configuration.
- Validation must cover entrypoint behavior and basic image buildability where Podman is available.
- Documentation must distinguish responsibilities from explicit non-goals.
