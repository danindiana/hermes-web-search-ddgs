<div align="center">

<img src="assets/logo.png" alt="hermes://search logo" width="640">

# Enabling keyless DuckDuckGo web search in Hermes Agent

![status](https://img.shields.io/badge/status-enabled%20(restart%20pending)-d29922?style=for-the-badge)
![license](https://img.shields.io/badge/license-MIT-3fb950?style=for-the-badge)
![hermes](https://img.shields.io/badge/Hermes%20Agent-local-58a6ff?style=for-the-badge)
![search](https://img.shields.io/badge/search-DuckDuckGo-de5833?style=for-the-badge&logo=duckduckgo&logoColor=white)
![api key](https://img.shields.io/badge/API%20key-none%20needed-39c5cf?style=for-the-badge)
![python](https://img.shields.io/badge/python-3.14.7-3776ab?style=for-the-badge&logo=python&logoColor=white)
![ddgs](https://img.shields.io/badge/ddgs-9.16.0-bc8cff?style=for-the-badge)
![diagrams](https://img.shields.io/badge/diagrams-12%20Graphviz-0d1117?style=for-the-badge&logo=graphviz&logoColor=white)

*A local Hermes agent said it had no web search. It was right. This repo documents why, and the small
config change that fixed it without any paid service or API key.*

</div>

---

## Table of contents
1. [TL;DR](#tldr)
2. [The question](#the-question)
3. [Diagnosis](#diagnosis)
4. [How toolsets resolve](#how-toolsets-resolve)
5. [The fix](#the-fix)
6. [Request path](#request-path)
7. [Gotchas](#gotchas)
8. [Limits](#limits)
9. [Alternatives](#alternatives)
10. [Verification status](#verification-status)
11. [Troubleshooting](#troubleshooting)
12. [Diagram index](#diagram-index)
13. [Repo layout](#repo-layout)

## TL;DR

| Step | What | Where |
|---|---|---|
| 1 | `pip install "ddgs==9.16.0"` | Hermes's **managed** Python 3.14.7 |
| 2 | Remove `web` (and `search`) from `agent.disabled_toolsets` | `~/.hermes/config.yaml` |
| 3 | Add `web` to `platform_toolsets.cli` | `~/.hermes/config.yaml` |
| 4 | Set `web.search_backend: ddgs` | `~/.hermes/config.yaml` |
| 5 | Restart the Hermes session and gateway | shell |

No API key, no account, no cost. Exact diff: [`config-diff.md`](config-diff.md).

## The question

> "For the running hermes instance on this machine the agent reports that it doesn't have web search
> functionality/accessibility? Is that true?"

## Diagnosis

It was true, and it was a configuration state rather than a bug. Three independent things pointed the same way:

1. `agent.disabled_toolsets` listed `web`, `search`, `x_search` and `browser`.
2. `platform_toolsets.cli` was `file, skills, terminal, vision`, with no web entry.
3. Every search provider key in `~/.hermes/.env` (Exa, Parallel, Firecrawl) was a commented-out template line.

![diagnosis](diagrams/01_problem_diagnosis.svg)

## How toolsets resolve

`disabled_toolsets` is a strict deny list: a toolset named there is subtracted from what the platform asks for,
so adding `web` to the CLI toolsets alone would not have been enough.

- `web` = `web_search` + `web_extract`
- `search` = `web_search` only

![toolset resolution](diagrams/02_toolset_resolution.svg)

## The fix

Two changes: one package, one config edit.

```bash
# 1. install into the Python Hermes actually runs (see Gotchas)
~/.hermes/tools/python-3.14.7+20260901-linux-x64/bin/python3 -m pip install "ddgs==9.16.0"

# 2. back up, then edit config
cp ~/.hermes/config.yaml ~/.hermes/config.yaml.bak-$(date +%s)
```

```yaml
agent:
  disabled_toolsets:      # 'web' and 'search' removed from this list
    - x_search            # ...others unchanged
platform_toolsets:
  cli:
    - file
    - web                 # added
    - skills
    - terminal
    - vision
web:
  search_backend: ddgs    # added
```

![before and after](diagrams/03_before_after_config.svg)

`hermes tools list` afterwards reports `web  Web Search & Scraping` as enabled.

## Request path

Hermes's `ddgs` plugin (`plugins/web/ddgs/provider.py`) does not call the library in-process. Each search
runs in a disposable child process that the parent polls, so a hung network call can be killed.

![request path](diagrams/04_request_path.svg)

Per the plugin's own docstring, `ddgs`/`primp` can block inside native code while holding the GIL, which
makes a thread-pool timeout impossible to enforce and can freeze Ctrl+C. The parent therefore enforces a
30 second wall-clock cap and escalates `terminate()` to `kill()` after a one second grace period.

![timeout isolation](diagrams/05_timeout_isolation.svg)

## Gotchas

**Install into the right Python.** The `hermes` launcher resolves to a managed runtime under
`~/.hermes/tools/python-3.14.7+.../`. The repo's `venv/` directory is not what runs.

![python env](diagrams/06_python_env_gotcha.svg)

**A false positive while checking.** Running `import ddgs` from inside `hermes-agent/plugins/web/` appeared to
succeed, because the plugin directory named `ddgs/` is importable as a namespace package from that cwd. Always
test imports from a neutral directory such as `/tmp`.

**Searching vs. the sandbox.** Web search runs on the host side of the agent. The Docker sandbox
(`terminal.backend: docker`) is a separate boundary used by the `terminal` tool.

![sandbox boundary](diagrams/09_sandbox_boundary.svg)

## Limits

- **Search only.** `ddgs` provides `web_search`. `web_extract` needs a different backend, so expect it to
  fail or be unavailable. The agent can still fetch pages with `curl` through the terminal tool.
- **Rate limits.** DuckDuckGo is accessed through an unofficial scraping library and may throttle heavy use. The 30 s cap keeps
  the agent loop from hanging.
- **Restart required.** Sessions that were already running loaded the old config.
- **Privacy.** Queries leave the machine to DuckDuckGo, unlike a self-hosted SearXNG.

## Alternatives

| Backend | Key? | Notes |
|---|---|---|
| `ddgs` | none | **chosen**; search only |
| `brave-free` | `BRAVE_SEARCH_API_KEY` | free signup at brave.com/search/api, about 2k queries/month per the plugin manifest |
| `searxng` | none (self-host) | most private; needs a SearXNG instance |
| Exa / Parallel / Firecrawl | API key | keyed vendors with extract support |

Switching is one line: `web.search_backend: brave-free` (plus the key in `~/.hermes/.env`).

![backend options](diagrams/07_backend_options.svg)

## Verification status

Honest accounting:

| Check | State |
|---|---|
| `DDGS().text()` live query from the managed Python returned results | done |
| `config.yaml` parses and shows the intended values | done |
| `hermes tools list` shows `web` enabled | done |
| Hermes restarted | **pending** |
| Agent performs a real `web_search` end to end | **pending, unverified** |

![verification](diagrams/11_verification_flow.svg)
![timeline](diagrams/08_rollout_timeline.svg)

## Troubleshooting

![failure modes](diagrams/10_failure_modes.svg)

| Symptom | Likely cause | Fix |
|---|---|---|
| Agent still says no web search | session predates the edit | restart session and gateway |
| `ddgs package is not installed` | installed into the wrong Python | pip into the managed runtime |
| Timeouts or empty results | rate limiting | wait, or switch backend |
| `web_extract` errors | search-only backend | use `curl`, or add an extract backend |

## Diagram index

All diagrams are Graphviz, dark themed, with `.dot` source, `.png` (160 dpi) and `.svg` in [`diagrams/`](diagrams/).
Re-render with `./render.sh`.

| # | Diagram |
|---|---|
| 01 | [Problem diagnosis](diagrams/01_problem_diagnosis.png) |
| 02 | [Toolset resolution](diagrams/02_toolset_resolution.png) |
| 03 | [Before / after config](diagrams/03_before_after_config.png) |
| 04 | [Request path](diagrams/04_request_path.png) |
| 05 | [Timeout isolation](diagrams/05_timeout_isolation.png) |
| 06 | [Python env gotcha](diagrams/06_python_env_gotcha.png) |
| 07 | [Backend options](diagrams/07_backend_options.png) |
| 08 | [Session timeline](diagrams/08_rollout_timeline.png) |
| 09 | [Sandbox boundary](diagrams/09_sandbox_boundary.png) |
| 10 | [Failure modes](diagrams/10_failure_modes.png) |
| 11 | [Verification flow](diagrams/11_verification_flow.png) |
| 12 | [Repo layout](diagrams/12_repo_layout.png) |

## Repo layout

![layout](diagrams/12_repo_layout.svg)

```
README.md        this file
SESSION.md       working log of the session
config-diff.md   exact config changes and rollback
render.sh        re-render diagrams and logo
assets/          logo.svg / logo.png
diagrams/        *.dot *.png *.svg
LICENSE          MIT
```

## License
MIT. See [`LICENSE`](LICENSE).
