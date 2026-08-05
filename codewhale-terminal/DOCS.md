# Codewhale Terminal

Codewhale in a web terminal, as a Home Assistant add-on.

## About

This add-on runs the [Codewhale](https://github.com/Hmbown/CodeWhale) coding agent — a Rust TUI/CLI for DeepSeek, OpenAI-compatible gateways, OpenRouter, Ollama, Moonshot/Kimi, and 30+ other hosted and local models — in a browser-based terminal (ttyd + tmux) with your Home Assistant configuration mounted. Open it from the sidebar, set an API key once, and ask Codewhale to write automations, debug YAML, or manage your setup.

## Installation

1. Add this repository to your Home Assistant add-on store
2. Install the Codewhale Terminal add-on
3. Optionally set an `api_key` in the add-on options (first-boot bootstrap); provider/model are configured inside Codewhale (see [Provider & model configuration](#provider--model-configuration))
4. Start the add-on
5. Click **OPEN WEB UI** to access the terminal

Your configuration, sessions, and MCP registrations are stored under `/data` and persist across restarts and add-on updates.

## Options

Only add-on-level settings live here — Codewhale's own settings (provider, model, endpoint, reasoning effort, extra providers) are configured inside Codewhale, not on this page.

| Option | Default | Description |
|--------|---------|-------------|
| `api_key` | `""` | **First-boot bootstrap only**: written into the initial `~/.codewhale/config.toml` (provider `deepseek`). After first boot, set/rotate keys inside Codewhale (`codewhale auth set --provider <name> --api-key-stdin`) — this field is ignored. |
| `auto_launch_codewhale` | `true` | Start Codewhale immediately when the terminal opens. Set to `false` to get a shell instead (run `codewhale` yourself). |
| `codewhale_auto_update` | `true` | Keep Codewhale current: maintains a persistent copy in `/data` and updates it in the background on each startup. |
| `dangerously_skip_permissions` | `false` | Launches Codewhale with `CODEWHALE_APPROVAL_POLICY=never` — runs tools without asking. **Read the security note below.** |
| `codewhale_extra_args` | `""` | Extra flags appended to every Codewhale launch, e.g. `--max-subagents 4`. Values are split on spaces; quoted multi-word arguments are not supported. |
| `ha_smart_context` | `true` | Generate an `AGENTS.md` with your HA system info so Codewhale knows your setup. |
| `enable_ha_mcp` | `true` | Register the [ha-mcp](https://github.com/homeassistant-ai/ha-mcp) MCP server so Codewhale can control Home Assistant directly. |
| `ha_mcp_version` | `"7.11.0"` | ha-mcp release to run. |
| `persistent_apt_packages` | `[]` | apt packages reinstalled on every startup. |
| `persistent_pip_packages` | `[]` | Python packages reinstalled on every startup. |

## Provider & model configuration

Codewhale owns `~/.codewhale/config.toml` (in `/data/.codewhale`) after first boot. Configure the provider, model, endpoint, and additional providers **inside the terminal**:

```bash
codewhale auth set --provider deepseek --api-key-stdin   # set or rotate an API key
codewhale auth status                                    # see the active provider
codewhale auth list                                      # all providers + auth state
# or run `codewhale` and use its built-in /provider onboarding
# or edit ~/.codewhale/config.toml directly (mode 600)
codewhale-reconfigure                                    # re-apply add-on settings (ha-mcp) without restarting
```

Anything you change persists in `/data` across restarts and add-on updates, and the add-on never rewrites the file. Example `config.toml` for a second provider:

```toml
provider = "deepseek"

[providers.moonshot]
api_key = "sk-..."
base_url = "https://api.moonshot.ai/v1"
default_text_model = "kimi-k3"
```

Then switch with `provider = "moonshot"`. See the [Codewhale provider docs](https://github.com/Hmbown/CodeWhale/blob/main/docs/PROVIDERS.md) for the full provider list and per-provider defaults.

## Usage

With default settings, Codewhale launches automatically inside a tmux session named `codewhale`. Navigating away in Home Assistant and coming back reattaches to the same session — your conversation survives.

Useful commands (in shell mode, or after exiting Codewhale):

```bash
codewhale             # start the Codewhale coding agent
codewhale -c          # continue the most recent session
codewhale -r          # pick a past session to resume
codewhale-doctor      # diagnose network, auth, and environment issues
codewhale-reconfigure # re-apply add-on settings (ha-mcp) without restarting
persist-install apt htop   # install packages that survive restarts
ha-context            # refresh the Home Assistant context file
```

### Terminal tips

- **Scrolling**: use the mouse wheel — tmux copy-mode opens automatically. Press `q` to jump back to the bottom.
- **Copying**: select text with the mouse; on release it's copied to your clipboard (OSC 52). Note: browsers only allow clipboard writes on secure pages — if you access Home Assistant over plain `http://`, use Shift+drag instead.
- **Shift+drag**: bypasses tmux and gives you the browser's native text selection (copy with `Ctrl+C` / right-click).
- **Pasting**: use `Ctrl+Shift+V` (or right-click, depending on browser).

### File access

The terminal starts in `/config` (your Home Assistant configuration). Also mounted:

- `/addon_configs` — configuration directories of your other add-ons
- `/share` — the shared folder

Codewhale's own state lives in `/data/.codewhale` (config.toml, mcp.json, sessions).

## Home Assistant MCP Integration

The bundled [ha-mcp](https://github.com/homeassistant-ai/ha-mcp) server connects Codewhale to Home Assistant through the Supervisor API — no token setup needed. Codewhale can query states, control devices, and manage automations, scripts, and dashboards in natural language.

ha-mcp requires Python 3.13, which Ubuntu 24.04 doesn't ship — the add-on provisions a managed Python build via [uv](https://github.com/astral-sh/uv) into `/data` on first use (a one-time ~150–250 MB download that persists across restarts and is included in HA backups). The environment is pre-warmed in the background at startup so the first MCP connection is fast.

Disable it with `enable_ha_mcp: false` if you don't want Codewhale to have this access.

## Security

- **`dangerously_skip_permissions: true`** launches Codewhale with `CODEWHALE_APPROVAL_POLICY=never`: it executes tool calls without asking. It has write access to `/config` and can control Home Assistant through the Supervisor API and MCP. Only enable this in trusted environments.
- Your API key is stored in `/data/.codewhale/config.toml` (mode 600), which is included in HA backups — treat backups accordingly.
- The Supervisor token is persisted in `/data/.codewhale/mcp.json` and `/data/supervisor.token` (both mode 600) — same backup consideration.
- The add-on requests `hassio_role: manager` for the HA integration; drop `enable_ha_mcp` and the Supervisor API features if you want a stricter posture.

## Troubleshooting

- **"No api_key found"**: configure a key inside Codewhale: `codewhale auth set --provider deepseek --api-key-stdin` (or set the `api_key` option before first boot).
- **Codewhale won't start**: run `codewhale-doctor` inside the terminal for a health report (binaries, config, HA connectivity).
- **First MCP call is slow**: that's the one-time uv/Python 3.13 provisioning; it is pre-warmed at startup and persists in `/data`.
- **aarch64 users**: the Codewhale arm64 binary requires glibc ≥ 2.39, which the Ubuntu 24.04 base provides. If a future Codewhale release raises the glibc floor, bump the base image.
- **Report issues** in this repository's issue tracker.
