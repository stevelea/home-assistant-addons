# Changelog

## 0.1.0

Initial release. Codewhale Terminal — the Codewhale coding agent in a web terminal (ttyd + tmux) as a Home Assistant add-on, 

- Web terminal with auto-launched Codewhale (CLI + TUI), tmux session persistence across reconnects
- API-key auth configured from add-on options; supports all Codewhale providers (DeepSeek, OpenAI-compatible gateways, OpenRouter, Ollama, Moonshot/Kimi, and more)
- Persistent state under `/data` (config, sessions, MCP registrations); background Codewhale self-update with runnability guard
- Home Assistant integration: auto-generated `AGENTS.md` context and optional ha-mcp MCP server (Python 3.13 provisioned via uv)
- Ubuntu 24.04 base for both amd64 (static musl binary) and aarch64 (glibc ≥ 2.39 binary)
- Convenience commands: `codewhale-doctor`, `codewhale-reconfigure`, `persist-install` (apt/pip), `ha-context`
