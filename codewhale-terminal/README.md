# Codewhale Terminal

[Codewhale](https://github.com/Hmbown/CodeWhale) — a terminal coding agent for hosted and local models — in a browser terminal (ttyd + tmux), as a Home Assistant add-on.

## Highlights

- **Web terminal** through the Home Assistant sidebar (ttyd + tmux); sessions survive navigation and reconnect automatically
- **Codewhale pre-installed** and auto-launched (`codewhale` CLI + TUI binaries, pinned to a release at image build time)
- **API-key auth** configured from add-on options — works with DeepSeek, OpenAI-compatible gateways, OpenRouter, Ollama, Moonshot/Kimi, and 30+ other providers
- **Persistent state** under `/data`: config, sessions, and MCP registrations survive restarts and add-on updates
- **Home Assistant integration**: `AGENTS.md` context file (auto-generated) and the [ha-mcp](https://github.com/homeassistant-ai/ha-mcp) MCP server for direct HA control
- **Works on amd64 and aarch64** — built on Ubuntu 24.04 so Codewhale's glibc arm64 binary and static musl x64 binary both run

## Installation

1. Add this repository to your Home Assistant add-on store: **Settings → Add-ons → Add-on Store → ⋮ → Repositories**, URL `https://github.com/stevelea/home-assistant-addons`
2. Install the **Codewhale Terminal** add-on
3. Configure at minimum `provider` and `api_key` (see [DOCS.md](DOCS.md#options))
4. Start the add-on and click **OPEN WEB UI**

## Documentation

- Full documentation: [DOCS.md](DOCS.md)
- Changelog: [CHANGELOG.md](CHANGELOG.md)

## License

MIT — see the repository [LICENSE](../LICENSE).
