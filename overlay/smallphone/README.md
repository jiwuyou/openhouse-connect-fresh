# SmallPhone Overlay

This directory contains OpenHouse files that are safe to bundle into a
SmallPhone APK payload. It is intentionally separate from upstream cc-connect
source modules.

## Contents

- `bin/openhouse-cc-connect-wrapper.sh`: launches cc-connect after loading
  `/root/.smallphoneai/agent-env`, using `bash -lc` for Ubuntu/proot.
- `env/agent-env.example`: variable-name template with empty values only.
- `service-manager/cc-connect.service.json`: service-manager registration
  template matching the `ServiceSpec` shape used by service-manager.

The canonical config example is outside this overlay:

```text
config/openhouse-smallphone.example.toml
```

The payload build script packages this overlay, the config example, the
offline `cc-connect` ARM64 binary, and runtime scripts:

```bash
scripts/openhouse-build-smallphone-payload.sh
```

## Runtime Ports

- `21010`: Bridge WebSocket and Bridge REST.
- `21020`: Management API and embedded web access.
- `21040`: Webhook or local callback ingress.

## Secret Policy

Do not place real secrets in the overlay. Runtime secrets belong in:

```text
/root/.smallphoneai/agent-env
```

The wrapper sources that file without printing values.
`scripts/register-service.sh` creates this file from a device-local
OpenHouseAI Claude Code shell block when available; otherwise it leaves a
600-permission placeholder for on-device setup.
