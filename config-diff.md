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

Package install (CORRECTED): the first attempt used `pip` against the base runtime Python, which Hermes does
not load. The working command is:

```bash
hermes tools post-setup ddgs   # installs the ddgs extra into Hermes's managed env
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

## Follow-up: sandbox image, GPU flags, hardening

```diff
 terminal:
-  docker_image: hermes-sandbox:pdf
+  docker_image: hermes-sandbox:tools
   docker_extra_args:
     - --add-host=host.docker.internal:host-gateway
     - --gpus=all
+    - --device=/dev/nvidia0
+    - --device=/dev/nvidia1
+    - --device=/dev/nvidiactl
+    - --device=/dev/nvidia-uvm
+    - --device=/dev/nvidia-uvm-tools
+    - --security-opt=no-new-privileges
+    - --pids-limit=512
```

Rollback: restore the matching `config.yaml.bak-*`, remove the container so Hermes recreates it.

## Later changes (end-to-end testing)

```diff
 web:
   search_backend: ddgs
+  extract_backend: keenable
 browser:
+  backend: 'off'
   inactivity_timeout: 120
+security:
+  website_blocklist:
+    enabled: true
+    domains: [accounts.google.com, mail.google.com, outlook.live.com, login.live.com,
+              login.microsoftonline.com, appleid.apple.com, paypal.com, "*.paypal.com"]
```

Only the newest 3 `config.yaml.bak-*` files remain, so rollback is limited to recent states.

## Browser desktop image

```diff
 terminal:
-  docker_image: hermes-sandbox:tools
+  docker_image: hermes-sandbox:desktop-tools
```

Built from `sandbox/Dockerfile.desktop`; the old container was removed and Hermes recreated it from the new image.
