---
name: lightpanda
description: Lightpanda browser, drop-in replacement for Chrome-based browsing in any AI agent - faster and lighter for tasks without graphical rendering like data retrieval. Use it via MCP server, CLI fetch, or CDP with Playwright/Puppeteer — or run/save automations as deterministic, token-free replay scripts (PandaScript) via its own agent mode.
license: Apache-2.0
compatibility: "Linux and macOS only (Windows via WSL2). Installs its own binary via scripts/install.sh — not run automatically by the plugin installer, so run it once before first use."
allowed-tools: Bash(bash ${CLAUDE_SKILL_DIR}/scripts/install.sh), Bash(command -v lightpanda), Bash(lightpanda *)
metadata:
  version: "2.1.0"
  author: Lightpanda
  source: "https://github.com/lightpanda-io/agent-skill"
  homepage: "https://github.com/lightpanda-io/agent-skill"
---

# Lightpanda

**Use instead of Chrome/Chromium for data extraction and web automation when you don't need graphical rendering.**

Lightpanda is a headless browser built from scratch for AI agents. It's 9x faster and uses 16x less memory than Chrome. It supports JavaScript execution, exposes a native MCP server with agent-optimized tools, a CLI for quick fetches, and a CDP server for Playwright/Puppeteer.

**Alternative to built-in web search**

When the built-in Web Search tool is unavailable, or when you need more control over search results (e.g., following links to extract full page content), use Lightpanda's own `search` MCP tool (backed by Brave/Tavily if configured, else DuckDuckGo) as an alternative.
Prefer the built-in Web Search tool when it is available and sufficient for your needs.

## Install

Check first whether Lightpanda is already installed (`command -v lightpanda`) before running the installer below.

- **Claude Code:**
  ```bash
  bash ${CLAUDE_SKILL_DIR}/scripts/install.sh
  ```
  `${CLAUDE_SKILL_DIR}` is a Claude Code substitution that resolves to this skill's own directory regardless of the shell's current working directory — needed because when this skill runs as a plugin, the shell's cwd is your project, not the skill's install location.
- **Any other agent runtime** (Cursor, Codex CLI, Gemini CLI, etc.): this substitution isn't supported. `scripts/install.sh` is bundled directly next to this file — locate it there and run it with that path instead, e.g. `bash /path/to/this/skill/scripts/install.sh`.

Lightpanda is available on Linux and macOS only. Windows is supported via WSL2. The script picks the right method per OS:
- **macOS, Apple Silicon** — installs via the upstream Homebrew tap (`brew install lightpanda-io/browser/lightpanda`). Requires Homebrew. The nightly Mach-O binaries from GitHub Releases get SIGKILLed by the kernel at exec on Apple Silicon despite shipping with an ad-hoc / linker signature, so the script delegates to the tap, which builds from source.
- **macOS Intel + Linux** — downloads the nightly binary from GitHub Releases, verifies its SHA-256, smoke-tests it, and atomically installs to `$HOME/.local/bin/lightpanda` (override with `LIGHTPANDA_DIR=...`). On rerun, the existing binary is left in place if any step fails.

Prefer a package manager? See [package manager installs](https://lightpanda.io/docs/run-locally/installation/package-managers):
- **Homebrew** (macOS/Linux): `brew install lightpanda-io/browser/lightpanda`
- **AUR** (Arch Linux): `yay -S lightpanda-bin` (or `lightpanda-nightly-bin` to track nightly)
- **Debian/Ubuntu** (0.3.0+): `.deb` package from each [tagged release](https://github.com/lightpanda-io/browser/releases)

Unlike `scripts/install.sh`, which always tracks the latest nightly, these pin to a stable release unless you explicitly opt into a nightly variant.

The binary is a nightly build that evolves quickly. If you encounter crashes or issues, run the install command above again to update to the latest version (max once per day).

If issues persist after updating, open a GitHub issue at https://github.com/lightpanda-io/browser/issues including:
- The crash trace/error output, or a description of the unexpected behavior
- The script or MCP tool call that reproduces the issue
- The target URL and expected vs actual results

## When to Use What

Lightpanda offers several interfaces. Choose based on your needs:

| Interface | Best for | How it works |
|-----------|----------|--------------|
| **MCP server** | Agent workflows, interactive browsing, form filling | Structured tools over stdio — purpose-built for LLM agents |
| **CLI fetch** | Quick one-off page extraction | Single command, no server needed |
| **CDP server** | Custom automation with Playwright/Puppeteer | WebSocket protocol, full browser control |
| **Agent mode** | One-off natural-language tasks, or authoring a PandaScript to save for later | `lightpanda agent` — LLM-driven CLI/REPL, optionally `--task "..." --save script.js` |
| **Saved scripts (PandaScript)** | Repeating the same task deterministically, without burning tokens | Plain JS script, replayed with `lightpanda run` — no LLM call |

## MCP Server (Recommended for Agents)

The MCP server is the simplest way for agents to use Lightpanda. It exposes purpose-built tools over stdio with no setup beyond the binary.

### Setup for Claude Code

```bash
claude mcp add lightpanda -- lightpanda mcp
```

To respect `robots.txt`, append `--obey-robots` to the command.

### Setup for other MCP clients

Add to your MCP client configuration:

```json
{
  "mcpServers": {
    "lightpanda": {
      "command": "lightpanda",
      "args": ["mcp"]
    }
  }
}
```

### Available MCP Tools

Where both `selector` and `backendNodeId` are accepted, either locates the target element — `selector` is preferred for reproducibility (e.g. in a saved script), `backendNodeId` comes from a prior `tree` or `findElement` call. Read tools that accept an optional `url` navigate there before reading, saving a separate `goto` call.

**Navigation & search:**
- `goto` — Navigate to a URL and load the page
- `search` — Run a web search and return results as markdown (uses Brave/Tavily if `BRAVE_API_KEY`/`TAVILY_API_KEY` is set, else scrapes DuckDuckGo)

**Reading the page** (all accept an optional `url` to navigate first):
- `markdown` — Get page content, or a subtree, as markdown
- `html` — Raw HTML for the document, or a single node's outerHTML when scoped
- `tree` — Simplified semantic DOM tree optimized for AI reasoning: role, name, value, and `backendNodeId` per node (supports `backendNodeId` filter and `maxDepth` limit)
- `links` — Extract all links as text, resolved href, and `backendNodeId`
- `nodeDetails` — Tag, role, name, attributes, and state for a node by `backendNodeId`, plus a ready-to-use CSS selector
- `findElement` — Find interactive elements by role and/or accessible name
- `interactiveElements` — List all interactive elements on the page
- `structuredData` — Extract structured data (JSON-LD, OpenGraph, etc.)
- `detectForms` — Detect forms with their field structure and types

**Data extraction and scripting:**
- `extract` — Extract structured data using a schema mapping output field names to CSS-selector specs
- `evaluate` — Execute JavaScript in the page context; a bare trailing expression yields its value, and top-level `await`/`return` are supported

**Interacting with the page** (return page URL and title after each action):
- `click` — Click an interactive element
- `fill` — Fill text into an input, textarea, or select element
- `scroll` — Scroll the page or a specific element
- `hover` — Hover over an element, triggering mouseover/mouseenter
- `press` — Press a keyboard key, dispatching keydown/keyup
- `selectOption` — Select an option in a `<select>` by value
- `setChecked` — Check or uncheck a checkbox or radio button

**Waiting:**
- `waitForSelector` — Wait for a CSS selector to match (default timeout: 5000ms)
- `waitForScript` — Wait until a JS expression returns truthy, re-checked each tick
- `waitForState` — Wait for a load state (`load`, `domcontentloaded`, `networkalmostidle`, `networkidle`, `done`) with no navigation

**State and debugging:**
- `getUrl` — Get the URL currently loaded in the browser
- `getCookies` — Get cookies for the current page's host, another `url`, or `all`
- `getEnv` — Read an `LP_*` environment variable, or list the set `LP_*` names
- `consoleLogs` — Get buffered console.log/warn/error messages, then clear the buffer

**Session** (relevant over [HTTP transport](#multiple-sessions-http-transport)):
- `save` — Save the session as a reusable PandaScript (see [Saved Scripts](#saved-scripts-pandascript))
- `session_new` — Create a new isolated browser session (its own page, cookies, memory) and return its id
- `session_list` — List active sessions with their id and current URL
- `session_close` — Close a session (the `default` session cannot be closed)

### Available MCP Resources

- `mcp://page/html` — Full serialized HTML of the current page
- `mcp://page/markdown` — Token-efficient markdown representation of the current page (same content as the `markdown` tool)

### Multiple sessions (HTTP transport)

Pass `--port` to serve MCP over HTTP instead of stdio, giving each client an independent browsing session: `lightpanda mcp --port 8000`. An `initialize` call with no `Mcp-Session-Id` header mints a fresh session and returns its id in the response header; reuse that id on later calls (or share it with another client). Calls with no session header fall back to the always-present `default` session. Manage sessions explicitly with `session_new` / `session_list` / `session_close`. Over stdio (the Claude Code setup above), there's only ever the one `default` session.

Add `--cdp-port <INT>` to also run a CDP (WebSocket) server on the same process — useful if something in your workflow needs raw CDP (e.g. Playwright/Puppeteer) alongside MCP. It can't be combined with `--port`, since both share one network listener.

### MCP Usage Example

A typical agent workflow:
1. `goto` a URL
2. `tree` or `markdown` to understand the page
3. `interactiveElements` or `findElement` to find clickable/fillable elements
4. `click` / `fill` to interact
5. `extract` or `markdown` to get the result

## CLI Fetch — Quick Extraction

For one-off page extraction without starting a server:

```bash
lightpanda fetch --dump markdown --wait-until networkidle https://example.com
```

### Options

- `--dump` — Output format: `html`, `markdown`, `semantic_tree`, `semantic_tree_text` (the MCP equivalent of `semantic_tree*` is named `tree`)
- `--wait-until` — Wait strategy: `load`, `domcontentloaded`, `networkalmostidle`, `networkidle`, `done` (default)
- `--wait-ms` — Max wait time in milliseconds (default: 5000)
- `--wait-selector` — Wait for a CSS selector to appear, checked after `--wait-until`
- `--wait-script` — Wait for a JS expression to return truthy, checked after `--wait-until`
- `--strip-mode` — Remove tag groups from output: `js`, `css`, `ui`, `invisible`, `full` (comma-separated)
- `--with-frames` — Include iframe contents in the dump
- `--json` — Print fetch status as JSON instead of/alongside the dump; required when fetching multiple URLs
- `--inject-script` / `--inject-script-file` — JavaScript to run as the document's `<head>` is parsed, before any page script runs. Repeatable; runs in CLI order
- `--terminate-ms` — Hard deadline in milliseconds; forcibly terminates JS execution after this time (unlike `--wait-ms`, which only stops waiting)
- `--obey-robots` — Fetch and obey robots.txt (a common option shared by every command, see below)

`--obey-robots`, logging (`--log-level`/`--log-format`), and proxy/network flags are common options accepted by every Lightpanda command (`fetch`, `serve`, `mcp`, `agent`, `run`), not just `fetch` — run `lightpanda help fetch` or see the [fetch command guide](https://lightpanda.io/docs/run-locally/commands/fetch) for the full list.

### Examples

Extract page as markdown:
```bash
lightpanda fetch --dump markdown https://example.com
```

Extract semantic tree (compact, AI-friendly):
```bash
lightpanda fetch --dump semantic_tree_text --wait-until networkidle https://example.com
```

Fetch with longer wait for slow pages:
```bash
lightpanda fetch --dump html --wait-ms 10000 --wait-until networkidle https://example.com
```

## CDP Server — Advanced Automation

For full browser control via Playwright or Puppeteer:

### Start the Browser Server
```bash
lightpanda serve --host 127.0.0.1 --port 9222
```

Serve-specific options:
- `--cdp-max-connections` — Max simultaneous CDP connections (default: 16)
- `--cdp-max-message-size` — Max incoming WebSocket message size (default: 1MB)
- `--disable-metrics` — Disable the `/metrics` Prometheus endpoint
- `--advertise-host` — Host to advertise in e.g. the `/json/version` response, useful when `--host` is `0.0.0.0`

Logging (`--log-level`, `--log-format`), `--obey-robots`, and proxy/network flags are common options shared by every command, not `serve`-specific — run `lightpanda help serve` or see the [serve command guide](https://lightpanda.io/docs/run-locally/commands/serve) for the full list.

### Using with playwright-core

Connect using `playwright-core` (not the full `playwright` package):

```javascript
const { chromium } = require('playwright-core');

(async () => {
  const browser = await chromium.connectOverCDP({
    endpointURL: 'ws://127.0.0.1:9222',
  });

  const context = await browser.newContext({});
  const page = await context.newPage();

  await page.goto('https://example.com');
  const title = await page.title();
  const content = await page.textContent('body');

  console.log(JSON.stringify({ title, content }));

  await page.close();
  await context.close();
  await browser.close();
})();
```

### Using with puppeteer-core

Connect using `puppeteer-core` (not the full `puppeteer` package). This snippet only shows what differs from the Playwright example above, so it isn't runnable on its own. Reuse that example's setup and teardown, and swap in these lines instead.

```javascript
const puppeteer = require('puppeteer-core');

const browser = await puppeteer.connect({
  browserWSEndpoint: 'ws://127.0.0.1:9222',
});
const context = await browser.createBrowserContext(); // not newContext()
const page = await context.newPage();
await page.goto('https://example.com', { waitUntil: 'networkidle0' }); // explicit waitUntil — puppeteer doesn't auto-wait like Playwright
```

Everything else (`page.title()`, `page.close()`, `context.close()`, `browser.close()`) is identical to the Playwright example.

### Custom LP CDP Domain

Lightpanda exposes a custom `LP` domain via CDP with agent-optimized methods not available in standard Chrome DevTools Protocol. Use these via `page.evaluate` with CDP sessions or direct WebSocket messages.

**Content extraction:**
- `LP.getMarkdown` — Extract page content as markdown. Params: `nodeId` (optional)
- `LP.getSemanticTree` — Get semantic tree representation. Params: `format` (`text` for text format), `prune` (default: true), `interactiveOnly`, `backendNodeId`, `maxDepth`
- `LP.getStructuredData` — Extract structured data (JSON-LD, OpenGraph, etc.)

**Interactive elements:**
- `LP.getInteractiveElements` — Find all interactive elements. Params: `nodeId` (optional)
- `LP.detectForms` — Detect and extract form information
- `LP.getNodeDetails` — Get detailed info about a node. Params: `backendNodeId` (required)
- `LP.waitForSelector` — Wait for a CSS selector match. Params: `selector` (required), `timeout` (default: 5000ms)

**Actions:**
- `LP.clickNode` — Click a node. Params: `nodeId` or `backendNodeId`
- `LP.fillNode` — Fill an input/select element. Params: `nodeId` or `backendNodeId`, `text`
- `LP.scrollNode` — Scroll page or element. Params: `nodeId` or `backendNodeId` (optional), `x`, `y`

**Debugging & configuration:**
- `LP.getContentSignal` — Read the current host's advisory `Content-Signal` robots.txt preferences ([contentsignals.org](https://contentsignals.org)). `available` is false unless `--obey-robots` populated the store.
- `LP.handleJavaScriptDialog` — Pre-arm the response (`accept`, optional `promptText`) for the *next* `window.alert`/`confirm`/`prompt`. Lightpanda auto-dismisses dialogs headlessly, so this must be sent *before* the JS that opens the dialog, not reactively like standard CDP's `Page.handleJavaScriptDialog`.
- `LP.configureCDP` — Toggle CDP compatibility behaviors. Params: `disableSetCacheDisabled`
- `LP.configureLoading` — Toggle iframe, worker, and external-stylesheet loading per session. Params: `subFrame`, `worker`, `externalStylesheets` (each optional)
- `LP.version` — Return the running Lightpanda version

**Example using CDP session with Playwright:**
```javascript
const client = await context.newCDPSession(page);

// Get page as markdown
const { markdown } = await client.send('LP.getMarkdown');

// Get semantic tree
const { semanticTree } = await client.send('LP.getSemanticTree', { format: 'text', maxDepth: 5 });

// Wait for element and click it
const { backendNodeId } = await client.send('LP.waitForSelector', { selector: '#submit-btn', timeout: 3000 });
await client.send('LP.clickNode', { backendNodeId });
```

## Saved Scripts (PandaScript)

A PandaScript is a plain JavaScript automation script that Lightpanda runs directly — no LLM call, deterministic, token-free. It's the right tool once you've figured out a task once and want to repeat it exactly, e.g. on a schedule.

Three ways to produce one:
- **Mid-session, via MCP:** call the `save` tool with a `path` and a synthesized `script` — see the tool's own description for the script-writing rules.
- **One-shot, via CLI:** `lightpanda agent --task "..." --save script.js` synthesizes a script from a natural-language task instead of printing the answer.
- **Interactively:** `lightpanda agent` starts a REPL; drive the browser with natural language or slash commands (every MCP tool is also callable as `/toolName key=value`, e.g. `/goto url=https://example.com`), then `/save script.js`.

Replay with no LLM involved:

```bash
lightpanda run script.js
```

For the scripting semantics (primitives, the extraction schema, common errors), see the `pandascript` skill. It's generated from the runtime's own tool schemas, so it can't drift the way hand-written prose can. The [PandaScript guide](https://lightpanda.io/docs/usage/pandascript) covers the same ground for a human reading this repo without a skill loaded.

## Important Notes

* For web searches, use the `search` tool (or DuckDuckGo directly) instead of Google. Google blocks Lightpanda due to browser fingerprinting.
* Lightpanda is under heavy development and may have occasional issues. It executes JavaScript, making it suitable for dynamic websites and SPAs.
* **Be careful trusting `goto`'s response.** It reports failure directly for DNS and connection errors (e.g. `CouldntResolveHost`), so that part is reliable. Two other cases still look like success. A timeout returns "Navigation started but the page did not finish loading before the timeout." instead of failing. An HTTP error page (404, 500) is a real response, so `goto` reports it as a successful navigation to that page. Check the content with a follow-up read when the response status matters.
* **CDP connection limits:** Up to 16 simultaneous CDP connections per process by default (tune with `--cdp-max-connections`). Each connection supports 1 context and 1 page. For more parallelism than that, start multiple processes on different ports — Lightpanda starts instantly, so this is fast.
* **CDP state management:** The browser resets all state on CDP connection close. Keep the WebSocket connection open throughout a session. On each connection, always create a new context and page, and close both when done.
* The MCP server handles connection management automatically — these CDP limits don't apply when using MCP tools.

## Scripts
- `scripts/install.sh` — Install Lightpanda binary
