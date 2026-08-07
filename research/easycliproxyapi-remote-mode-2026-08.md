# EasyCLIProxyAPI v0.2.16 remote-mode investigation

Date: 2026-08-07. Primary sources checked: EasyCLIProxyAPI tag `v0.2.16` (release commit `7281fece062885947a0657f3116a936e05173b9f`) and current CLIProxyAPI HEAD (`31a4e9b4870f4510f3e2b8c5122236b67a61f730`).

## Finding

The published EasyCLIProxyAPI v0.2.16 source does **not** contain a remote-mode server URL/login flow. Its management request path is hard-coded to `http://127.0.0.1:{configured-port}/v0/management/{path}`, and its credential is the plaintext management secret sent as `Authorization: Bearer <secret>`. The visible GUI controls are local-core controls: **WebUI key** section, **New key**, **Confirm key**, **Generate**, **Save**, and **Open**. Therefore there are no v0.2.16 GUI fields named Remote mode, Server URL/Base URL, or remote management password to fill in.

Evidence: [management request command](https://github.com/router-for-me/EasyCLIProxyAPI/blob/7281fece062885947a0657f3116a936e05173b9f/src-tauri/src/main.rs#L10282-L10319), [endpoint and Authorization construction](https://github.com/router-for-me/EasyCLIProxyAPI/blob/7281fece062885947a0657f3116a936e05173b9f/src-tauri/src/main.rs#L15338-L15354), [GUI WebUI-key fields](https://github.com/router-for-me/EasyCLIProxyAPI/blob/7281fece062885947a0657f3116a936e05173b9f/src/pages/ConfigPanel.tsx#L692-L805).

## CLIProxyAPI settings needed

To expose the management API, set a non-empty plaintext management secret and keep the panel enabled:

```yaml
remote-management:
  allow-remote: false
  secret-key: "<new-management-secret>"
  disable-control-panel: false
```

CLIProxyAPI hashes a plaintext `secret-key` at startup and persists the bcrypt hash, but clients must continue to send the original plaintext secret. All management requests, including localhost, require the management key. `allow-remote: true` is required only for non-localhost clients; it is **not required for a client running on ceres and connecting to 127.0.0.1**.

Evidence: [current example YAML](https://github.com/router-for-me/CLIProxyAPI/blob/31a4e9b4870f4510f3e2b8c5122236b67a61f730/config.example.yaml#L198-L218), [management API authentication and localhost/remote rules](https://help.router-for.me/management/api), [current config model and hashing behavior](https://github.com/router-for-me/CLIProxyAPI/blob/31a4e9b4870f4510f3e2b8c5122236b67a61f730/internal/config/config.go#L530-L565).

## Credential distinction

- **Management secret**: the value in `remote-management.secret-key`; use it for EasyCLIProxyAPI management requests. Do not paste the bcrypt hash.
- **Proxy API keys**: entries under CLIProxyAPI `api-keys`; these authenticate model/proxy traffic, not `/v0/management`.

## Practical consequence for ceres

With v0.2.16, the exact local management endpoint is `http://127.0.0.1:8317/v0/management/...`; there is no supported v0.2.16 way in the GUI to substitute a remote server URL. First add `remote-management.secret-key`, restart the Home Manager service, then use a build/version that explicitly implements remote mode if the GUI must connect to another process by URL. If EasyCLIProxyAPI itself runs on ceres, its hard-coded localhost target is already the correct target; only the management secret is missing.
