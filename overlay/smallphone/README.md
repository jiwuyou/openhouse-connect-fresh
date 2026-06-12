# SmallPhone Overlay

This directory contains OpenHouse files that are safe to bundle into a
SmallPhone APK payload. It is intentionally separate from upstream cc-connect
source modules.

## Contents

- `bin/openhouse-cc-connect-wrapper.sh`: launches cc-connect after loading
  `/root/.smallphoneai/agent-env`, using `bash -lc` for Ubuntu/proot.
- `env/agent-env.example`: variable-name template with empty values only.
- `service-manager/cc-connect.service.json`: service-manager registration
  template.

The canonical config example is outside this overlay:

```text
config/openhouse-smallphone.example.toml
```

The payload build script packages both this overlay and the config example:

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
