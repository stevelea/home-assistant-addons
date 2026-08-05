# Addons by @stevelea

Home Assistant add-ons by [@stevelea](https://github.com/stevelea).

## Add-ons

### Codewhale Terminal

A web-based terminal interface with the [Codewhale](https://github.com/Hmbown/CodeWhale) coding agent pre-installed — a Rust TUI/CLI for DeepSeek, OpenAI-compatible gateways, OpenRouter, Ollama, Moonshot/Kimi, and 30+ other hosted and local models — running in a ttyd + tmux web terminal inside your Home Assistant dashboard.

Features:
- Web terminal access through your Home Assistant UI (tmux session persistence across reconnects)
- Pre-installed Codewhale CLI + TUI that launches automatically
- API-key auth configured from add-on options
- Direct access to your Home Assistant config directory
- Home Assistant integration: auto-generated `AGENTS.md` context and optional ha-mcp MCP server
- Persistent config/sessions under `/data`; works on amd64 and aarch64

[Documentation](codewhale-terminal/DOCS.md)

## How it works

**Codewhale Terminal** is a Docker container (Ubuntu 24.04) that runs the Codewhale coding agent behind a web terminal:

```
Browser (HA sidebar / ingress)
   │  WebSocket
   ▼
ttyd ──► tmux session "codewhale" ──► codewhale (CLI + TUI)
   │                                   │
   │                                   ├─► provider API (DeepSeek, OpenAI-compatible, …)
   │                                   └─► ha-mcp ──► Supervisor API ──► Home Assistant
```

- **ttyd + tmux**: ttyd serves the terminal over HTTPS through Home Assistant's ingress; tmux keeps the session alive, so navigating away and coming back reattaches to the same running agent (`tmux new-session -A`). `codewhale -c` / `-r` continue or resume sessions.
- **Boot flow (`run.sh`)**: everything persistent lives under `/data` — config, sessions, MCP registrations, and the Supervisor token. At startup the add-on generates `~/.codewhale/config.toml` from the add-on options (rewritten only when those options change), installs helper commands (`codewhale-doctor`, `codewhale-reconfigure`, `persist-install`, `ha-context`), checks for a Codewhale update in the background, and launches the terminal with Codewhale auto-started.
- **Home Assistant integration** happens over three channels:
  1. **ha-mcp** — a bundled MCP server that Codewhale launches on demand. It authenticates to the Supervisor API with the injected `SUPERVISOR_TOKEN` and exposes tools to query entity states, call services, and manage automations, scripts, and dashboards.
  2. **Supervisor API** — used at boot to generate `/config/AGENTS.md` (system info, entities, installed add-ons, recent errors) so Codewhale knows your setup; the tmux status bar also checks HA reachability.
  3. **Ingress + mounts** — the terminal itself comes through the sidebar, with `/config` (your HA configuration), `/addon_configs`, and `/share` mounted for file access.
- **Security model**: your provider API key lives only in `/data/.codewhale/config.toml` (mode 600); the Supervisor token is carried in `mcp.json` and `/data/supervisor.token` (both mode 600). `dangerously_skip_permissions: true` maps to `approval_policy = "never"` — see the add-on docs before enabling.
- **Keeping things current**: Codewhale self-updates in `/data` in the background on each start (guarded by a runnability check, with the image's pinned `CODEWHALE_VERSION` copy as fallback); the add-on image itself is rebuilt on every release.

## Installation

To add this repository to your Home Assistant instance:

1. Go to **Settings** → **Add-ons** → **Add-on Store**
2. Click the three dots menu in the top right corner
3. Select **Repositories**
4. Add the URL: `https://github.com/stevelea/home-assistant-addons`
5. Click **Add**
6. Install **Codewhale Terminal**, set `provider` and `api_key`, and start it

## Support

If you have any questions or issues with this add-on, please create an issue in this repository.

## Credits

This add-on stands on the shoulders of two projects:

- **[Claude Terminal](https://github.com/heytcass/home-assistant-addons)** by [Tom Cassady (@heytcass)](https://github.com/heytcass) — this add-on is a derivative of that project: the ttyd + tmux web-terminal foundation, the Home Assistant add-on structure, and many operational patterns (persistent `/data` layout, self-update with a runnability guard, ha-mcp wiring, tmux/ttyd configuration) were adapted from it. Licensed MIT.
- **[Codewhale](https://github.com/Hmbown/CodeWhale)** by [@Hmbown](https://github.com/Hmbown) — the coding agent (Rust TUI/CLI) that runs inside this add-on, supporting DeepSeek, OpenAI-compatible gateways, OpenRouter, Ollama, Moonshot/Kimi, and 30+ other providers. Licensed MIT.

Key components bundled for the Home Assistant integration: [ha-mcp](https://github.com/homeassistant-ai/ha-mcp) (Home Assistant MCP server) and [uv](https://github.com/astral-sh/uv) (managed Python provisioning).

## License

This repository is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
