# Runbook

Commands for verifying, recovering and rolling back the Hermes web + sandbox setup. Nothing here needs a secret.
Replace `<sandbox>` with the container name from `docker ps` (`hermes-` plus 8 hex characters).

## Verify (healthy state)

```bash
hermes tools list | head -5                                  # web and browser both enabled
grep -E "Web search via|Tavily keyless|DDGS search" ~/.hermes/logs/agent.log | tail -3    # backend actually used, not the rescue ring
docker ps --format '{{.Names}} {{.Image}}'                   # sandbox on hermes-sandbox:desktop-tools
docker exec <sandbox> nvidia-smi -L                          # 2 GPUs
docker exec <sandbox> sh -c 'command -v jq rg tmux ffmpeg pandoc agent-browser Xvnc'
systemctl is-active hermes-sandbox-egress                    # active
sudo iptables -S DOCKER-USER                                 # jump to HERMES-SBX-EGRESS for 172.30.0.0/24
docker network inspect hermes-sbx --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}'   # 172.30.0.0/24
```

Egress probe from inside the sandbox (expect internet 200, private ranges blocked, Ollama open):

```bash
docker exec <sandbox> sh -c "curl -s -m6 -o /dev/null -w '%{http_code}\n' https://pypi.org/simple/; \
  timeout 3 bash -c '</dev/tcp/host.docker.internal/11434' && echo ollama-open; \
  timeout 3 bash -c '</dev/tcp/host.docker.internal/9998' && echo tika-open || echo tika-blocked"
```

## Recover

| Symptom | Check | Fix |
|---|---|---|
| Search "works" but log says `ddgs package is not installed` | `agent.log` | `hermes tools post-setup ddgs` (never plain pip into the base runtime Python) |
| `nvidia-smi` NVML error in the sandbox | `docker inspect <sandbox>` shows the 5 `--device` entries? | recreate the container (below); keep the `--device` flags in `terminal.docker_extra_args` |
| `browser_*` tools missing from the agent | `browser.backend` is `'off'`? | set it; default Browser Use mode swaps in `browser_exec` |
| `browser_navigate`: "Bot Desktop needs Xvnc..." | sandbox image has the desktop stack? | `terminal.docker_image: hermes-sandbox:desktop-tools`, recreate |
| Sandbox has no network | `hermes-sbx` exists, `--network=hermes-sbx` in extra args, egress unit active | recreate the network or restart the unit |
| Agent needs a LAN host | blocked by design | add a narrow RETURN rule for that host before the REJECTs in `hermes-sandbox-egress.sh`, reinstall, restart the unit |

Recreate the sandbox container (the workspace mount persists; ad-hoc installs inside it do not):

```bash
docker stop <sandbox> && docker rm <sandbox>
hermes chat -t terminal -q "Use the terminal tool to run: echo ok"   # Hermes recreates it from config
```

Do not trust a model's own report that something works; check `agent.log` or `docker exec` (see the README lessons).

## Roll back

Backups: `~/.hermes/config.yaml.bak-<unix-time>` (only the newest 3 are kept).

| Change | Roll back |
|---|---|
| Search and extract backends | set `web.search_backend: ddgs` (or remove it); remove `web.extract_backend`; to disable web entirely re-add `web` to `agent.disabled_toolsets` |
| Browser | remove `browser` from `platform_toolsets.cli`, add it back to `disabled_toolsets`, drop `browser.backend` |
| Domain blocklist | set `security.website_blocklist.enabled: false` |
| Sandbox image | set `terminal.docker_image` back to `hermes-sandbox:tools` (or `:pdf`), recreate the container |
| GPU flags / hardening flags | delete the matching lines from `terminal.docker_extra_args`, recreate |
| Egress policy | remove `--network=hermes-sbx`; `sudo systemctl disable --now hermes-sandbox-egress`; `sudo ufw delete` the 11434 rule for 172.30.0.0/24 (`sudo ufw status numbered`); `docker network rm hermes-sbx`; recreate the container |

## Not covered

A full machine reboot has not been tested. IPv6 is not configured on the sandbox network.
