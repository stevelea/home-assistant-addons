# Codewhale Terminal

Codewhale in a web terminal, as a Home Assistant add-on.

## About

This add-on runs the [Codewhale](https://github.com/Hmbown/CodeWhale) coding agent — a Rust TUI/CLI for DeepSeek, OpenAI-compatible gateways, OpenRouter, Ollama, Moonshot/Kimi, and 30+ other hosted and local models — in a browser-based terminal (ttyd + tmux) with your Home Assistant configuration mounted. Open it from the sidebar, set an API key once, and ask Codewhale to write automations, debug YAML, or manage your setup.



## Installation

1. Add this repository to your Home Assistant add-on store
2. Install the Codewhale Terminal add-on
3. Configure at minimum `provider` and `api_key` (see [Options](#options))
4. Start the add-on
5. Click **OPEN WEB UI** to access the terminal

Your configuration, sessions, and MCP registrations are stored under `/data` and persist across restarts and add-on updates.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `provider` | `"deepseek"` | Codewhale provider to use (see [providers](#providers)). |
| `api_key` | `""` | API key for the provider. Leave empty if you authenticate another way (e.g. an env-var key baked into a custom image). |
| `base_url` | `""` | Optional endpoint override for the provider (e.g. a self-hosted OpenAI-compatible gateway). |
| `default_text_model` | `""` | Optional model to use; empty lets Codewhale pick its default for the provider. |
| `reasoning_effort` | `"auto"` | Reasoning budget (`auto` / `low` / `medium` / `high` / `max`). |
| `extra_config` | `""` | Extra TOML appended to `~/.codewhale/config.toml` — e.g. additional `[providers.<name>]` sections. |
| `auto_launch_codewhale` | `true` | Start Codewhale immediately when the terminal opens. Set to `false` to get a shell instead (run `codewhale` yourself). |
| `codewhale_auto_update` | `true` | Keep Codewhale current: maintains a persistent copy in `/data` and updates it in the background on each startup. |
| `dangerously_skip_permissions` | `false` | Sets `approval_policy = "never"` — Codewhale runs tools without asking. **Read the security note below.** |
| `codewhale_extra_args` | `""` | Extra flags appended to every Codewhale launch, e.g. `--max-subagents 4`. Values are split on spaces; quoted multi-word arguments are not supported. |
| `ha_smart_context` | `true` | Generate an `AGENTS.md` with your HA system info so Codewhale knows your setup. |
| `enable_ha_mcp` | `true` | Register the [ha-mcp](https://github.com/homeassistant-ai/ha-mcp) MCP server so Codewhale can control Home Assistant directly. |
| `ha_mcp_version` | `"7.11.0"` | ha-mcp release to run. |
| `persistent_apt_packages` | `[]` | apt packages reinstalled on every startup. |
| `persistent_pip_packages` | `[]` | Python packages reinstalled on every startup. |

## Usage

With default settings, Codewhale launches automatically inside a tmux session named `codewhale`. Navigating away in Home Assistant and coming back reattaches to the same session — your conversation survives.

Useful commands (in shell mode, or after exiting Codewhale):

```bash
codewhale             # start the Codewhale coding agent
codewhale -c          # continue the most recent session
codewhale -r          # pick a past session to resume
codewhale-doctor      # diagnose network, auth, and environment issues
codewhale-reconfigure # regenerate config.toml from the add-on options
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

## Providers

Set `provider` to any Codewhale provider ID — e.g. `deepseek` (default), `openai`, `openrouter`, `moonshot`, `ollama`, `vllm`, `sglang`, `openmodel`, `stepfun`, `minimax`, `deepinfra`, `xai`, `siliconflow`, `arcee`, `fireworks`, `together`, `novita`, `qianfan`, `zai`, `atlascloud`, `wanjie-ark`, `volcengine`, `huggingface`, `nvidia-nim`, `deepseek-anthropic`, `opencode-zen`, and more. Use `base_url` to point an OpenAI-compatible provider at a custom endpoint, and `extra_config` to define additional providers:

```toml
# Example extra_config: a second provider alongside the primary one
[providers.moonshot]
api_key = "sk-..."
base_url = "https://api.moonshot.ai/v1"
default_text_model = "kimi-k3"
```

Then switch with `provider = "moonshot"` (or set `CODEWHALE_PROVIDER`-style env overrides at runtime). See the [Codewhale provider docs](https://github.com/Hmbown/CodeWhale/blob/main/docs/PROVIDERS.md) for the full list and per-provider defaults.

## Home Assistant MCP Integration

The bundled [ha-mcp](https://github.com/homeassistant-ai/ha-mcp) server connects Codewhale to Home Assistant through the Supervisor API — no token setup needed. Codewhale can query states, control devices, and manage automations, scripts, and dashboards in natural language.

ha-mcp requires Python 3.13, which Ubuntu 24.04 doesn't ship — the add-on provisions a managed Python build via [uv](https://github.com/astral-sh/uv) into `/data` on first use (a one-time ~150–250 MB download that persists across restarts and is included in HA backups). The environment is pre-warmed in the background at startup so the first MCP connection is fast.

Disable it with `enable_ha_mcp: false` if you don't want Codewhale to have this access.

## Security

- **`dangerously_skip_permissions: true`** sets `approval_policy = "never"`: Codewhale executes tool calls without asking. It has write access to `/config` and can control Home Assistant through the Supervisor API and MCP. Only enable this in trusted environments.
- Your API key is stored in `/data/.codewhale/config.toml` (mode 600), which is included in HA backups — treat backups accordingly.
- The add-on requests `hassio_role: manager` for the HA integration; drop `enable_ha_mcp` and the Supervisor API features if you want a stricter posture.

## Troubleshooting

- **"No api_key found"**: set the `api_key` option (and `provider`), then run `codewhale-reconfigure` in the terminal, or restart the add-on.
- **Codewhale won't start**: run `codewhale-doctor` inside the terminal for a health report (binaries, config, HA connectivity).
- **First MCP call is slow**: that's the one-time uv/Python 3.13 provisioning; it is pre-warmed at startup and persists in `/data`.
- **aarch64 users**: the Codewhale arm64 binary requires glibc ≥ 2.39, which the Ubuntu 24.04 base provides. If a future Codewhale release raises the glibc floor, bump the base image.
- **Report issues** in this repository's issue tracker.
