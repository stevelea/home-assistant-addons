# Changelog

## 0.1.3

Slim the add-on configuration page: Codewhale owns its own config after first boot.

- Removed from add-on options: `provider`, `base_url`, `default_text_model`,
  `reasoning_effort`, `extra_config` — all are Codewhale-native settings,
  configured inside the terminal (`codewhale auth set`, `/provider`
  onboarding, or editing `~/.codewhale/config.toml`) and persisting in `/data`.
- `config.toml` is now bootstrapped once (deepseek + optional `api_key`) and
  then left to Codewhale — add-on option changes never rewrite it.
- `dangerously_skip_permissions` now sets `CODEWHALE_APPROVAL_POLICY=never`
  at launch instead of editing config.toml.
- `api_key` add-on option is a first-boot bootstrap convenience only.

## 0.1.2

- Persist the Supervisor token to `/data/supervisor.token` (mode 600) at every
  boot, as a standalone copy for in-container tools and scripts. Refreshed on
  each start; never clobbered with an empty value (e.g. when the container is
  run manually outside a real Supervisor). The token was already carried in
  `/data/.codewhale/mcp.json` for ha-mcp; this makes it directly readable.

## 0.1.1

Fix: ha-mcp MCP server registration.

- Register ha-mcp with argv-form command/args + env object in mcp.json.
  Codewhale spawns the mcp.json `command` as a single executable, so the
  previous shell-style one-liner failed with "MCP stdio spawn failed ...
  No such file or directory" and the home-assistant tools were unavailable.
- setup-ha-mcp.sh now writes the entry directly (jq) with HOMEASSISTANT_URL /
  HOMEASSISTANT_TOKEN passed as literal env values; mcp.json is chmod 600.
- run.sh delegates to the shared setup-ha-mcp.sh instead of duplicating it.

## 0.1.0

Initial release. Codewhale Terminal — the Codewhale coding agent in a web terminal (ttyd + tmux) as a Home Assistant add-on.

- Web terminal with auto-launched Codewhale (CLI + TUI), tmux session persistence across reconnects
- API-key auth configured from add-on options; supports all Codewhale providers (DeepSeek, OpenAI-compatible gateways, OpenRouter, Ollama, Moonshot/Kimi, and more)
- Persistent state under `/data` (config, sessions, MCP registrations); background Codewhale self-update with runnability guard
- Home Assistant integration: auto-generated `AGENTS.md` context and optional ha-mcp MCP server (Python 3.13 provisioned via uv)
- Ubuntu 24.04 base for both amd64 (static musl binary) and aarch64 (glibc ≥ 2.39 binary)
- Convenience commands: `codewhale-doctor`, `codewhale-reconfigure`, `persist-install` (apt/pip), `ha-context`
