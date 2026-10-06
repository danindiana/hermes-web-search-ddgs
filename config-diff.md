# Config diff (`~/.hermes/config.yaml`)

Unified against the pre-change backup `config.yaml.bak-1791314376`. No secrets are involved:
DuckDuckGo needs no API key and `~/.hermes/.env` was not touched.

```diff
 agent:
   disabled_toolsets:
-    - search
     - session_search
@@
-    - web
     - x_search
@@
 platform_toolsets:
   cli:
     - file
+    - web
     - skills
@@
+web:
+  search_backend: ddgs
```

Package installed into Hermes's managed Python (not the repo `venv/`):

```bash
~/.hermes/tools/python-3.14.7+20260901-linux-x64/bin/python3 -m pip install "ddgs==9.16.0"
# pulled in: primp-2.0.1, lxml-6.1.3, click-8.5.0
```

Rollback: copy the backup over `config.yaml` and `pip uninstall ddgs`.

## Follow-up: browser toolset (level 1, local headless Chromium)

```diff
 agent:
   disabled_toolsets:
-    - browser
@@
 platform_toolsets:
   cli:
     - file
     - web
+    - browser
```

No package install was needed; Chromium and `agent-browser` were already under `~/.hermes/tools/`.
Rollback: restore the matching `config.yaml.bak-*`.
