# Changelog

All entries are 2026-10-06 unless noted. Newest last.

- **Diagnosed** missing web search: `web`/`search` toolsets disabled, no provider keys.
- **Enabled** `web` toolset with `web.search_backend: ddgs` (first install went to the wrong Python; see below).
- **Added** the `browser` toolset (CLI smoke test only at this point).
- **Added** image `hermes-sandbox:tools` (jq, ripgrep, tmux, sqlite3, zip, rsync, ffmpeg, pandoc, gh).
- **Fixed** GPU loss in the long-running sandbox: explicit `--device=/dev/nvidia*` flags; confirmed with a control container across a `daemon-reload`.
- **Hardened** the sandbox: `--security-opt=no-new-privileges`, `--pids-limit=512`.
- **Found** (end-to-end test): `ddgs` was invisible to Hermes and the keyless rescue ring had been serving searches. **Fixed** with `hermes tools post-setup ddgs`; stray install removed.
- **Pinned** `web.extract_backend: keenable`.
- **Added** `security.website_blocklist` (8 domains); enforced for browser navigation, not for `web_extract`.
- **Fixed** browser visibility: `browser.backend: 'off'`.
- **Cleaned up** old config backups, three old Open WebUI containers plus their old images, one exited NemoClaw container.
- **Built** `hermes-sandbox:desktop-tools` (Xvnc + Xfce parts + dbus + agent-browser + Chromium); browser verified inside the sandbox.
- **Investigated** a `browser_console` TypeError: the agent's own `removeChild(null)` on a page with no `<h1>`; not a stack bug.
- **Applied** egress policy: network `hermes-sbx`, `HERMES-SBX-EGRESS` chain, systemd unit, UFW allow for Ollama only.
- **Tested** `systemctl restart docker`: network, rules and service survived.
- **Deferred** by the user: Brave search (optional, needs a free key).
- **Consolidated** the docs: current-state summary, lessons, decision log, runbook, 9 more diagrams.
- **Tried** Tavily keyless: search kept (`web.search_backend: tavily`), keyless extract rejected (placeholder content); extract stays on Keenable. Google PSE not pursued (closed to new customers).
