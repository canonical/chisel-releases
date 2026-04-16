# Chisel Slice Platform — Monitor + Build

## Context

We maintain our own chisel slice definitions for 100+ Ubuntu packages. We need two things:

1. **Monitor**: Daily check for new package versions. If anything changed (files, deps), create a GitHub issue with the full diff.
2. **Build**: A tool that takes our slices + a snapshot-pinned manifest and produces a minimal rootfs. Uses native APT + dpkg (no chisel binary).

## What We Build

- `monitor.py` (~300 lines) — checks for updates, diffs packages, creates issues
- `build.py` (~200 lines) — resolves deps from snapshot, downloads debs, extracts sliced files into rootfs
- `check-updates.yaml` — daily cron that runs monitor.py
- `build.yaml` — builds containers on merge or manual trigger

## Repo Structure

```
main branch:
  .github/
    scripts/
      monitor.py             # Version check + file diff + dep diff
      build.py               # Snapshot resolve + deb download + slice extraction
      requirements.txt       # python-debian, pyyaml, requests
    workflows/
      check-updates.yaml     # Daily cron → issues
      build.yaml             # Build containers on merge / manual

Each ubuntu-XX.XX branch (existing structure, unchanged):
  chisel.yaml                # Standard format (reference/compat)
  slices/                    # Our slice definitions
    curl.yaml
    openssl.yaml
    ...
  manifest.yaml              # NEW: packages we track + pinned versions + snapshot
  snapshot.lock              # NEW: generated — resolved versions + SHA256s
```

## `manifest.yaml` (per release branch)

Simple list of what we track and what we currently have pinned:

```yaml
schema: 1
snapshot: "20260401T000000Z"

packages:
  curl:
    version: "8.5.0-2ubuntu10.6"
  libcurl4t64:
    version: "8.5.0-2ubuntu10.6"
  openssl:
    version: "3.0.13-0ubuntu3.5"
  libssl3t64:
    version: "3.0.13-0ubuntu3.5"
  libc6:
    version: "2.39-0ubuntu8.4"
  ca-certificates:
    version: "20240203"
  # ... 100+ packages
```

## `monitor.py` — What It Does

Runs inside an `ubuntu:XX.XX` container (needs `dpkg-deb`, `apt-get`).

### Step 1: Check for version updates

```
For each package in manifest.yaml:
  1. apt-cache policy <package>  →  get latest available version
  2. Compare against version in manifest.yaml
  3. If different → package has an update
```

### Step 2: For each updated package, diff files + deps

```
For each updated package:
  1. apt-get download <package>=<old-version>  (from snapshot)
  2. apt-get download <package>=<new-version>  (from current archive)
  3. dpkg-deb --contents <old>.deb  →  old file list
  4. dpkg-deb --contents <new>.deb  →  new file list
  5. diff the file lists → added, removed, changed files
  6. dpkg-deb --info <old>.deb  →  old Depends
  7. dpkg-deb --info <new>.deb  →  new Depends
  8. diff the dependency lists → added, removed deps
  9. Cross-reference with our slice YAML:
     - Are any REMOVED files listed in our slices? → BREAKING
     - Are any ADDED files things we might want? → INFO
     - Are any NEW dependencies not in our manifest? → WARNING
```

### Step 3: Generate issue body

For each package with changes, produce a markdown report:

```markdown
## curl: 8.5.0-2ubuntu10.5 → 8.5.0-2ubuntu10.6

### File Changes
| Status | Path | In Slice? |
|--------|------|-----------|
| ➕ Added | /usr/share/doc/curl/NEWS.Debian.gz | No |
| ➖ Removed | (none) | |

### Dependency Changes
| Status | Dependency |
|--------|-----------|
| (no changes) |

### Slice Impact: ✅ None — safe to update version pin
```

Or for breaking changes:
```markdown
## libssl3t64: 3.0.13-0ubuntu3.4 → 3.0.14-0ubuntu1

### File Changes
| Status | Path | In Slice? |
|--------|------|-----------|
| ➖ Removed | /usr/lib/x86_64-linux-gnu/libssl.so.3.0 | ⚠️ YES: libssl3t64_libs |
| ➕ Added | /usr/lib/x86_64-linux-gnu/libssl.so.3.1 | No |

### Dependency Changes
| Status | Dependency |
|--------|-----------|
| ➕ Added | libfoo2 (>= 1.0) |

### Slice Impact: ❌ BREAKING — libssl3t64_libs references removed file
### Action Required: Update slice to use new .so path, add libfoo2 to manifest
```

## `check-updates.yaml` — Daily Cron Workflow

```yaml
on:
  schedule:
    - cron: '0 6 * * *'
  workflow_dispatch:
    inputs:
      release:
        description: 'Specific release to check (e.g. ubuntu-24.04), or "all"'
        default: 'all'

jobs:
  check:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        release: [ubuntu-20.04, ubuntu-22.04, ubuntu-24.04, ubuntu-25.10, ubuntu-26.04]
    container:
      image: ubuntu:${{ <extract version from matrix.release> }}
    steps:
      - uses: actions/checkout@HASH
        with:
          ref: ${{ matrix.release }}

      - uses: actions/checkout@HASH
        with:
          ref: main
          path: _main

      - name: Install deps
        run: |
          apt-get update
          apt-get install -y python3 python3-pip
          pip install -r _main/.github/scripts/requirements.txt

      - name: Configure snapshot sources
        run: |
          # Add snapshot source for old versions + current archive for new
          # (monitor.py handles this internally)

      - name: Check for updates
        run: python3 _main/.github/scripts/monitor.py check --manifest manifest.yaml --slices slices/
        id: check

      - name: Create issues for changes
        if: steps.check.outputs.has_updates == 'true'
        uses: actions/github-script@HASH
        with:
          script: |
            // Read report.json output from monitor.py
            // For each updated package, create or update a GitHub issue
            // Label: 'package-update', release name, severity (breaking/safe)
            // Avoid duplicate issues (check for existing open issue for same package+release)
```

## monitor.py Internals

```python
# ~300 lines total

import subprocess, json, yaml, sys, re
from pathlib import Path
from debian.deb822 import Packages  # from python-debian

def check_updates(manifest_path, slices_dir):
    """Main entry point. Returns list of package update reports."""
    manifest = yaml.safe_load(Path(manifest_path).read_text())
    reports = []

    for pkg_name, pkg_info in manifest['packages'].items():
        current_ver = pkg_info['version']
        latest_ver = get_latest_version(pkg_name)

        if latest_ver != current_ver:
            report = diff_package(pkg_name, current_ver, latest_ver, slices_dir)
            reports.append(report)

    return reports

def get_latest_version(package):
    """apt-cache policy <package> → parse latest version."""
    ...

def diff_package(name, old_ver, new_ver, slices_dir):
    """Download both versions, diff files and deps, check slice impact."""

    old_files = get_deb_contents(name, old_ver)  # dpkg-deb --contents
    new_files = get_deb_contents(name, new_ver)

    old_deps = get_deb_depends(name, old_ver)     # dpkg-deb --info → Depends
    new_deps = get_deb_depends(name, new_ver)

    # Load our slice definition for this package
    slice_files = load_slice_contents(slices_dir, name)

    added = new_files - old_files
    removed = old_files - new_files
    deps_added = new_deps - old_deps
    deps_removed = old_deps - new_deps

    # Check if removed files are in our slices
    breaking = removed & slice_files

    return {
        'package': name,
        'old_version': old_ver,
        'new_version': new_ver,
        'files_added': sorted(added),
        'files_removed': sorted(removed),
        'deps_added': sorted(deps_added),
        'deps_removed': sorted(deps_removed),
        'breaking_files': sorted(breaking),
        'is_breaking': len(breaking) > 0,
    }
```

## `build.py` — The Build Tool

Produces a rootfs from our slices using native APT + dpkg. Runs inside an Ubuntu container.

### Subcommand: `build.py resolve`

Resolves exact package versions from the snapshot archive and writes `snapshot.lock`.

1. Configure APT sources to point at `snapshot.ubuntu.com/ubuntu/TIMESTAMP/`
2. `apt-get update` (against snapshot — deterministic)
3. For each package in manifest: `apt-cache show <package>` → exact version, SHA256, filename
4. Walk `Depends:` recursively → full transitive dependency set
5. Write `snapshot.lock`:

```yaml
# Auto-generated — DO NOT EDIT
generated: "2026-04-09T12:00:00Z"
snapshot: "20260401T000000Z"

packages:
  curl:
    version: "8.5.0-2ubuntu10.6"
    sha256: "abc123..."
    filename: "pool/main/c/curl/curl_8.5.0-2ubuntu10.6_amd64.deb"
  libcurl4t64:
    version: "8.5.0-2ubuntu10.6"
    sha256: "def456..."
    filename: "pool/main/c/curl/libcurl4t64_8.5.0-2ubuntu10.6_amd64.deb"
    required-by: [curl_bins]
  libc6:
    version: "2.39-0ubuntu8.4"
    sha256: "789abc..."
    filename: "pool/main/g/glibc/libc6_2.39-0ubuntu8.4_amd64.deb"
    required-by: [curl_bins, openssl_bins]
```

### Subcommand: `build.py build --arch amd64 --output rootfs/`

Builds the minimal rootfs.

1. Read `snapshot.lock` → list of packages to download
2. `apt-get download` each package (APT sources already pinned to snapshot)
3. Verify SHA256 against lock file
4. For each .deb, for each slice referencing that package:
   - `dpkg-deb -x <pkg>.deb /tmp/extract/`
   - Read slice YAML → get `contents:` file list
   - Copy only those files into `rootfs/`
   - Handle special types: `{text: '...'}`, `{symlink: /path}`, `{arch: [amd64]}`
5. Output clean `rootfs/` ready for `COPY --from` in Dockerfile

### Subcommand: `build.py bom`

Reads `snapshot.lock` + slices, outputs:
- `bom.json` — machine-readable (packages, versions, hashes, dependency graph)
- `bom.md` — markdown table for humans

### Container Usage

```dockerfile
FROM ubuntu:24.04 AS builder
ARG SNAPSHOT=20260401T000000Z

# Pin APT to snapshot
RUN printf "deb http://snapshot.ubuntu.com/ubuntu/${SNAPSHOT}/ noble main universe\n\
deb http://snapshot.ubuntu.com/ubuntu/${SNAPSHOT}/ noble-updates main universe\n\
deb http://snapshot.ubuntu.com/ubuntu/${SNAPSHOT}/ noble-security main universe\n" \
    > /etc/apt/sources.list && apt-get update

# Copy build tool + slice definitions
COPY build.py manifest.yaml snapshot.lock /build/
COPY slices/ /build/slices/

# Build rootfs
RUN apt-get install -y python3 python3-yaml && \
    cd /build && python3 build.py build --arch amd64 --output /rootfs

FROM scratch
COPY --from=builder /rootfs /
```

## `build.yaml` — Build Workflow

```yaml
on:
  push:
    branches: ['ubuntu-*']
  workflow_dispatch:
    inputs:
      release: { description: 'Ubuntu release branch', required: true }

jobs:
  build:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        arch: [amd64, arm64]
    container:
      image: ubuntu:${{ <version from branch> }}
    steps:
      - checkout release branch
      - checkout main (for scripts)
      - apt-get update && apt-get install -y python3 python3-yaml python3-debian
      - python3 build.py resolve
      - python3 build.py build --arch ${{ matrix.arch }} --output rootfs/
      - python3 build.py bom
      - # Build FROM scratch container
      - # Push to GHCR with tag: <release>-<snapshot>-<arch>
      - # Commit snapshot.lock + bom.json + bom.md if changed
```

## Implementation Order

### Phase 1: monitor.py (~300 lines)
1. `get_latest_version()` — parse `apt-cache policy` output
2. `get_deb_contents()` — download .deb + parse `dpkg-deb --contents`
3. `get_deb_depends()` — parse `dpkg-deb --info` Depends field
4. `load_slice_contents()` — parse slice YAML, extract file paths
5. `diff_package()` — orchestrate the comparison
6. `check_updates()` — main loop over manifest
7. Output: `report.json` + human-readable markdown

### Phase 2: build.py (~200 lines)
8. `resolve` subcommand — configure snapshot sources, resolve deps, write lock
9. `build` subcommand — download debs, extract sliced files into rootfs
10. `bom` subcommand — read lock + slices, output JSON + markdown

### Phase 3: Bootstrap ubuntu-24.04
11. Create `manifest.yaml` with ~20 starter packages
12. Copy/author slice definitions for those packages
13. Run resolve → lock, build → rootfs, verify it works
14. Test: `docker run` the resulting container

### Phase 4: CI workflows
15. `check-updates.yaml` — daily cron + issue creation
16. `build.yaml` — build + push containers

### Phase 5: Scale
17. Expand to full package list (100+)
18. Add remaining Ubuntu releases

## Files to Create

| File | Location | Est. Lines | Description |
|------|----------|-----------|-------------|
| `monitor.py` | `.github/scripts/` on main | ~300 | Version check + file diff + dep diff |
| `build.py` | `.github/scripts/` on main | ~200 | Resolve + build rootfs + BOM |
| `requirements.txt` | `.github/scripts/` on main | 3 | python-debian, pyyaml |
| `check-updates.yaml` | `.github/workflows/` on main | ~80 | Daily cron → issues |
| `build.yaml` | `.github/workflows/` on main | ~80 | Build containers on merge |
| `manifest.yaml` | root of each `ubuntu-*` branch | ~50-200 | Tracked packages + versions + snapshot |
| `snapshot.lock` | root of each `ubuntu-*` branch | generated | Resolved versions + SHA256s |

## Verification

1. `monitor.py` correctly identifies packages with newer versions
2. `monitor.py` diff is accurate — matches manual `dpkg-deb --contents` comparison
3. `monitor.py` flags breaking changes when removed files are in our slices
4. `build.py resolve` produces lock file with correct versions from snapshot
5. `build.py build` produces rootfs with only the files defined in slices
6. Container built from rootfs works: `curl --version` etc.
7. Rebuild with same manifest+lock → identical rootfs
8. Workflow creates properly formatted issues with correct labels
9. Duplicate detection: running monitor twice doesn't create duplicate issues
