# Config Placement

The source config template lives at:

```text
config/openhouse-smallphone.example.toml
```

APK packaging may copy it into this overlay layout as:

```text
/opt/openhouse/config/openhouse-smallphone.example.toml
```

Runtime devices should copy or render the final config to:

```text
/root/.smallphoneai/cc-connect.toml
```

Keep real tokens in `/root/.smallphoneai/agent-env`, not in bundled config.
