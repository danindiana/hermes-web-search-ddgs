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

## Update: web search confirmed
Operator independently confirmed web search works in the running instance; no reload needed.

## Open items
- `web_extract` is not expected to work with the ddgs backend (search only per provider docstring).

## Follow-up: browser access
- Asked how to give Hermes full browser access. Found Chromium (`chromium-1208`) and `agent-browser` 0.26.0 already
  installed; only the `browser` toolset was disabled. Presented 4 levels; operator chose option 1 (local headless).
- Backed up config, removed `browser` from `disabled_toolsets`, added it to `platform_toolsets.cli`;
  `hermes tools list` shows it enabled.
- Smoke test with the driver CLI against https://example.com: open, snapshot, close all OK.
- Not verified: agent-driven browsing, and whether running sessions need a restart.
- Docs updated: README browser section, diagrams 13-15, config-diff.md.

## Follow-up: sandbox upgrade (see also session_1791317605)
- Built `hermes-sandbox:tools` (jq, ripgrep, tmux, sqlite3, zip, rsync, ffmpeg, pandoc, gh).
- GPU died in the long-running container after systemd reloads; fixed with explicit `--device` flags.
  Reload-survival later tested (see below).
- Added `no-new-privileges` and `--pids-limit=512`; recreated the container; verified via docker exec.
- A `hermes chat -q` check hallucinated tool output; discarded.
- Docs: README "Sandbox upgrade" section, diagrams 16-24, `sandbox/Dockerfile.tools`.

## Daemon-reload test (2026-10-06)
Earlier docs said sudo was unavailable; that was wrong (passwordless `sudo -n` works). Test: sandbox container
(`--gpus=all` + explicit `--device`) and a control (`--gpus=all` only) both showed 2 GPUs; after one
`sudo systemctl daemon-reload` the sandbox kept both GPUs and torch CUDA True, the control failed with
NVML Unknown Error. Control container removed. Single observation.

## Follow-up testing: corrections found (2026-10-06)
- E2E run through Hermes showed `web_search backend 'ddgs' failed (ddgs package is not installed)` then keyless rescue:
  my earlier pip install went into the base runtime python, not Hermes's managed env. Fixed via
  `hermes tools post-setup ddgs`; log confirms real DDGS results. Stray base install removed.
- `web.extract_backend: keenable` pinned; extract verified on example.com.
- Browser: default Browser Use CLI mode hid browser_* tools -> `browser.backend: 'off'`. Then browser_navigate fails:
  the browser is placed in the Docker sandbox (placement auto) and the image lacks the Xvnc/Xfce desktop stack. The
  earlier "browser runs on the host" claim was wrong. Decision pending (A sandboxed desktop image / B gateway / C off).
- Domain blocklist added; matcher verified; NOT enforced by web_extract (third-party fetch); browser path untestable now.
- Cleanup done within approved scope; Open WebUI healthy. Egress reviewed only (DOCKER-USER empty; LAN + host services reachable).

## Browser: option A done (2026-10-06)
- Built `hermes-sandbox:desktop-tools` (Dockerfile.desktop): Xvnc + Xfce parts + dbus + x11-utils + agent-browser 0.26.0 +
  Playwright-layout Chromium 1208 (binaries copied from ~/.hermes/tools; not committed). All required binaries resolve;
  0 missing Chromium libs.
- Switched `terminal.docker_image`, removed old container, Hermes recreated it. Verified from agent.log: browser_navigate
  2.71s, browser_snapshot 0.83s; Xvnc/xfwm4/xfdesktop running; GPUs still 2.
- Blocklist live-tested on browser path: mail.google.com blocked in 0.06s.
- browser_console removeChild TypeError: investigated later; agent's own JS on a page with no h1 (see below).

## Egress rules applied (2026-10-06)
- Dedicated docker network `hermes-sbx` (172.30.0.0/24) so only the Hermes sandbox is affected (Agent Zero shares the
  default bridge and was left alone).
- `/usr/local/sbin/hermes-sandbox-egress.sh` + systemd unit (enabled): chain HERMES-SBX-EGRESS rejects RFC1918, link-local
  (metadata), CGNAT; internet stays open. UFW: 11434 from the subnet only.
- Tested first on a throwaway container, then recreated the real sandbox with `--network=hermes-sbx`: internet 200, LAN +
  metadata + Tika/Meili blocked, Ollama open, terminal curl + browser navigate/snapshot OK, 2 GPUs, Open WebUI 200,
  rules survive service restart and daemon-reload. Not tested: reboot, IPv6.

## browser_console error investigated (2026-10-06)
- state.db transcript for session 20261006_152814_c58bc8: agent ran querySelector('h1') (null twice), then
  `let h = querySelector('h1'); document.body.removeChild(h)` -> TypeError at col 53 = removeChild(null).
- CLI check: example.com now has 0 h1, 0 h2; body = STYLE, svg, 6 P, A, SCRIPT. Not a Hermes/browser bug; tool returned
  a clean success:false error. Model also called a paragraph the "heading" and misreported console-call count (3 vs 5).

## Docker restart test (2026-10-06)
`sudo systemctl restart docker`: hermes-sbx network + HERMES-SBX-EGRESS chain intact, egress service active, 4 containers
back via unless-stopped (Open WebUI healthy, 200). Sandbox (no restart policy) stayed stopped, Hermes restarted it on the next
terminal call (same container name). Egress re-verified inside it: internet 200; LAN gw, metadata, Tika blocked; Ollama open;
2 GPUs. Full machine reboot still untested.
