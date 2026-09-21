# RustDesk Flutter Web Client Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and package the existing RustDesk Flutter Web client as a static HTTPS deployment that connects to the user's existing `hbbs`/`hbbr` deployment.

**Architecture:** Restore the historical Flutter Web scaffold from Git history, keep it at `flutter/web` so Flutter's web target is recognized, and reuse the existing browser adapter in `flutter/lib/web/`. Add deterministic build scripts and deployment documentation without adding a custom backend. The final deliverable is a static archive plus an Nginx/Caddy deployment example.

**Tech Stack:** Flutter 3.24.5, Dart 3, TypeScript 4.4, Vite 2.8, Yarn 1, protoc/ts-proto, RustDesk protobuf protocol, HTTPS plus WebSocket reverse proxy.

## Global Constraints

- Do not mix this feature with unrelated changes; start from a clean isolated worktree based on `a419d3258`.
- Do not modify the existing `hbbs`/`hbbr` deployment or RustDesk server protocol.
- The first release supports remote desktop control only.
- File transfer, terminal, port forwarding, address-book synchronization, and native desktop/mobile behavior changes are out of scope.
- Use `wss://` for browser-to-server connections; do not ship an HTTP-only deployment guide.
- Use Flutter `3.24.5` and Flutter Rust Bridge `1.80.1`.
- Use the historical Web JS dependency set pinned by `flutter/web/js/yarn.lock`; do not upgrade Vite beyond `2.8`.
- Build with Node.js `20.x`, Yarn `1.22.x`, and a protoc release compatible with the committed ts-proto setup.
- Avoid `unwrap()` and `expect()` in production Rust changes; no Rust changes are expected.
- Do not add a new backend service.
- Preserve RustDesk security semantics: the page is static, HTTPS-only, and must not persist device passwords by default.
- Every task must end with its tests or validation command passing and a focused commit.

---

### Task 1: Restore the Flutter Web target and inventory runtime dependencies

**Files:**
- Create: `flutter/web/.gitignore`
- Create: `flutter/web/README.md`
- Create: `flutter/web/index.html`
- Create: `flutter/web/manifest.json`
- Create: `flutter/web/favicon.svg`
- Create: `flutter/web/icons/Icon-192.png`
- Create: `flutter/web/icons/Icon-512.png`
- Create: `flutter/web/icons/Icon-maskable-192.png`
- Create: `flutter/web/icons/Icon-maskable-512.png`
- Create: `flutter/web/yuv.js`
- Create: `flutter/web/yuv.wasm`
- Create: `flutter/web/js/.gitattributes`
- Create: `flutter/web/js/.gitignore`
- Create: `flutter/web/js/.yarnrc.yml`
- Create: `flutter/web/js/gen_js_from_hbb.py`
- Create: `flutter/web/js/index.html`
- Create: `flutter/web/js/package.json`
- Create: `flutter/web/js/src/codec.js`
- Create: `flutter/web/js/src/common.ts`
- Create: `flutter/web/js/src/connection.ts`
- Create: `flutter/web/js/src/globals.js`
- Create: `flutter/web/js/src/main.ts`
- Create: `flutter/web/js/src/style.css`
- Create: `flutter/web/js/src/ui.js`
- Create: `flutter/web/js/src/vite-env.d.ts`
- Create: `flutter/web/js/src/websock.ts`
- Create: `flutter/web/js/ts_proto.py`
- Create: `flutter/web/js/tsconfig.json`
- Create: `flutter/web/js/vite.config.js`
- Create: `flutter/web/js/yarn.lock`

**Interfaces:**
- Consumes: historical commit `5faf0ad3c^` as the source of the last complete `flutter/web/v1` tree.
- Produces: a Git-tracked Flutter web target at `flutter/web`, with JavaScript sources at `flutter/web/js`; later tasks build it with `yarn install --frozen-lockfile` and `yarn build`.

- [ ] **Step 1: Confirm the clean worktree and branch**

Run:

```bash
git status --short
git rev-parse HEAD
```

Expected: the only new file may be `docs/superpowers/plans/2026-09-21-rustdesk-web-client.md`; all other files are clean. If unrelated changes are present, create a new worktree instead of editing the current checkout:

```bash
git worktree add ../rustdesk-web-client a419d3258
cd ../rustdesk-web-client
git switch -c codex/rustdesk-web-client
```

- [ ] **Step 2: Restore the historical Web v1 tree into a temporary directory**

Run:

```bash
mkdir -p /tmp/rustdesk-web-restore
git archive 5faf0ad3c^ flutter/web/v1 | tar -x -C /tmp/rustdesk-web-restore
find /tmp/rustdesk-web-restore/flutter/web/v1 -maxdepth 3 -type f | sort
```

Expected: the listing contains `index.html`, `manifest.json`, `yuv.js`, `yuv.wasm`, `js/package.json`, and all files listed above.

- [ ] **Step 3: Move the restored files to the expected Flutter target path**

Run:

```bash
mkdir -p flutter/web
cp -R /tmp/rustdesk-web-restore/flutter/web/v1/. flutter/web/
```

- [ ] **Step 4: Add only source and intentionally reusable binary assets**

Run:

```bash
git add flutter/web
git diff --cached --name-only
```

Expected: the cached list contains the files in this task's **Files** list. It must not contain `node_modules`, `js/src/gen_js_from_hbb.ts`, `js/src/message.ts`, `js/src/rendezvous.ts`, `ogvjs*`, `libopus.js`, `libopus.wasm`, or `yuv-canvas*`.

- [ ] **Step 5: Validate the web target is recognized without downloading packages**

Run:

```bash
flutter create --list-samples . >/dev/null
test -f flutter/web/index.html
test -f flutter/web/js/package.json
git check-ignore -v flutter/web/js/node_modules || true
```

Expected: all `test` commands succeed. The ignore output should resolve to `flutter/web/js/.gitignore`.

- [ ] **Step 6: Commit**

```bash
git commit -m "build: restore Flutter web target"
```

---

### Task 2: Add a reproducible Web dependency bootstrap

**Files:**
- Create: `scripts/fetch-rustdesk-web-deps.sh`
- Create: `scripts/rustdesk-web-versions.env`
- Modify: `flutter/web/README.md`

**Interfaces:**
- Consumes: `https://github.com/rustdesk/doc.rustdesk.com/releases/download/console/web_deps.tar.gz`, referenced by the current `build-rustdesk-web` CI job.
- Produces: `flutter/web/ogvjs-1.8.6/ogv.js`, `flutter/web/yuv-canvas-1.2.6.js`, and any other files included by the official `web_deps.tar.gz`; the script exits successfully only after the archive is extracted into `flutter/web`.

- [ ] **Step 1: Create the version manifest**

Write `scripts/rustdesk-web-versions.env` exactly as:

```bash
RUSTDESK_WEB_DEPS_URL="https://github.com/rustdesk/doc.rustdesk.com/releases/download/console/web_deps.tar.gz"
RUSTDESK_WEB_DEPS_SHA256=""
```

The empty checksum is temporary in this task and must be filled after downloading the archive.

- [ ] **Step 2: Create the fetch script**

Write `scripts/fetch-rustdesk-web-deps.sh` exactly as:

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$repo_root/scripts/rustdesk-web-versions.env"
web_dir="$repo_root/flutter/web"
archive="$(mktemp "${TMPDIR:-/tmp}/rustdesk-web-deps.XXXXXX.tar.gz")"

cleanup() {
  rm -f "$archive"
}
trap cleanup EXIT

echo "Downloading RustDesk web dependencies from $RUSTDESK_WEB_DEPS_URL"
curl --fail --location --proto '=https' --tlsv1.2 "$RUSTDESK_WEB_DEPS_URL" --output "$archive"

actual_sha256="$(shasum -a 256 "$archive" | awk '{print $1}')"
if [[ -z "$RUSTDESK_WEB_DEPS_SHA256" ]]; then
  echo "RUSTDESK_WEB_DEPS_SHA256 is empty. Downloaded archive SHA-256: $actual_sha256"
  echo "Set it in scripts/rustdesk-web-versions.env and rerun this script."
  exit 1
fi

if [[ "$actual_sha256" != "$RUSTDESK_WEB_DEPS_SHA256" ]]; then
  echo "SHA-256 mismatch for RustDesk web dependencies." >&2
  echo "Expected: $RUSTDESK_WEB_DEPS_SHA256" >&2
  echo "Actual:   $actual_sha256" >&2
  exit 1
fi

tar -xzf "$archive" -C "$web_dir"
echo "RustDesk web dependencies are ready under $web_dir"
```

Then run:

```bash
chmod +x scripts/fetch-rustdesk-web-deps.sh
```

- [ ] **Step 3: Run the script once to learn the checksum**

Run:

```bash
./scripts/fetch-rustdesk-web-deps.sh
```

Expected: it fails with `RUSTDESK_WEB_DEPS_SHA256 is empty`, and prints the downloaded archive's SHA-256.

- [ ] **Step 4: Record the checksum and verify a clean run**

Replace the empty checksum in `scripts/rustdesk-web-versions.env` with the printed value. Then run:

```bash
./scripts/fetch-rustdesk-web-deps.sh
test -f flutter/web/ogvjs-1.8.6/ogv.js
test -f flutter/web/yuv-canvas-1.2.6.js
```

Expected: the script succeeds and both dependency files exist. If the archive uses different exact paths, inspect the extracted files with `find flutter/web -maxdepth 2 -type f`, update the two `test` paths in this step to the archive's actual paths, and make the equivalent check part of `scripts/build-rustdesk-web.sh` in Task 3.

- [ ] **Step 5: Keep fetched dependencies out of Git**

Run:

```bash
git status --short flutter/web scripts
```

Expected: only `scripts/fetch-rustdesk-web-deps.sh` and `scripts/rustdesk-web-versions.env` appear as changes. If an extracted dependency appears as untracked, add its path to `flutter/web/.gitignore`, not to Git.

- [ ] **Step 6: Document the dependency source**

Append this section to `flutter/web/README.md`:

```markdown
## Runtime dependencies

The Flutter Web target references the official RustDesk Web runtime bundle,
including the OGV.js decoder and YUV canvas renderer. These files are not
committed because they are downloaded from a release artifact.

Run this command before building:

```bash
./scripts/fetch-rustdesk-web-deps.sh
```

The expected archive URL and SHA-256 are recorded in
`scripts/rustdesk-web-versions.env`.
```

- [ ] **Step 7: Run shell syntax validation**

Run:

```bash
bash -n scripts/fetch-rustdesk-web-deps.sh
```

Expected: no output and exit code `0`.

- [ ] **Step 8: Commit**

```bash
git add scripts/fetch-rustdesk-web-deps.sh scripts/rustdesk-web-versions.env flutter/web/README.md flutter/web/.gitignore
git commit -m "build: add pinned RustDesk web dependency bootstrap"
```

---

### Task 3: Add a one-command Web build and archive script

**Files:**
- Create: `scripts/build-rustdesk-web.sh`
- Create: `docs/deploy/rustdesk-web/README.md`

**Interfaces:**
- Consumes: `scripts/fetch-rustdesk-web-deps.sh`, `flutter/web/js/yarn.lock`, `flutter/lib/web/bridge.dart`, and Flutter Web target `flutter/web`.
- Produces: `target/rustdesk-web/rustdesk-web.tar.gz` containing the contents of `flutter/build/web`; the script prints the absolute archive path and SHA-256.

- [ ] **Step 1: Create the build script**

Write `scripts/build-rustdesk-web.sh` exactly as:

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
flutter_dir="$repo_root/flutter"
web_js_dir="$flutter_dir/web/js"
output_dir="$repo_root/target/rustdesk-web"
archive="$output_dir/rustdesk-web.tar.gz"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_command flutter
require_command yarn
require_command python3
require_command protoc
require_command shasum
require_command tar

if ! flutter --version | grep -q '3\.24\.5'; then
  echo "RustDesk Web must be built with Flutter 3.24.5." >&2
  echo "Current version:" >&2
  flutter --version >&2
  exit 1
fi

"$repo_root/scripts/fetch-rustdesk-web-deps.sh"

pushd "$web_js_dir"
yarn install --frozen-lockfile
yarn build
popd

test -f "$flutter_dir/web/js/dist/index.js"
test -f "$flutter_dir/web/ogvjs-1.8.6/ogv.js"
test -f "$flutter_dir/web/yuv-canvas-1.2.6.js"

pushd "$flutter_dir"
flutter pub get
flutter build web --release
popd

test -f "$flutter_dir/build/web/index.html"
test -f "$flutter_dir/build/web/main.dart.js"
test -f "$flutter_dir/build/web/js/dist/index.js"

rm -rf "$output_dir"
mkdir -p "$output_dir"
tar -czf "$archive" -C "$flutter_dir/build" web

archive_sha256="$(shasum -a 256 "$archive" | awk '{print $1}')"
echo "RustDesk Web archive: $archive"
echo "SHA-256: $archive_sha256"
```

If Task 2 found that the runtime dependency paths differ, update the three `test -f` lines to those exact paths before running the script.

Then run:

```bash
chmod +x scripts/build-rustdesk-web.sh
```

- [ ] **Step 2: Validate script syntax**

Run:

```bash
bash -n scripts/build-rustdesk-web.sh
```

Expected: no output and exit code `0`.

- [ ] **Step 3: Run the first full build**

Run:

```bash
./scripts/build-rustdesk-web.sh
```

Expected: Yarn, TypeScript, Vite, and Flutter all complete successfully. The script prints the archive path and SHA-256.

- [ ] **Step 4: Inspect and fix build failures in the restored scaffold**

For each failure, make the smallest possible source change:

- If generated TypeScript imports fail, inspect `flutter/web/js/gen_js_from_hbb.py` and confirm it is executed from `flutter/web/js`.
- If protoc reports missing include paths, inspect `flutter/web/js/ts_proto.py` and compare it with `libs/hbb_common/protos`.
- If Vite emits a module-name conflict, do not upgrade Vite; keep rollup output filenames fixed as configured in `flutter/web/js/vite.config.js`.
- If Flutter cannot find the web target, confirm `flutter/web/index.html` exists.
- If Dart imports use `dart:html` only under web but still fail, inspect the matching conditional import in `flutter/lib/common.dart` or `flutter/lib/models/platform_model.dart`.

Do not delete the historical scaffold or replace it with a new application. Do not disable compiler errors.

- [ ] **Step 5: Verify archive contents**

Run:

```bash
tar -tzf target/rustdesk-web/rustdesk-web.tar.gz | sed -n '1,120p'
```

Expected: the archive is rooted at `web/` and contains `web/index.html`, `web/main.dart.js`, `web/js/dist/index.js`, Flutter assets, and the runtime dependencies required by `index.html`.

- [ ] **Step 6: Create deployment instructions**

Write `docs/deploy/rustdesk-web/README.md` exactly as:

```markdown
# Deploy the RustDesk Flutter Web client

The web client is a static bundle. It does not add a new backend service and
does not replace your existing RustDesk `hbbs`/`hbbr` deployment.

## Build

Run from the repository root:

```bash
./scripts/build-rustdesk-web.sh
```

The command creates:

```text
target/rustdesk-web/rustdesk-web.tar.gz
```

Record the printed SHA-256 with the release.

## Nginx example

This example assumes the domain is `rustdesk.example.com`, static files are
unpacked under `/var/www/rustdesk-web/current`, and your reverse proxy already
has TLS certificates configured.

```nginx
server {
    listen 443 ssl;
    http2 on;
    server_name rustdesk.example.com;

    # Configure your existing certificate and key.
    ssl_certificate /etc/letsencrypt/live/rustdesk.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/rustdesk.example.com/privkey.pem;

    root /var/www/rustdesk-web/current;
    index index.html;

    location = /index.html {
        add_header Cache-Control "no-cache, must-revalidate";
    }

    location / {
        try_files $uri $uri/ =404;
        add_header Cache-Control "public, max-age=31536000, immutable";
    }

    # Long-lived remote-control sessions require generous proxy timeouts.
    # Replace the upstream ports with the values used by your existing deployment.
    location /ws/id {
        proxy_pass http://127.0.0.1:21118;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
        proxy_buffering off;
    }

    location /ws/relay {
        proxy_pass http://127.0.0.1:21119;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
        proxy_buffering off;
    }
}
```

The `/ws/id` and `/ws/relay` paths are deployment examples. Configure them to
match the exact WebSocket endpoints exposed by your existing RustDesk server
version. Before enabling the site, verify that the browser page and all
WebSocket requests use `https://` or `wss://`; do not deploy an HTTP-only page.

## Caddy example

```caddy
rustdesk.example.com {
    root * /var/www/rustdesk-web/current
    encode gzip zstd

    @immutable {
        not path /index.html
        not path /
    }
    header @immutable Cache-Control "public, max-age=31536000, immutable"
    header /index.html Cache-Control "no-cache, must-revalidate"

    # Replace these ports and paths with the endpoints exposed by your server.
    reverse_proxy /ws/id/* 127.0.0.1:21118
    reverse_proxy /ws/relay/* 127.0.0.1:21119
    file_server
}
```

## Release steps

1. Unpack the new archive into a versioned directory, not directly over the
   current release.
2. Atomically update the `current` symlink to the new version directory.
3. Run `nginx -t` or the equivalent configuration check.
4. Reload the reverse proxy.
5. Open the HTTPS URL and verify one representative controlled device.
6. Keep the previous version directory and configuration for rollback.

Static web deployment is public unless the reverse proxy adds authentication or
network access controls. If the URL must be restricted, use IP allowlisting,
mTLS, or SSO at the reverse proxy before exposing it publicly.
```

- [ ] **Step 7: Confirm generated files are ignored**

Run:

```bash
git status --short flutter/web flutter/build target scripts docs/deploy/rustdesk-web
```

Expected: only `scripts/build-rustdesk-web.sh` and `docs/deploy/rustdesk-web/README.md` are changed. If generated TypeScript, `node_modules`, `flutter/build`, or `target` appear as untracked, add them to the relevant existing `.gitignore` file.

- [ ] **Step 8: Commit**

```bash
git add scripts/build-rustdesk-web.sh docs/deploy/rustdesk-web/README.md flutter/web/.gitignore flutter/web/js/.gitignore .gitignore
git commit -m "build: add RustDesk web release build"
```

---

### Task 4: Add Web contract tests for required scaffold and runtime dependencies

**Files:**
- Create: `scripts/test-rustdesk-web.sh`
- Test: `scripts/test-rustdesk-web.sh`

**Interfaces:**
- Consumes: the source files created in Tasks 1–3 and the archive produced by `scripts/build-rustdesk-web.sh`.
- Produces: exit code `0` when the source tree, archive, and build manifest satisfy the Web contract; any missing required file exits non-zero with a precise error.

- [ ] **Step 1: Create the failing contract test**

Write `scripts/test-rustdesk-web.sh` exactly as:

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
archive="$repo_root/target/rustdesk-web/rustdesk-web.tar.gz"

require_file() {
  if [[ ! -f "$1" ]]; then
    echo "Missing required file: $1" >&2
    exit 1
  fi
}

require_archive_member() {
  if ! tar -tzf "$archive" | grep -qx "$1"; then
    echo "Missing required archive member: $1" >&2
    exit 1
  fi
}

require_file "$repo_root/flutter/web/index.html"
require_file "$repo_root/flutter/web/manifest.json"
require_file "$repo_root/flutter/web/js/package.json"
require_file "$repo_root/flutter/web/js/yarn.lock"
require_file "$repo_root/flutter/lib/web/bridge.dart"
require_file "$repo_root/flutter/lib/models/web_model.dart"

if ! grep -q 'js/dist/index.js' "$repo_root/flutter/web/index.html"; then
  echo "flutter/web/index.html does not load the generated JavaScript entry." >&2
  exit 1
fi

if ! grep -q 'ogv.js' "$repo_root/flutter/web/index.html"; then
  echo "flutter/web/index.html does not load the OGV.js runtime." >&2
  exit 1
fi

if ! grep -q 'yuv-canvas' "$repo_root/flutter/web/index.html"; then
  echo "flutter/web/index.html does not load the YUV canvas runtime." >&2
  exit 1
fi

if ! grep -q 'RUSTDESK_WEB_DEPS_SHA256=' "$repo_root/scripts/rustdesk-web-versions.env"; then
  echo "Runtime dependency checksum is not configured." >&2
  exit 1
fi

if [[ ! -f "$archive" ]]; then
  echo "Build archive does not exist. Run ./scripts/build-rustdesk-web.sh first." >&2
  exit 1
fi

require_archive_member web/index.html
require_archive_member web/main.dart.js
require_archive_member web/js/dist/index.js
require_archive_member web/flutter_service_worker.js

echo "RustDesk Web contract checks passed."
```

Then run:

```bash
chmod +x scripts/test-rustdesk-web.sh
```

- [ ] **Step 2: Run the test against the completed build**

Run:

```bash
./scripts/test-rustdesk-web.sh
```

Expected: `RustDesk Web contract checks passed.`

- [ ] **Step 3: Verify the test catches a missing archive**

Run:

```bash
mv target/rustdesk-web/rustdesk-web.tar.gz target/rustdesk-web/rustdesk-web.tar.gz.keep
if ./scripts/test-rustdesk-web.sh; then
  echo "ERROR: test unexpectedly passed without archive"
  exit 1
else
  echo "Expected failure observed"
fi
mv target/rustdesk-web/rustdesk-web.tar.gz.keep target/rustdesk-web/rustdesk-web.tar.gz
./scripts/test-rustdesk-web.sh
```

Expected: the middle invocation fails with `Build archive does not exist`; the final invocation passes.

- [ ] **Step 4: Run shell syntax validation**

Run:

```bash
bash -n scripts/test-rustdesk-web.sh
```

Expected: no output and exit code `0`.

- [ ] **Step 5: Commit**

```bash
git add scripts/test-rustdesk-web.sh
git commit -m "test: add RustDesk web build contract"
```

---

### Task 5: Add a CI workflow for the Web build

**Files:**
- Create: `.github/workflows/rustdesk-web.yml`
- Modify: `docs/deploy/rustdesk-web/README.md`

**Interfaces:**
- Consumes: `scripts/build-rustdesk-web.sh` and `scripts/test-rustdesk-web.sh`.
- Produces: a GitHub Actions artifact named `rustdesk-web` containing `target/rustdesk-web/rustdesk-web.tar.gz`.

- [ ] **Step 1: Create the workflow**

Write `.github/workflows/rustdesk-web.yml` exactly as:

```yaml
name: RustDesk Web

on:
  push:
    branches:
      - master
      - "codex/**"
    paths:
      - "flutter/web/**"
      - "flutter/lib/web/**"
      - "flutter/lib/models/web_model.dart"
      - "scripts/fetch-rustdesk-web-deps.sh"
      - "scripts/build-rustdesk-web.sh"
      - "scripts/test-rustdesk-web.sh"
      - "scripts/rustdesk-web-versions.env"
      - ".github/workflows/rustdesk-web.yml"
  pull_request:
    paths:
      - "flutter/web/**"
      - "flutter/lib/web/**"
      - "flutter/lib/models/web_model.dart"
      - "scripts/fetch-rustdesk-web-deps.sh"
      - "scripts/build-rustdesk-web.sh"
      - "scripts/test-rustdesk-web.sh"
      - "scripts/rustdesk-web-versions.env"
      - ".github/workflows/rustdesk-web.yml"
  workflow_dispatch:

jobs:
  build:
    name: Build and validate
    runs-on: ubuntu-22.04
    timeout-minutes: 45
    steps:
      - name: Checkout source code
        uses: actions/checkout@v4

      - name: Install Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: stable
          flutter-version: "3.24.5"
          cache: true

      - name: Install Node and Yarn
        uses: actions/setup-node@v4
        with:
          node-version: "20"
          cache: yarn
          cache-dependency-path: flutter/web/js/yarn.lock

      - name: Install protoc
        run: |
          set -euo pipefail
          sudo apt-get update
          sudo apt-get install -y protobuf-compiler
          protoc --version

      - name: Build Web
        run: ./scripts/build-rustdesk-web.sh

      - name: Validate Web contract
        run: ./scripts/test-rustdesk-web.sh

      - name: Upload Web bundle
        if: github.event_name == 'push' || github.event_name == 'workflow_dispatch'
        uses: actions/upload-artifact@v4
        with:
          name: rustdesk-web
          path: target/rustdesk-web/rustdesk-web.tar.gz
          if-no-files-found: error
          retention-days: 14
```

- [ ] **Step 2: Validate YAML syntax**

Run:

```bash
python3 -c "import pathlib, yaml; yaml.safe_load(pathlib.Path('.github/workflows/rustdesk-web.yml').read_text())"
```

Expected: no output and exit code `0`. If `PyYAML` is unavailable, install it in the execution environment or use another YAML parser already available, but do not skip validation.

- [ ] **Step 3: Confirm the workflow path filters do not exclude the workflow itself**

Run:

```bash
rg -n '"\.github/workflows/rustdesk-web.yml"' .github/workflows/rustdesk-web.yml
```

Expected: two matches, one under `push.paths` and one under `pull_request.paths`.

- [ ] **Step 4: Document CI behavior**

Append this section to `docs/deploy/rustdesk-web/README.md`:

```markdown
## Continuous integration

`.github/workflows/rustdesk-web.yml` builds the Web bundle on pushes to
`master` and `codex/**` branches, on relevant pull requests, and manually
through `workflow_dispatch`. Successful push and manual runs upload an artifact
named `rustdesk-web`.
```

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/rustdesk-web.yml docs/deploy/rustdesk-web/README.md
git commit -m "ci: build RustDesk web bundle"
```

---

### Task 6: Perform browser-level functional validation

**Files:**
- Create: `docs/deploy/rustdesk-web/VALIDATION.md`
- No source files should be modified during this task unless a defect is found.

**Interfaces:**
- Consumes: the archive generated by `scripts/build-rustdesk-web.sh`, the user's existing HTTPS domain, existing `hbbs`/`hbbr` deployment, and one representative controlled RustDesk device.
- Produces: a completed validation record with pass/fail status, browser versions, timestamp, device ID redacted as `REDACTED-DEVICE-ID`, and any follow-up defects.

- [ ] **Step 1: Serve a local build for smoke validation**

Run:

```bash
pushd flutter/build/web
python3 -m http.server 8099
popd
```

Open `http://127.0.0.1:8099/` in Chrome. Expected: the page loads without a blank screen or JavaScript error. Because this is an HTTP local smoke test, do not treat remote WebSocket connection as a pass or fail result; use the HTTPS deployment for connectivity.

- [ ] **Step 2: Stop the local smoke server**

Run:

```bash
pkill -f "python3 -m http.server 8099"
```

Expected: the command terminates the smoke server. If `pkill` reports no process, inspect the terminal and stop the correct process manually.

- [ ] **Step 3: Deploy the archive to the staging HTTPS host**

Use the release procedure in `docs/deploy/rustdesk-web/README.md`. Do not overwrite the production release during first validation.

- [ ] **Step 4: Validate Chrome remote control**

Record each result in `docs/deploy/rustdesk-web/VALIDATION.md`:

```markdown
# RustDesk Web validation record

- Date: `YYYY-MM-DD HH:mm TZ`
- Build SHA-256: `<archive sha256>`
- Deployment URL: `<redacted-or-private-staging-url>`
- Device ID: `REDACTED-DEVICE-ID`
- Browser: Chrome `<version>`

| Check | Result | Notes |
|---|---:|---|
| HTTPS page loads | PASS | |
| No mixed-content warning | PASS | |
| Connection form accepts server, key, and device ID | PASS | |
| Password prompt appears | PASS | |
| Remote video renders | PASS | |
| Mouse click reaches remote device | PASS | |
| Mouse drag reaches remote device | PASS | |
| Scroll reaches remote device | PASS | |
| Printable-key input reaches remote device | PASS | |
| Shortcut keys reach remote device | PASS | |
| Fullscreen enters and exits | PASS | |
| Wrong password shows actionable error | PASS | |
| Unknown ID shows actionable error | PASS | |
| Network interruption shows disconnect state | PASS | |
| Reconnect action works | PASS | |
```

Expected: every required row is `PASS` and no browser console errors remain that affect connection, rendering, or input.

- [ ] **Step 5: Perform targeted non-Chrome checks**

Repeat the connection, render, click, keyboard, fullscreen, and disconnect checks in Edge, Firefox, and Safari. Record each browser and any platform-specific failure. Do not block release for a browser-specific issue that was not part of the first-release success criteria unless it affects Chrome.

- [ ] **Step 6: Commit the validation record**

```bash
git add docs/deploy/rustdesk-web/VALIDATION.md
git commit -m "docs: record RustDesk web validation"
```

---

### Task 7: Release readiness review

**Files:**
- Create: `docs/deploy/rustdesk-web/RELEASE.md`
- No source files should be modified during this task unless the review finds a defect.

**Interfaces:**
- Consumes: the implementation from Tasks 1–6 and the design at `docs/superpowers/specs/2026-09-21-rustdesk-web-client-design.md`.
- Produces: a release checklist and the exact rollback procedure.

- [ ] **Step 1: Review the complete diff**

Run:

```bash
git log --oneline a419d3258..HEAD
git diff --stat a419d3258..HEAD
git diff --check a419d3258..HEAD
```

Expected: commits contain only Web scaffold/build/CI/docs/validation changes; `git diff --check` emits no output.

- [ ] **Step 2: Review scope against the design**

Read `docs/superpowers/specs/2026-09-21-rustdesk-web-client-design.md` and confirm:

- Static bundle only; no new backend service.
- Existing `hbbs`/`hbbr` unchanged.
- HTTPS and `wss://` deployment guidance present.
- Remote desktop control validated in Chrome.
- File transfer, terminal, and port forwarding absent or disabled in the first release.
- Build and deployment instructions are reproducible.
- Rollback procedure is present.

- [ ] **Step 3: Write the release checklist**

Write `docs/deploy/rustdesk-web/RELEASE.md` exactly as:

```markdown
# RustDesk Web release checklist

1. Confirm the Web CI workflow passed on the release commit.
2. Record the release commit SHA.
3. Run `./scripts/build-rustdesk-web.sh`.
4. Record the archive SHA-256 printed by the build script.
5. Run `./scripts/test-rustdesk-web.sh`.
6. Confirm `docs/deploy/rustdesk-web/VALIDATION.md` has no open `FAIL` rows.
7. Confirm the reverse-proxy configuration passes its syntax check.
8. Confirm the reverse-proxy configuration has HTTPS and WebSocket timeouts.
9. Unpack the archive into a new versioned release directory.
10. Atomically switch the `current` symlink.
11. Reload the reverse proxy.
12. Open the HTTPS URL and verify one representative controlled device.
13. Preserve the previous release directory and configuration for rollback.

## Rollback

1. Change the `current` symlink back to the previous release directory.
2. Reload the reverse proxy.
3. Refresh the browser, bypassing any cached service worker if necessary.
4. Verify one representative controlled device again.

If the rollback does not restore service, restore the previous reverse-proxy
configuration, reload the proxy, and inspect WebSocket errors in the browser
console and reverse-proxy logs.
```

- [ ] **Step 4: Final validation**

Run:

```bash
./scripts/build-rustdesk-web.sh
./scripts/test-rustdesk-web.sh
git diff --check
git status --short
```

Expected: both scripts pass, `git diff --check` emits no output, and there are no unexpected modified or untracked files.

- [ ] **Step 5: Commit**

```bash
git add docs/deploy/rustdesk-web/RELEASE.md
git commit -m "docs: add RustDesk web release checklist"
```

- [ ] **Step 6: Report the release artifact**

In the final implementation report, include:

- Release commit SHA.
- Archive path: `target/rustdesk-web/rustdesk-web.tar.gz`.
- Archive SHA-256.
- Deployment documentation path.
- Validation record path.
- Any known browser limitations.
