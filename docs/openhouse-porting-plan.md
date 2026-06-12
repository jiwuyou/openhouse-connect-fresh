# OpenHouse Porting Plan

This plan keeps OpenHouse close to current `cc-connect` and avoids reviving the
old webclient fork. SmallPhone integration should be a thin runtime overlay
around upstream APIs.

## Goals

- Base OpenHouse on the latest viable `chenhg5/cc-connect`, not a stale fork.
- Use upstream Bridge, Management API, Webhook, hooks, and agent providers.
- Keep SmallPhone/service-manager packaging outside generic upstream modules.
- Upstream broadly useful Bridge and attachment work.
- Keep device-specific APK payload, env loading, and proot launch behavior in
  `overlay/smallphone/`.

## Non-Goals

- Do not fork `core/`, `agent/`, or generic web socket hooks for SmallPhone.
- Do not copy the old OpenHouse webclient into this tree.
- Do not store runtime secrets in git.
- Do not make payload build scripts fetch dependencies from the network.

## Workstreams

1. Upstream tracking
   - Track upstream in a clean local integration branch.
   - Use `scripts/openhouse-sync-cc-connect.sh` to fetch and fast-forward only.
   - Review upstream conflicts explicitly.

2. SmallPhone overlay
   - Keep APK payload examples under `overlay/smallphone/`.
   - Reserve ports:
     - `21010`: Bridge WebSocket and Bridge REST.
     - `21020`: Management API and embedded web access.
     - `21040`: Webhook or local callback ingress.
   - Load provider and agent environment from
     `/root/.smallphoneai/agent-env`.
   - Start cc-connect in Ubuntu/proot through `bash -lc` so shell-managed agent
     CLIs resolve the same way they do interactively.

3. service-manager integration
   - Register the cc-connect wrapper as a managed service.
   - Expose health checks against local OpenHouse ports.
   - Keep service-manager schema examples in the overlay, not upstream modules.

4. Upstreamable bridge behavior
   - Bridge-only project validation should be proposed upstream. Today strict
     config validation requires at least one `[[projects.platforms]]`, while
     Bridge is attached after engine creation.
   - Attachment send-back and session APIs should remain platform-neutral.
   - Any generic agent/provider env behavior should be documented upstream when
     it applies beyond SmallPhone.

## Acceptance Checklist

- OpenHouse docs describe latest-upstream tracking.
- Overlay files can be bundled into an APK payload without network access.
- Examples use ports `21010`, `21020`, and `21040`.
- Runtime secrets are loaded from `/root/.smallphoneai/agent-env` and are not
  committed.
- Sync script exits on dirty working trees and uses only non-destructive git
  operations.
- Payload build script packages only local overlay, config, and scripts.
