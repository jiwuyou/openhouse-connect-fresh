# OpenHouse Upstream Tracking Policy

OpenHouse tracks `chenhg5/cc-connect` from the newest viable upstream baseline.
The starting audit baseline for this branch is `c53f5450`, but new integration
work should regularly rebase or merge from current upstream instead of carrying
an old webclient fork.

## Strategy

- Keep upstream `cc-connect` as the base product.
- Do not copy the old OpenHouse webclient split into this repository.
- Treat SmallPhone and service-manager integration as an overlay that connects
  through upstream extension points, primarily Bridge, Management API, Webhook,
  hooks, and agent configuration.
- Keep SmallPhone-only packaging, APK payload files, proot launch wrappers, and
  service-manager templates under `overlay/smallphone/`.
- Move generic bridge, attachment, reference rendering, and session management
  improvements upstream whenever they are not SmallPhone-specific.

## Branch Model

Use a local integration branch for OpenHouse work, for example:

```bash
scripts/openhouse-sync-cc-connect.sh
```

The sync script is intentionally conservative:

- It refuses to run with a dirty working tree.
- It fetches the configured upstream remote.
- It creates the integration branch from the fetched upstream branch when the
  branch does not exist.
- It updates an existing integration branch only with a fast-forward merge.
- It does not use destructive history or working-tree operations.

If fast-forward is not possible, resolve the upstream integration manually in a
separate review. Do not hide conflicts by replacing local commits.

## Overlay Boundary

The overlay may contain:

- SmallPhone APK payload layout.
- Local config examples for ports `21010`, `21020`, and `21040`.
- Environment loading examples for `/root/.smallphoneai/agent-env`.
- `bash -lc` wrappers for Ubuntu/proot execution.
- service-manager registration templates.
- Notes that explain how SmallPhone calls Bridge or Management API.

The overlay must not contain:

- Real API keys, tokens, cookies, or account secrets.
- Copied upstream webclient code.
- Forked copies of generic `core/`, `agent/`, or web socket hook logic.
- Network dependency downloads during payload build.

## Upstream Candidates

Prefer upstream PRs for changes with general value:

- Allow Bridge-only projects to pass strict config validation when `[bridge]`
  is enabled. The current engine can accept a Bridge platform after startup,
  but strict config loading still requires at least one configured platform.
- Keep attachment send-back and file/image delivery platform-neutral.
- Keep Bridge session APIs and event envelopes usable by any external adapter,
  not only SmallPhone.
- Improve management and bridge documentation in upstream docs when behavior is
  not OpenHouse-specific.

Keep these in the overlay:

- SmallPhone port assignments.
- APK payload paths.
- proot or Ubuntu launch assumptions.
- service-manager registration shape.
- Device-local env file location and secret handling policy.

## Secret Handling

OpenHouse examples load secrets from `/root/.smallphoneai/agent-env`. This file
is runtime state, not source. Templates may list variable names, but must leave
values empty and must not print loaded secrets. Recommended permissions:

```bash
chmod 600 /root/.smallphoneai/agent-env
```

Common prefixes used by agents and providers include `ANTHROPIC_`, `OPENAI_`,
`CODEX_`, `OPENCODE_`, `GEMINI_`, `GOOGLE_`, `AWS_`, and proxy variables.
