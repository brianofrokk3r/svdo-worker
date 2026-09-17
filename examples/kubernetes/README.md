# Kubernetes Work-Unit Job Example

`job.yaml` shows how to run `svdo-worker` as a single Kubernetes Job using the same runtime contract as the Podman examples.

The manifest is intentionally only a runtime example. It does not schedule tickets, register workers, clone repositories, collect results, run a queue, expose an API, or define a controller.

## Runtime Contract

The Job maps the worker contract into Kubernetes primitives:

| Worker setting | Kubernetes representation |
| --- | --- |
| `SVDO_WORKSPACE=/workspace` | Required workspace volume mount. The sample uses a PVC named `svdo-workspace`. |
| `SVDO_HOME=/home/svdo` | Writable agent state volume. The sample uses `emptyDir`; use a PVC if state must survive the pod. |
| `SVDO_TMPDIR=/tmp/svdo-worker` | Writable transient and meter-output volume. The worker passes `--output-dir ${SVDO_TMPDIR}/meter` by default. The sample uses `emptyDir`. |
| `SVDO_METER_CONFIG=/etc/svdo-worker/meter.yaml` | ConfigMap-mounted config file in the sample. Use a Secret-mounted file instead when meter config includes sensitive values. |
| `SVDO_METER_BIN=/usr/local/bin/svdo-meter` | Meter binary installed in the worker image. |
| `SVDO_WORKER_MODE=harness` | Default measured `svdo-meter run` path. |
| `SVDO_METER_EXTRA_ARGS` | Optional operator-controlled extra flags for `svdo-meter run`. Include `--output-dir <path>` only when intentionally replacing the default `${SVDO_TMPDIR}/meter` sink. |

The workspace mount is the only required project source mount. Kubernetes operators are responsible for preparing that volume through their own checkout, CSI, PVC, or initContainer strategy.

## Security Posture

The sample avoids privileged execution by default:

- `runAsNonRoot: true`
- fixed non-root UID/GID
- `allowPrivilegeEscalation: false`
- `privileged: false`
- all Linux capabilities dropped
- `seccompProfile: RuntimeDefault`

The root filesystem is left writable in the sample because common CLI agents and package managers may write outside the explicit state and temp paths. Operators with stricter images can set `readOnlyRootFilesystem: true` after confirming the selected agent and tooling only write to mounted paths.

## Config And Secrets

The sample meter config is a ConfigMap because it contains non-secret runtime metadata. If meter configuration or agent provider settings include secrets, inject them with a Kubernetes Secret and mount or expose only the specific keys needed by the selected agent.

Provider credentials are shown as commented `secretKeyRef` environment variables in the manifest. Sensitive meter config can follow the same pattern by replacing the ConfigMap volume with a Secret volume that mounts the key at `/etc/svdo-worker/meter.yaml`. The worker does not define credential names or required providers.

## Running The Example

Build and push a worker image that includes `svdo-meter` and the selected agent CLI, then update:

- `containers[0].image`
- `volumes[].persistentVolumeClaim.claimName`
- the work instruction in `containers[0].args`
- optional metadata such as `SVDO_TICKET_ID`, `SVDO_WORK_UNIT_ID`, `SVDO_AGENT`, and `SVDO_METER_EXTRA_ARGS`

Then apply the manifest with your normal cluster tooling:

```bash
kubectl apply -f examples/kubernetes/job.yaml
```

Use this example as a template for a single work unit. Scheduling, retry policy beyond the Job fields, workspace provisioning, result collection, and ticket orchestration belong to the invoking platform.
