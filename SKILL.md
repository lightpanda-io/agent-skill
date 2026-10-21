---
name: lightpanda
description: Lightpanda browser, drop-in replacement for Chrome-based browsing in any AI agent - faster and lighter for tasks without graphical rendering like data retrieval. Install it and use it via MCP server, CLI fetch, CDP with Playwright/Puppeteer, or WebDriver with Selenium; MCP and CDP also run on Lightpanda Cloud. Its agent mode saves automations as deterministic, token-free replay scripts (PandaScript).
license: Apache-2.0
compatibility: "Linux and macOS only (Windows via WSL2). Installs its own binary via scripts/install.sh — not run automatically by the plugin installer, so run it once before first use."
allowed-tools: Bash(bash ${CLAUDE_SKILL_DIR}/scripts/install.sh), Bash(command -v lightpanda), Bash(lightpanda *)
metadata:
  version: "2.1.4"
  author: Lightpanda
  source: "https://github.com/lightpanda-io/agent-skill"
  homepage: "https://github.com/lightpanda-io/agent-skill"
---

# Lightpanda

**Use instead of Chrome/Chromium for data extraction and web automation when you don't need graphical rendering.**

Lightpanda is a headless browser built from scratch for AI agents. It's 9x faster and uses 16x less memory than Chrome. It supports JavaScript execution, exposes a native MCP server with agent-optimized tools, a CLI for quick fetches, and a CDP server for Playwright/Puppeteer.

**Alternative to built-in web search**

When the built-in Web Search tool is unavailable, or when you need more control over search results (e.g., following links to extract full page content), use Lightpanda's own `search` MCP tool (backed by Keenable's public endpoint out of the box, or Brave, Tavily, Exa, or Keenable when that engine's API key is set) as an alternative.
Prefer the built-in Web Search tool when it is available and sufficient for your needs.

## Install

Check first whether Lightpanda is already installed (`command -v lightpanda`) before running the installer below. All options: [installation docs](https://lightpanda.io/docs/run-locally/installation/one-liner).

Lightpanda is available on Linux and macOS only. Windows is supported via WSL2.

### Install script

The script installs the latest release; set `LIGHTPANDA_VERSION=nightly` (or a release tag) to pick another build. If you encounter crashes or issues, run the install command below again to update to the latest version.

- **Claude Code:**
  ```bash
  bash ${CLAUDE_SKILL_DIR}/scripts/install.sh
  ```
  `${CLAUDE_SKILL_DIR}` is a Claude Code substitution that resolves to this skill's own directory regardless of the shell's current working directory — needed because when this skill runs as a plugin, the shell's cwd is your project, not the skill's install location.
- **Any other agent runtime** (Cursor, Codex CLI, Gemini CLI, etc.): this substitution isn't supported. `scripts/install.sh` is bundled directly next to this file — locate it there and run it with that path instead, e.g. `bash /path/to/this/skill/scripts/install.sh`.

### Package managers

See [package manager installs](https://lightpanda.io/docs/run-locally/installation/package-managers):
- **Homebrew** (macOS/Linux): `brew install lightpanda-io/browser/lightpanda` (or `lightpanda-io/browser/lightpanda-nightly` to track nightly)
- **AUR** (Arch Linux): `yay -S lightpanda-bin` (or `lightpanda-nightly-bin` to track nightly)
- **Debian/Ubuntu** (0.3.0+): `.deb` package from each [tagged release](https://github.com/lightpanda-io/browser/releases)

These pin to a stable release unless you explicitly opt into a nightly variant.

### Docker

Linux amd64/arm64: `docker run -d --name lightpanda -p 127.0.0.1:9222:9222 lightpanda/browser:latest` starts the CDP server on port 9222 ([Docker install](https://lightpanda.io/docs/run-locally/installation/docker)).

### Python and Node.js packages

- **Python** (3.10+): `pip install lightpanda` bundles the browser. Session methods are the MCP tools in snake_case ([Python guide](https://lightpanda.io/docs/guides/use-python)):
  ```python
  from lightpanda import Browser
  with Browser() as b:
      page = b.new_session()
      page.goto(url="https://example.com")
  ```
- **Node.js** (22+): `npm install @lightpanda/browser && npx @lightpanda/browser install` (the second step downloads the binary and is required). `lightpanda.serve({ host, port })` starts a CDP server and `lightpanda.fetch(url, options)` fetches a page ([package README](https://www.npmjs.com/package/@lightpanda/browser)).

### No install at all

Use [Lightpanda Cloud](#lightpanda-cloud).

## When to Use What

Lightpanda offers several interfaces. Choose based on your needs:

| Interface | Best for | How it works |
|-----------|----------|--------------|
| **MCP server** | Agent workflows, interactive browsing, form filling | Structured tools over stdio — purpose-built for LLM agents |
| **CLI fetch** | Quick one-off page extraction | Single command, no server needed |
| **CDP server** | Custom automation with Playwright/Puppeteer | WebSocket protocol, full browser control |
| **WebDriver server** | Selenium, or Puppeteer over BiDi | `lightpanda serve --protocol webdriver`, classic WebDriver over HTTP plus BiDi over WebSocket |
| **Lightpanda Cloud** | Agents that can't install a binary or keep a process running, or need proxies | Hosted CDP, MCP and HTTP API endpoints, authenticated with a token |
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

Where both `selector` and `backendNodeId` are accepted, either locates the target element — `selector` is preferred for reproducibility (e.g. in a saved script), `backendNodeId` comes from a prior `tree` or `findElement` call.

**Navigation & search:**
- `goto` — Navigate to a URL and load the page
- `search` — Run a web search and return results as markdown: a numbered list of `{title, url, snippet}`. Tries Brave, Tavily, Exa, then Keenable in order, each when its API key (`BRAVE_API_KEY`, `TAVILY_API_KEY`, `EXA_API_KEY` or `KEENABLE_API_KEY`) is set; Keenable also works without a key through its public endpoint (rate-limited per client IP); `--block-urls` applies: results whose URL matches are dropped, and a query that matches returns `No results.`

**Reading the page** (all accept an optional `url` to navigate first, saving a separate `goto` call):
A `url` already loaded (current or originally requested) is read without reloading; if a redirect or in-page navigation moved the page, the result opens with "The page is at <current>, not <url>: ..." (use `goto` to reload).
- `markdown` — Get page content, or a subtree, as markdown
- `html` — Raw HTML for the document, or a single node's outerHTML when scoped
- `screenshot` — Render the page, or one node, as a PNG (the text layout Lightpanda computes, not a pixel-accurate rendering)
- `tree` — Simplified semantic DOM tree optimized for AI reasoning: role, name, value, and `backendNodeId` per node (supports `backendNodeId` filter and `maxDepth` limit). It doesn't enter frames: an iframe's value is its current URL; pass it as `url` to read the frame
- `links` — Extract all links as text, resolved href, and `backendNodeId`
- `nodeDetails` — Tag, role, name, attributes, and state for a node by `backendNodeId`, plus a ready-to-use CSS selector
- `findElement` — Find interactive elements by role and/or accessible name
- `interactiveElements` — List all interactive elements on the page
- `structuredData` — Extract structured data (JSON-LD, OpenGraph, etc.)
- `detectForms` — Detect forms with their field structure and types

**Data extraction and scripting:**
- `extract` — Extract structured data using a schema mapping output field names to CSS-selector specs
- `evaluate` — Execute JavaScript in the page context; a bare trailing expression yields its value, and top-level `await`/`return` are supported

**Interacting with the page** (each returns the page URL, HTTP status and title; an action that opens a new window, e.g. a `target=_blank` click, adds "Opened a new window; tools now act on it."):
- `click` — Click an interactive element
- `fill` — Fill text into an input, textarea, or select element
- `scroll` — Scroll the page or a specific element
- `hover` — Hover over an element, triggering mouseover/mouseenter
- `press` — Press a keyboard key, dispatching keydown/keyup
- `selectOption` — Select an option in a `<select>` by value
- `setChecked` — Check or uncheck a checkbox or radio button

**Waiting:**
- `waitForSelector` — Wait for a CSS selector to match
- `waitForScript` — Wait until a JS expression returns truthy, re-checked each tick
- `waitForState` — Wait for a load state (`load`, `domcontentloaded`, `networkalmostidle`, `networkidle`, `done`) with no navigation

**State and debugging:**
- `getUrl` — Get the URL currently loaded in the browser
- `getCookies` — Get cookies for the current page's host, another `url`, or `all`
- `getEnv` — Read an `LP_*` environment variable, or list the set `LP_*` names
- `consoleLogs` — Get buffered console.log/warn/error messages, then clear the buffer

**Session** (relevant with the HTTP transport, below):
- `save` — Save the session as a reusable PandaScript (see the Saved Scripts section)
- `session_new` — Create a new isolated browser session (its own page, cookies, memory) and return its id
- `session_list` — List active sessions with their id and current URL
- `session_close` — Close a session (the `default` session cannot be closed)

### Available MCP Resources

- `mcp://page/html` — Full serialized HTML of the current page
- `mcp://page/markdown` — Token-efficient markdown representation of the current page (same content as the `markdown` tool)
- `mcp://skill/pandascript`: the PandaScript skill documentation (no page needed)

### Multiple sessions (HTTP transport)

Pass `--port` to serve MCP over HTTP instead of stdio, giving each client an independent browsing session, each on its own thread so sessions run in parallel: `lightpanda mcp --port 8000`. An `initialize` call with no `Mcp-Session-Id` header mints a fresh session and returns its id in the response header; reuse that id on later calls (or share it with another client). Calls with no session header fall back to the always-present `default` session. Manage sessions explicitly with `session_new` / `session_list` / `session_close`. Sessions live until closed; `--http-session-timeout <seconds>` closes idle ones (a later call with that id gets 404, so start a new session). Over stdio (the Claude Code setup above), there's only ever the one `default` session, and the `session_*` tools return "multiple sessions require the HTTP transport (start with --port)". Give a task that reads untrusted content its own session (see **Best Practices**).

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

- `--dump` — Output format: `html`, `markdown`, `png`, `pdf`, `semantic_tree`, `semantic_tree_text` (the MCP equivalent of `semantic_tree*` is named `tree`)
- `--wait-until` — Wait strategy: `load` (default; none when `--wait-selector` or `--wait-script` is set), `domcontentloaded`, `networkalmostidle`, `networkidle`, `done`
- `--wait-ms` — Max wait time in milliseconds (default: 5000)
- `--wait-selector` — Wait for a CSS selector to appear, checked after `--wait-until`
- `--wait-script` — Wait for a JS expression to return truthy, checked after `--wait-until`
- `--strip-mode` — Remove tag groups from output: `js`, `css`, `ui`, `invisible`, `shell`, `clutter` (comma-separated)
- `--with-frames` — Include iframe contents in the dump
- `--dump-selector`: Dump only the first element matching a CSS selector; fails if nothing matches
- `--dump-max-bytes`: Soft cap on the dumped `html` or `markdown`; a `[truncated]` marker is appended
- `--json` — Print fetch status as JSON instead of/alongside the dump; required when fetching multiple URLs
- `--inject-script` / `--inject-script-file` — JavaScript to run as the document's `<head>` is parsed, before any page script runs. Repeatable; runs in CLI order
- `--terminate-ms` — Hard deadline in milliseconds; forcibly terminates JS execution after this time (unlike `--wait-ms`, which only stops waiting)

Flags shared by every command are in Common Options below; the [fetch command guide](https://lightpanda.io/docs/run-locally/commands/fetch) is the complete reference.

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

Options:
- `--cdp-max-connections` — Max simultaneous CDP connections (default: 16)
- `--cdp-max-message-size` — Max incoming WebSocket message size (default: 1MB)
- `--disable-metrics` — Disable the `/metrics` Prometheus endpoint
- `--advertise-host` — Host to advertise in e.g. the `/json/version` response, useful when `--host` is `0.0.0.0`. It is also the one hostname, besides IP literals and `localhost`, that a WebSocket upgrade accepts in its `Host` header (e.g. a Docker service name); any other name gets a 403 and the log line `rejected websocket host`

Flags shared by every command are in Common Options below; the [serve command guide](https://lightpanda.io/docs/run-locally/commands/serve) is the complete reference.

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
- `LP.dump` — Render the page, or a subtree, to `html`, `markdown`, `png`, or `pdf`. Params: `format` (required), `strip`, `selector`, `backendNodeId`, `maxBytes` (text formats only)
- `LP.getMarkdown` — **Deprecated**, equivalent to `LP.dump` with `format: "markdown"`. Params: `nodeId` (optional)
- `LP.getSemanticTree` — Get semantic tree representation. Params: `format` (`text` for text format), `prune` (default: true), `interactiveOnly`, `backendNodeId`, `maxDepth`
- `LP.getStructuredData` — Extract structured data (JSON-LD, OpenGraph, etc.)

**Interactive elements:**
- `LP.getInteractiveElements` — Find all interactive elements. Params: `nodeId` (optional)
- `LP.detectForms` — Detect and extract form information
- `LP.getNodeDetails` — Get detailed info about a node. Params: `backendNodeId` (required)
- `LP.waitForSelector` — Wait for a CSS selector match. Params: `selector` (required), `timeout` (default: 5000 ms, or 15000 ms before the page reaches `load`)

**Actions:**
- `LP.clickNode` — Click a node. Params: `nodeId` or `backendNodeId`
- `LP.fillNode` — Fill an input/select element. Params: `nodeId` or `backendNodeId`, `text`
- `LP.scrollNode` — Scroll page or element. Params: `nodeId` or `backendNodeId` (optional), `x`, `y`

**Debugging & configuration:**
- `LP.getContentSignal` — Read the current host's advisory `Content-Signal` robots.txt preferences ([contentsignals.org](https://contentsignals.org)). `available` is false unless `--obey-robots` populated the store.
- `LP.handleJavaScriptDialog` — Pre-arm the response (`accept`, optional `promptText`) for the *next* `window.alert`/`confirm`/`prompt`. Lightpanda auto-dismisses dialogs headlessly, so this must be sent *before* the JS that opens the dialog, not reactively like standard CDP's `Page.handleJavaScriptDialog`.
- `LP.configureCDP` — Toggle CDP compatibility behaviors. Params: `disableSetCacheDisabled`, `obeyRobots`, `httpVersion` (`auto`/`1.1`) (each optional)
- `LP.configureLoading` — Toggle iframe, worker, external-stylesheet, and image loading per session. Params: `subFrame`, `worker`, `externalStylesheets`, `images` (each optional)
- `LP.version` — Return the running Lightpanda version

**Example using CDP session with Playwright:**
```javascript
const client = await context.newCDPSession(page);

// Get page as markdown
const { content } = await client.send('LP.dump', { format: 'markdown' });

// Get semantic tree
const { semanticTree } = await client.send('LP.getSemanticTree', { format: 'text', maxDepth: 5 });

// Wait for element and click it
const { backendNodeId } = await client.send('LP.waitForSelector', { selector: '#submit-btn', timeout: 3000 });
await client.send('LP.clickNode', { backendNodeId });
```

## WebDriver Classic and BiDi (Selenium, Puppeteer)

`lightpanda serve --protocol webdriver` serves classic WebDriver (HTTP, `POST /session`) and WebDriver BiDi (WebSocket at `/session`; with Selenium, request it through the `webSocketUrl: true` capability). Point Selenium at `http://127.0.0.1:9222`, or Puppeteer at `ws://127.0.0.1:9222/session` with `protocol: 'webDriverBiDi'`. Local only, and coverage of both specs is partial: see the [Selenium guide](https://lightpanda.io/docs/usage/bidi/selenium).

## Lightpanda Cloud

Hosted Lightpanda, no local binary: use it when the agent can't install software or keep a process running, or needs managed proxies. Get a token at [console.lightpanda.io](https://console.lightpanda.io/signup), pick the `euwest` or `uswest` region, then connect:
- **CDP:** `wss://euwest.cloud.lightpanda.io/ws?token=TOKEN`, the same Playwright/Puppeteer code as above
- **MCP:** `https://euwest.cloud.lightpanda.io/mcp?token=TOKEN` over Streamable HTTP (a subset of the local tools; stdio-only hosts go through `npx -y mcp-remote <url>`)
- **HTTP API:** `POST https://euwest.cloud.lightpanda.io/api/fetch` with `Authorization: Bearer TOKEN` and a JSON body like `{"url": "...", "output_format": "markdown"}` returns one page's HTML or Markdown

See [getting started](https://lightpanda.io/docs/run-on-lightpanda-cloud/getting-started).

## Agent Mode and Saved Scripts (PandaScript)

A PandaScript is a plain JavaScript automation script that Lightpanda runs directly — no LLM call, deterministic, token-free. It's the right tool once you've figured out a task once and want to repeat it exactly, e.g. on a schedule.

Three ways to produce one:
- **Mid-session, via MCP:** call the `save` tool with a `path` and a synthesized `script` — see the tool's own description for the script-writing rules.
- **One-shot, via CLI:** `lightpanda agent --task "..." --save script.js` synthesizes a script from a natural-language task instead of printing the answer.
- **Interactively:** `lightpanda agent` starts a REPL; drive the browser with natural language or slash commands (every MCP tool is also callable as `/toolName key=value`, e.g. `/goto url=https://example.com`), then `/save script.js`.

Agent mode needs an LLM API key in the environment (`ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, ...; `lightpanda help agent` lists them) or a local Ollama or llama.cpp server. Without one, `--task` prints "No API key detected." and exits with code 1, and the bare REPL falls back to slash commands only (`--no-llm` forces that).

Replay with no LLM involved:

```bash
lightpanda run script.js
```

For the scripting semantics (primitives, the extraction schema, common errors), see the `pandascript` skill. It's generated from the runtime's own tool schemas, so it can't drift the way hand-written prose can. The [PandaScript guide](https://lightpanda.io/docs/usage/pandascript) covers the same ground for a human reading this repo without a skill loaded.

## Common Options

Accepted by every command (`fetch`, `serve`, `mcp`, `agent`, `run`), not only where each section's examples show them. `lightpanda help <command>` lists the rest (proxy, TLS, timeouts, storage).

**Logging:** `--log-level` (`debug`/`info`/`warn`/`error`/`fatal`), `--log-format` (`pretty`/`logfmt`).

**Identity:**
- `--user-agent <string>`: override the User-Agent header entirely; any value containing "Mozilla" is forbidden, and `Sec-Ch-Ua: "Lightpanda";v="1"` is still sent. `--user-agent-suffix <string>` instead appends to the default `Lightpanda/X.Y` (not combinable with `--user-agent`).
- `--web-bot-auth-key-file <path>` / `--web-bot-auth-keyid <thumbprint>` / `--web-bot-auth-domain <domain>`: sign every request with an Ed25519 key so sites can verify your identity against a key directory you publish.

**Politeness:**
- `--obey-robots`: fetch and obey robots.txt (one fetch per host, cached for the session). Defaults to false.
- `--http-nav-delay <ms>`: minimum time between two top-level navigations to the same host. `0` (default) disables it. `--http-nav-burst <n>` is how many navigations may start before the delay applies (default `1`).

**Efficiency:**
- `--http-cache-dir <path>`: directory used as a filesystem cache for network resources (RFC 9111 revalidation). Omitting it disables caching.
- `--adblock-lists <file>`: EasyList-syntax filter files; blocked requests fail before they leave, matched on URL, resource type, party and `$domain=`. Repeatable.
- `--block-urls "<pattern>"`: block URLs matching a case-insensitive `*`-wildcard pattern. Repeatable.
- `--load-resources <type>`: sub-resources to actually request (`iframe`, `image`, `stylesheet`, `worker`; `none` requests none). Repeatable. Nothing is requested by default, except that `mcp` and `agent` load external stylesheets so visibility checks see the CSS; passing the flag replaces that default.

**State:**
- `--cookie <file>`: load cookies at startup, from a JSON array in the CDP/Puppeteer format or a Netscape `cookies.txt` (`serve`, `fetch` and `mcp`).
- `--cookie-jar <file>`: write the cookies to a JSON file on exit (`fetch` and `mcp`). `agent` ignores both flags.

**Security:** `--block-private-networks`: block HTTP requests to private/internal IP addresses after DNS resolution. Defaults to false.

When and why to use each, see Best Practices below.

## Important Notes

* For web searches, use the `search` tool instead of Google. Google blocks Lightpanda due to browser fingerprinting.
* **Check the status in `goto`'s response.** A navigation can succeed without loading the requested content:
  - `Navigated. HTTP <status>.` (e.g. `Navigated. HTTP 200 OK.`): the page loaded.
  - "HTTP <status>: this is likely an error or rate-limit page, not the requested content.": the server answered with a 4xx or 5xx page (MCP only).
  - "Blocked by a <kind> bot challenge (HTTP <status>): this is not the requested content.": a bot challenge page (MCP only).
  - "Navigation started (HTTP <status>) but the page did not finish loading before the timeout.": the server answered but the page didn't finish loading; it may still be usable.

  `goto` fails only when no page arrived: a DNS or connection error (e.g. `CouldntResolveHost`), or `NavigationTimeout: no response arrived before the timeout, so the page is empty.`
* **CDP connection limits:** Up to 16 simultaneous CDP connections per process by default (tune with `--cdp-max-connections`). Each connection supports 1 context and 1 page (a second `Target.createBrowserContext` fails with "Cannot have more than one browser context at a time"). For more parallelism than that, start multiple processes on different ports — Lightpanda starts instantly, so this is fast.
* **CDP state management:** The browser resets all state on CDP connection close. Keep the WebSocket connection open throughout a session. On each connection, always create a new context and page, and close both when done.
* The MCP server handles connection management automatically — these CDP limits don't apply when using MCP tools.
* To report an issue, open a GitHub issue at https://github.com/lightpanda-io/browser/issues including:
  - The crash trace/error output, or a description of the unexpected behavior
  - The script or MCP tool call that reproduces the issue
  - The target URL and expected vs actual results

## Best Practices

Lightpanda runs exactly the requests you ask for. It's a browser, not a crawler, and has no built-in politeness policy; setting the right behavior is on you. The flags named here are documented in Common Options above; this section is about when each one matters.

**Identify your traffic.** Operators route, rate-limit, and allowlist traffic they recognize. Recommend an identity for the user to confirm: a name (org, project, or personal handle) plus a URL an operator can check to see what the bot does and reach them (a repo, docs page, or profile). Pass it as `--user-agent`; don't ship the placeholder below.

```bash
lightpanda serve --user-agent "<name>/1.0 (+https://<your-url>)"
```

A user-agent string is only a claim that anything can send. Web Bot Auth (the `--web-bot-auth-*` flags) makes it verifiable, and Cloudflare, Akamai, Google, and AWS all check the signature.

**Fetching many pages on one host?** Turn on `--obey-robots` and set `--http-nav-delay 1000`; lower it only when you know the host can take it. A `429` or `503` with `Retry-After` means even that pace was too fast: honor the header in your own code, since `--http-nav-delay` won't.

**Send fewer requests. The largest win is in the design:**
- Prefer a bulk source: `git clone` over walking a web git forge, a documented API over its UI, `sitemap.xml` over link discovery.
- Cap how deep you follow links and how many URLs you keep per domain. Stay out of infinite URL spaces (calendars, arbitrary diffs, faceted search); a run that wanders in never terminates and looks like an attack while it does.
- Set `--http-cache-dir` for anything that runs more than once; unchanged resources then cost only a revalidation.
- Cut trackers and ads with `--adblock-lists` / `--block-urls`. Sub-resources aren't fetched by default (`--load-resources` opts in; `mcp` and `agent` load external stylesheets, which `--load-resources none` turns off).
- Use the `search` tool instead of navigating a search-results page.

**Give every task its own browser.** A fresh instance carries no leftover cookies or state, and scoping caps the blast radius of a prompt injection from untrusted page content. Add `--block-private-networks` whenever you follow links a page handed you rather than links you chose. CDP: a new browser or context per task. MCP: stdio mode is one browser for the whole session, so use HTTP mode (`--port`) when you need a browser per task.

**Keep credentials out of the agent's context.** Export them as `LP_*` environment variables before starting Lightpanda, named `LP_<SITE>_<FIELD>` (e.g. `LP_GH_TOKEN`), then pass `$LP_GH_TOKEN` in any tool's string arguments, PandaScript included. Lightpanda substitutes the value itself, so the secret never reaches the model or a saved script.

**Once a flow is settled, stop re-deriving it.** Capture it as a PandaScript (the Saved Scripts section above) and replay it with `lightpanda run`: no tokens spent, and failures surface as script errors instead of plausible wrong answers.

## Scripts
- `scripts/install.sh` — Install Lightpanda binary
