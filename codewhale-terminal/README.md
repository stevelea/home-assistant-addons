# Codewhale Terminal

[Codewhale](https://github.com/Hmbown/CodeWhale) — a terminal coding agent for hosted and local models — in a browser terminal (ttyd + tmux), as a Home Assistant add-on.

## Highlights

- **Web terminal** through the Home Assistant sidebar (ttyd + tmux); sessions survive navigation and reconnect automatically
- **Codewhale pre-installed** and auto-launched (`codewhale` CLI + TUI binaries, pinned to a release at image build time)
- **API-key auth** — set a bootstrap key in the add-on options or configure inside Codewhale; works with DeepSeek, OpenAI-compatible gateways, OpenRouter, Ollama, Moonshot/Kimi, and 30+ other providers
- **Persistent state** under `/data`: config, sessions, and MCP registrations survive restarts and add-on updates
- **Home Assistant integration**: `AGENTS.md` context file (auto-generated) and the [ha-mcp](https://github.com/homeassistant-ai/ha-mcp) MCP server for direct HA control
- **Works on amd64 and aarch64** — built on Ubuntu 24.04 so Codewhale's glibc arm64 binary and static musl x64 binary both run

## Installation

1. Add this repository to your Home Assistant add-on store: **Settings → Add-ons → Add-on Store → ⋮ → Repositories**, URL `https://github.com/stevelea/home-assistant-addons`
2. Install the **Codewhale Terminal** add-on
3. Optionally set an `api_key` (first-boot bootstrap); provider/model are configured inside Codewhale (see [DOCS.md](DOCS.md#provider--model-configuration))
4. Start the add-on and click **OPEN WEB UI**

## Documentation

- Full documentation: [DOCS.md](DOCS.md)
- Changelog: [CHANGELOG.md](CHANGELOG.md)

## Credits

- **[Claude Terminal](https://github.com/heytcass/home-assistant-addons)** by [@heytcass](https://github.com/heytcass) — this add-on adapts its web-terminal foundation (ttyd + tmux), Home Assistant add-on structure, and operational patterns. MIT.
- **[Codewhale](https://github.com/Hmbown/CodeWhale)** by [@Hmbown](https://github.com/Hmbown) — the coding agent this add-on runs. MIT.
- **[ha-mcp](https://github.com/homeassistant-ai/ha-mcp)** — the Home Assistant MCP server integration.

## Disclaimer

**Use at your own risk.** This add-on gives an AI agent write access to your Home Assistant configuration and, via ha-mcp, control over your devices and automations — AI can and will make mistakes. Take a full backup before letting it make changes, and review what it writes. This is an independent community project, not affiliated with or endorsed by Home Assistant, the Codewhale project, or any model/API provider.

## License

MIT — see the repository [LICENSE](../LICENSE).
