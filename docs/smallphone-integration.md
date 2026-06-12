# SmallPhone Integration

SmallPhone should connect to OpenHouse through upstream cc-connect interfaces
instead of carrying a copied webclient fork. The intended path is:

```text
SmallPhone UI or service-manager
  -> Bridge on 127.0.0.1:21010
  -> cc-connect engine and configured agent
  -> optional Management API on 127.0.0.1:21020
  -> optional Webhook on 127.0.0.1:21040
```

## Port Map

| Port | Owner | Purpose |
| ---- | ----- | ------- |
| `21010` | cc-connect `[bridge]` | Bridge WebSocket and Bridge REST for SmallPhone adapters. |
| `21020` | cc-connect `[management]` | Management API and embedded web access. |
| `21040` | cc-connect `[webhook]` | Local callbacks from service-manager, file watchers, or APK glue. |

Do not use upstream default ports in APK-bundled examples. The fixed OpenHouse
ports make service-manager registration deterministic.

## Runtime Environment

Agent and provider variables are loaded from:

```text
/root/.smallphoneai/agent-env
```

This file is a shell fragment owned by the device runtime. It may define
variables such as:

- `ANTHROPIC_API_KEY`, `ANTHROPIC_BASE_URL`, `ANTHROPIC_MODEL`
- `OPENAI_API_KEY`, `OPENAI_BASE_URL`, `OPENAI_MODEL`
- `CODEX_HOME`, `CODEX_API_KEY`
- `OPENCODE_CONFIG`, `OPENCODE_DISABLE_AUTOUPDATE`
- `GEMINI_API_KEY`, `GOOGLE_APPLICATION_CREDENTIALS`
- `HTTP_PROXY`, `HTTPS_PROXY`, `NO_PROXY`

Never commit real values. The repository only carries
`overlay/smallphone/env/agent-env.example`.

Recommended setup on device:

```bash
mkdir -p /root/.smallphoneai
cp overlay/smallphone/env/agent-env.example /root/.smallphoneai/agent-env
chmod 600 /root/.smallphoneai/agent-env
```

## Ubuntu/proot Launch

When cc-connect runs inside Ubuntu/proot, launch through `bash -lc`. This keeps
agent CLIs closer to an interactive shell environment and lets PATH, shell
profiles, and runtime env setup behave predictably.

The overlay wrapper is:

```text
overlay/smallphone/bin/openhouse-cc-connect-wrapper.sh
```

The wrapper:

- sources `/root/.smallphoneai/agent-env` with auto-export enabled;
- does not print secret values;
- runs cc-connect through `/bin/bash -lc`;
- supports an optional `OPENHOUSE_PROOT_CMD` prefix when the service-manager
  must enter a proot environment before launching cc-connect.

## service-manager Registration

Use this template as the registration shape:

```text
overlay/smallphone/service-manager/cc-connect.service.json
```

The template points service-manager at the wrapper and declares the three local
ports. Adapt only device-specific paths, binary locations, and service-manager
schema fields. Keep tokens and API keys in `/root/.smallphoneai/agent-env`.

## Config Example

The config template is:

```text
config/openhouse-smallphone.example.toml
```

It enables Bridge, Management API, and Webhook on the OpenHouse port map.

Important current-upstream note: strict config loading currently requires at
least one `[[projects.platforms]]` entry. A Bridge-only project is the desired
OpenHouse shape, because Bridge is attached after engine creation. The small
upstreamable fix is to allow zero configured platforms when `[bridge].enabled`
is true. Until that lands, keep any local compatibility workaround in the
integration branch and do not fork generic core behavior in the overlay.

## Payload Build

Build a local payload archive without network access:

```bash
scripts/openhouse-build-smallphone-payload.sh
```

The payload contains only:

- `overlay/smallphone/`
- `config/openhouse-smallphone.example.toml`
- `scripts/openhouse-sync-cc-connect.sh`
- `scripts/openhouse-build-smallphone-payload.sh`
