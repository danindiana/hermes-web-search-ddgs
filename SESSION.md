# session_1791314587 — enable keyless web search in Hermes

## Objective
User: "the agent reports it doesn't have web search — is that true?" then "enable web search using a free
service like duckduckgo or brave".

## Findings
- True. `agent.disabled_toolsets` contained `web`, `search`, `x_search`, `browser`; `platform_toolsets.cli`
  was `file, skills, terminal, vision`; all search-provider keys in `.env` were commented out.
- Hermes ships web-search plugins in `plugins/web/`: `ddgs` (no key), `brave_free`
  (`BRAVE_SEARCH_API_KEY`, free signup, ~2k queries/month), `searxng`, plus keyed vendors.
- `search` toolset = `web_search` only; `web` = `web_search` + `web_extract`. `hermes tools list` only
  offers `web`, so `web` was enabled.

## Decisions
- DuckDuckGo (`ddgs`) over Brave: zero signup/keys. Brave remains a one-line switch.
- Install into the managed runtime Python (`~/.hermes/tools/python-3.14.7+.../bin/python3`), not `venv/`.

## Gotcha caught
An early `import ddgs` seemed to succeed under `hermes-agent/venv`; it was only because cwd was
`plugins/web/`, where the `ddgs/` plugin directory acts as a namespace package. A real check from a
neutral cwd showed it was not installed.

## Log (2026-10-06)
- ~14:19 inspected config, `.env`, plugin manifests
- `pip install ddgs==9.16.0` OK; `DDGS().text('python release', max_results=2)` returned 2 results
- backed up config (`config.yaml.bak-1791314376`), edited, `hermes tools list` shows `web` enabled
- documented this session (this folder)

## Open items
- Hermes pts/0 session and gateway (pid 18297 at the time) must be restarted to load the change.
- Not yet verified: an actual `web_search` call made by the agent end to end.
- `web_extract` is not expected to work with the ddgs backend (search only per provider docstring).
