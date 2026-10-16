# Lightpanda Skill for LLM Agents

Teach your LLM agent to use [Lightpanda](https://github.com/lightpanda-io/browser), a fast headless browser optimized for data extraction and web automation, as a drop-in replacement for Chrome/Chromium.

## What is this?

This skill covers Lightpanda's interfaces and when to use them:

| Interface | Best for |
|-----------|----------|
| **MCP server** | Agent workflows, interactive browsing, form filling |
| **CLI fetch** | Quick one-off page extraction |
| **CDP server** | Custom automation with Playwright/Puppeteer |
| **WebDriver server** (Classic and BiDi) | Selenium, or Puppeteer over BiDi |
| **Agent mode** | Natural-language tasks, or authoring a PandaScript to save |
| **Saved scripts (PandaScript)** | Repeating a task deterministically, token-free |

[Lightpanda Cloud](https://lightpanda.io/docs/run-on-lightpanda-cloud/getting-started) hosts the MCP and CDP servers, plus an HTTP API, for agents that can't install a binary or keep a process running.

A companion sub-skill, [`pandascript`](pandascript/SKILL.md), covers writing PandaScript — the deterministic replay-script format run with `lightpanda run` (no LLM call).

[SKILL.md](SKILL.md) and [lightpanda.io/docs](https://lightpanda.io/docs) are the full reference — every tool, flag, and caveat.

## Installation

### 1. Add the skill to your agent

Via [skills.sh](https://skills.sh) — works with Claude Code, Cursor, Codex, Windsurf, Copilot, opencode, OpenClaw, Hermes, and more:

```bash
npx skills add lightpanda-io/agent-skill
```

It prompts for the skills and target agent — pick `lightpanda`, plus `pandascript` if you'll write replay scripts.

Claude Code users can instead install the plugin, which also wires in the MCP server:

```bash
/plugin marketplace add lightpanda-io/agent-skill
/plugin install lightpanda@lightpanda
```

### 2. Install the Lightpanda binary

With the skill loaded, ask the agent to do it — it knows the install script, the package-manager options, and the platform quirks. Or run it yourself:

```bash
bash scripts/install.sh
```

Homebrew, AUR, and `.deb` builds: see the [install docs](https://lightpanda.io/docs/run-locally/installation/package-managers).

### MCP server (optional)

The MCP server gives your agent live, interactive browsing — structured tools it calls mid-task (navigate, click, extract, wait, …) against a persistent session. It's one of the interfaces above, not a requirement.

Claude Code plugin users already have it. For any other MCP client, add this to your config:

```json
{ "mcpServers": { "lightpanda": { "command": "lightpanda", "args": ["mcp"] } } }
```

## Platform Support

- Linux (x86_64, aarch64)
- macOS (x86_64, arm64)
- Windows via WSL2

## License

Apache 2.0
