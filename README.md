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
