# Slice Builder Tool — Implementation Plan

## Problem

Bin packages (.tar.xz packed by `bincraft pack`) are not Ubuntu debs, so the existing deb-slicing workflow (apt download → dpkg -c → design slices) does not apply. Yet these bins must be consumable by `chisel cut` alongside Ubuntu archive slices, so each bin needs an SDF in the new store: bin namespace. Authoring these by hand does not scale (sd-tools produces bins in bulk), so an automated SDF generator is needed.

## Scope

**In:** generate one SDF per bin archive; classify paths; resolve `essential`
to dep slices; detect literal path conflicts and emit `prefer`; validate; emit
final SDF.

**Out:** hand-tuning (output is final); forward-porting (sd-tools orchestrates);
glob conflict resolution (Chisel handles at cut time; unresolvable conflicts flag for human review).

## Architecture

The tool is a **Python CLI** (`slice-builder`) managed with **uv**, wrapping
an **oh-my-pi (`omp`) agent**. The tool handles deterministic I/O; the agent
handles judgment calls guided by the `sdf-generation` skill. All tool source,
tests, prompts, and config live under a single top-level `slice-builder/`
directory so the tool can be extracted to its own repository with no rework.

```
┌─ slice-builder (Python CLI, uv-managed) ──────────┐
│ 1. Parse args (argparse)                            │
│ 2. Shallow-clone chisel-releases ubuntu-<base>      │
│ 3. Read chisel.yaml → format, default-prefix,       │
│    bin SDF directory                                │
│ 4. Overlay --sdf-lookup-dir SDFs onto checkout      │
│ 5. Extract --bin-archive → enumerate paths          │
│ 6. Invoke omp agent(paths, deps, dep-SDFs, skill)  │
│ 7. Validate output (yamllint, sort, parse)          │
│ 8. Write to --output                                │
└─────────────────────────────────────────────────────┘
         │
┌─ oh-my-pi agent (consumes sdf-generation skill) ────┐
│ - Classify paths → slices                           │
│ - Analyze dep SDFs → pick essential slices          │
│ - Detect literal path conflicts → prefer            │
│ - Render SDF (sorted, map-format essential)         │
└─────────────────────────────────────────────────────┘
```

**Design decision — agent+skill vs deterministic code:**
- *Chosen (agent + skill):* heuristics evolve via skill edits without code
  changes; handles ambiguous dep-slice selection flexibly. Trade-off:
  non-deterministic, slower, requires LLM.
- *Alternative (deterministic):* fast, testable, but requires code changes
  when path→slice rules evolve.
- *Future:* hybrid — deterministic for clear rules (path table, sort, render),
  agent only for dep-slice selection.

**Design decision — Python + uv:**
- *Chosen:* matches the Canonical SD toolchain convention (slupgrader,
  pydep_differ, sd-tools are all Python/uv). `uv run slice-builder ...`
  resolves deps from `pyproject.toml` with no install step; `uv` is already
  present in the workshop SDK. argparse CLI mirrors slupgrader's `cli.py` /
  `__main__.py` split. `justfile` recipes mirror slupgrader's for
  `test`/`fmt`/`lint`/`run`.
- *Alternative (Go):* would match chisel itself, but the agent-orchestration
  layer (subprocess, prompt assembly, retry loop) is lighter in Python and
  the sibling tools are Python.

**Design decision — oh-my-pi as agent:**
- *Chosen:* `omp` is already in the workshop SDK (`workshop.yaml` lists
  `omp`). It exposes a one-shot mode (`omp -p "<prompt>"`) and a persistent
  RPC mode (`omp --mode rpc`, NDJSON over stdio). It auto-discovers skills
  from disk (`.claude`, `.cursor`, `AGENTS.md`, `skills/`), so the
  `sdf-generation` skill is picked up with no wiring. Its `read`/`write`/
  `bash`/`search` tools let it inspect the checkout and dep SDFs directly.
- *Integration mode:* **one-shot (`omp -p`)** per invocation. The builder
  assembles a single prompt (paths, deps, dep-SDF summaries, skill pointer),
  runs `omp -p` with `--tools read,write,search,bash` and a constrained
  working directory, and parses the SDF from the agent's `write` output or
  stdout. RPC mode is a future optimisation to amortise session startup
  across a batch.
- *Alternative (LangChain/LangGraph in-process):* slupgrader's approach. Heavier
  dependency surface; omp is already installed and tuned.

## Project layout

Everything lives under `slice-builder/` so the directory can be lifted into
its own git repository (e.g. `canonical/slice-builder`) without moving files.
The `chisel-releases` repo gains only the `slice-builder/` subtree plus the
`sdf-generation` skill; the SDF outputs go to the existing `slices/` (or
`bin-slices/`) tree as today.

```
slice-builder/
├── pyproject.toml          # uv project; [project.scripts] slice-builder=...
├── README.md               # install + usage (mirrors slupgrader README shape)
├── justfile                # test / fmt / lint / run recipes (uv run ...)
├── ruff.toml               # line-length 100, match repo style
├── yamllint.yaml           # tool-owned yamllint config (repo's is local-only)
├── src/
│   └── slice_builder/
│       ├── __init__.py
│       ├── __main__.py     # `python -m slice_builder` entry
│       ├── cli.py          # argparse parser + main() (slupgrader-style)
│       ├── config.py       # dataclasses: BuildConfig, DepRef, etc.
│       ├── checkout.py     # shallow-clone chisel-releases ubuntu-<base>
│       ├── release.py      # parse chisel.yaml → format, stores, prefix, dir
│       ├── archive.py      # extract .tar.xz → sorted path list
│       ├── overlay.py      # copy --sdf-lookup-dir onto checkout
│       ├── deps.py         # locate + load dep SDFs (bin vs deb detection)
│       ├── prefer.py       # literal-path conflict scan across checkout SDFs
│       ├── agent.py        # omp invocation: prompt assembly + `omp -p` runner
│       ├── render.py       # sort + emit SDF YAML (map essential, quoted track)
│       ├── validate.py     # yamllint + sort-check + parse-check
│       └── sdf.py          # SDF data model + YAML load/dump helpers
├── prompts/
│   └── system.md          # base system prompt for the omp agent
├── skills/
│   └── sdf-generation/
│       └── SKILL.md       # the skill consumed by omp (see Skill section)
└── tests/
    ├── conftest.py
    ├── unit/              # fast, no LLM (archive, release, render, validate)
    └── integration/       # @slow, requires omp + LLM credentials
```

**`pyproject.toml` essentials** (slupgrader-aligned):

```toml
[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[project]
name = "slice-builder"
version = "0.1.0"
requires-python = ">=3.12"
dependencies = [
  "pyyaml>=6.0",     # SDF load/dump
  "yamllint>=1.35",   # validation
]

[project.scripts]
slice-builder = "slice_builder.cli:main"

[tool.hatch.build.targets.wheel]
packages = ["src/slice_builder"]

[tool.ruff]
line-length = 100
```

Run without installing: `uv run slice-builder ...` (uv resolves deps from
`pyproject.toml` into an ephemeral venv). Tests: `uv run pytest`. Lint:
`uv run --with ruff ruff check && uv run --with ruff ruff format --check`.

## Data flow

```
sd-tools ──invoke──▶ uv run slice-builder generate-sdf
  │
  ├─ 1. Derive branch: ubuntu-<base> (e.g. ubuntu-26.04)
  ├─ 2. Shallow-clone → temp dir
  ├─ 3. Read chisel.yaml → format (v3/v4), stores.bin.default-prefix, bin SDF dir
  ├─ 4. Copy --sdf-lookup-dir/*.yaml → checkout bin SDF dir (overlay)
  ├─ 5. Extract bin.tar.xz → path list
  ├─ 6. For each dep: locate SDF in checkout → load
  ├─ 7. omp -p (skill, paths, deps, dep-SDFs, checkout) → SDF YAML
  ├─ 8. Validate: yamllint + sort-check + parse
  └─ 9. Write to --output
```

**Checkout strategy:** per-invocation shallow clone to a temp dir (no state,
no concurrency issues). Can optimize to a long-lived checkout with
`git fetch + reset` if performance demands.

**SDF lookup overlay:** `--sdf-lookup-dir` is read-only (populated by sd-tools,
never overwritten). The builder copies its contents onto the checkout so the
agent sees a unified tree (Ubuntu archive SDFs + previously generated bin
SDFs). Within a batch, sd-tools adds each output to the cache, so subsequent
invocations see prior outputs.

**omp invocation detail:** the builder writes the assembled prompt to a temp
file and runs `omp -p "$(cat prompt.txt)" --tools read,write,search,bash
--cwd <checkout>` (one-shot). The agent is instructed to `write` the SDF to a
known temp path inside the checkout; the builder reads that file back, then
validates. On validation failure the builder re-runs `omp -p` with the
validation errors appended (≤N retries). The `sdf-generation` skill is
discovered by omp from `slice-builder/skills/` (omp auto-discovers on-disk
skills); no `--skill` flag is needed. If omp exits 0 but writes no SDF file,
treat it as a validation failure and retry (then Error, exit 1). The exact omp
flags (`-p`, `--tools`, `--cwd`, model selector) must be verified against
`omp --help` on the workshop SDK before wiring — the flags above are the
intended interface, not confirmed.

**chisel.yaml parsing:** the plan assumes `format: v3`/`v4` and a
`stores.bin.default-prefix` key, but the only in-repo `chisel.yaml` example
(in `.github/scripts/install-slices/test_install_slices.py`) is `format: v1`.
The implementer must read the actual `chisel.yaml` from the cloned
`ubuntu-<base>` branch and verify the real schema (format value, stores
layout, default-prefix key name, bin SDF directory) before coding `release.py`
— do not assume the v3/v4 specifics above are accurate.

## Path→slice classification

| Path pattern | Slice |
|---|---|
| `/usr/bin/**`, `/bin/**` | `bins` |
| `/usr/lib/**`, `/lib/**` | `libs` |
| `/etc/**` | `config` |
| `/usr/share/doc/**/copyright` | `copyright` |
| `/usr/share/gocode/src/**` | `src` |

Rules:
- Only emit slices with ≥1 path.
- `copyright`: always expected; only created if the archive actually contains a
  copyright file. If created, add `bin-<package>_copyright` to top-level
  `essential`.
- Unmatched paths: flag for human review; agent must not silently drop them.
- Table is provisional; will be refined as more bins are processed.

## Documentation

Chisel and chisel-releases https://canonical-chisel--72.com.readthedocs.build/72/

## Essential resolution

For each dependency `sd_name` from `--dependencies`:

1. **Locate dep SDF:** search `--sdf-lookup-dir` (bin SDFs from prev runs),
   then the checkout (v3: `bin-slices/<sd_name>.yaml` or
   `slices/<sd_name>.yaml`; v4: `slices/<sd_name>.yaml`).
2. **Determine bin vs deb:** if SDF has `store: bin` → bin dep (slice refs use
   `default-prefix`, e.g. `bin-<dep>_...`); otherwise → deb dep (bare name,
   `<dep>_...`).
3. **Analyze dep SDF → pick slice(s):** the agent reads the dep's slices and
   contents, selects the slice(s) that provide what the current bin needs
   (e.g. `libs` for a library, `bins` for a binary). This is a judgment call
   guided by the skill.
4. **Emit in v3/v4 map format:**
   ```yaml
   essential:
     libc6_libs: {}
     bin-go-github-some-dep_bins: {}
   ```
5. **Dep SDF not found:** error (cannot resolve essential). Do not emit
   unresolved references.

## Prefer detection

1. Collect all **literal** (non-glob) paths from the bin's contents.
2. Scan all SDFs in the checkout for literal paths.
3. For each literal path in the bin that also appears in another package:
   - **Bin vs deb:** emit `prefer: <deb-package-name>` on the bin's path. Deb
     wins by default.
   - **Bin vs bin:** flag for human review (no default resolution).
4. **Glob paths:** `prefer` forbidden on globs (spec). Glob conflicts are
   detected by Chisel at cut time; if Chisel errors, human review.
5. `prefer` value = unique package identifier of the preferred package (bare
   name for debs, `bin-<name>` for bins).

## Invocation contract

sd-tools invokes the slice builder as a subprocess. Because the tool is
uv-managed, the command is `uv run slice-builder ...` (uv is on PATH in the
workshop SDK). sd-tools locates the binary via PATH, mirroring how it locates
`slupgrader`.

```
uv run slice-builder generate-sdf \
  --bin-archive <path/to/bin.tar.xz> \
  --base <base> \
  --package <sd_name> \
  --track <track> \
  --dependencies <sd_name1>,<sd_name2>,... \
  --sdf-lookup-dir <path/to/sdf-cache> \
  --output <path/to/<sdf-dir>/<bare-name>.yaml>
```

| Parameter | Description |
|---|---|
| `--bin-archive` | `.tar.xz` from `bincraft pack`. Extracted to inspect contents. |
| `--base` | Ubuntu base (e.g. `26.04`). Derives branch `ubuntu-26.04`, fetched shallow. |
| `--package` | Bin's SD name, bare (e.g. `curl`). → `package:` field + output filename basename. |
| `--track` | Bin's track (e.g. `v1.2.3`). → `default-track:` (always YAML-quoted to force string). |
| `--dependencies` | Comma-separated `sd_name` values (may be empty). Bin-to-bin refs use prefixed name, no track. |
| `--sdf-lookup-dir` | Read-only cache of already-generated bin SDFs (populated by sd-tools). Overlaid onto checkout. |
| `--output` | Full output path. Dir determined by release format: v3→`bin-slices/`, v4→`slices/`. |
| `--omp` | (opt) Path to `omp` binary; default `omp` on PATH. |
| `--omp-model` | (opt) Model selector for omp (e.g. `gemini/gemini-flash-latest`). Default: omp's configured default. |
| `--retries` | (opt) Max agent retries on validation failure. Default 3. |

Exit 0 = success; non-zero = failure (sd-tools surfaces stderr). Exit codes
follow slupgrader's convention: 0 success, 1 SDF generation failed, 2
input/config error (bad archive, missing dep SDF, bad args).

## Output shape

```yaml
package: go-github-some-package
store: bin
default-track: "v1.2.3"

essential:
  bin-go-github-some-package_copyright:

slices:
  bins:
    essential:
      libc6_libs:
      bin-go-github-some-dep_bins:
    contents:
      /usr/bin/some-binary:

  libs:
    contents:
      /usr/lib/go-github-some-package/**:

  config:
    contents:
      /etc/some-package/config.yaml:

  copyright:
    contents:
      /usr/share/doc/go-github-some-package/copyright:
```

**Key format rules:**
- `essential` uses **v3/v4 map format** (a YAML mapping, not a v1/v2 list).
  Emit each entry as `key:` (null value) to match the existing bin SDFs in the
  repo (e.g. `slices/bins/curl.yaml`, `slices/foo.yaml`); the `key: {}` notation
  denotes "map format", not a literal empty-dict value.
- Slice refs use the **`bin-` prefix** for bin packages (read from
  `stores.bin.default-prefix` in `chisel.yaml`, not hardcoded).
- `default-track` **always quoted** (prevents YAML float parsing of `0.1` etc.).
- `copyright` + top-level `essential` only if archive contains a copyright file.
- **Output directory is sd-tools' responsibility** — the builder writes to the
  exact `--output` path and does not compute or validate the directory. The
  `v3→bin-slices/`, `v4→slices/` mapping is sd-tools' concern (note the
  current dev branch uses `slices/bins/`).
- **YAML emission:** use a custom PyYAML `Dumper` to force the repo style —
  block style for maps, `default-track` as a quoted scalar, contents paths and
  `essential` entries as null-valued keys (`/path:`). Do not emit flow style,
  anchors, or `!!` tags.

## Validation

Builder validates before writing (sd-tools does no further processing):
1. **yamllint** with the tool's own config (`slice-builder/yamllint.yaml`),
   authored from scratch — the repo's root `yamllint.yaml` and `lint.sh` are
   local-only and not committed, so the tool must not reference them. The
   `yamllint` Python package is a declared dependency; invoke it as a
   subprocess against the temp SDF. Start from `extends: default` and tighten
   to match the SDF style (2-space indent, 100-char lines, no document-start
   marker).
2. **Sort-check** `contents` paths and `essential` entries in **byte order**
   (`LC_COLLATE=C`), lexicographic. Builder implements its own check in
   `validate.py` (no reusable repo linter exists).
3. **Parse-check** required fields (`package`, `store`, `default-track`,
   `slices`) via `sdf.py`.
4. Validation fail → agent retries (≤`--retries`) or tool errors.

## Failure modes

| Condition | Behavior |
|---|---|
| Malformed archive | Error (exit 2) |
| No paths match any rule | Error (exit 1) |
| Unmatched paths | Warn; flag for review; don't drop |
| Dep SDF not found | Error (exit 2) |
| Glob conflict | Warn; Chisel handles at cut time |
| Bin-vs-bin literal conflict | Warn; no default; flag for review |
| Output exists | Error (exit 2); don't overwrite |
| `omp` not on PATH | Error (exit 2) |
| omp invocation fails / non-zero | Error (exit 1) |
| Validation fails after N retries | Error (exit 1) |

## Skill

`slice-builder/skills/sdf-generation/SKILL.md` bundles:
- SDF format reference (v3/v4 fields, map `essential`, `store`/`default-track`).
- Path→slice table.
- Essential resolution rules (analyze dep SDF → pick slices).
- Prefer rules (literal only, deb preferred).
- Validation rules (sort, yamllint).
- Non-deb slicing methodology (Chisel how-to with deb steps stripped).

Consumed by the **omp agent** inside slice-builder. omp auto-discovers skills
from disk (it inherits `.claude`, `.cursor`, `AGENTS.md`, and `skills/`
layouts), so placing the skill under `slice-builder/skills/sdf-generation/`
and running omp with `--cwd slice-builder/` is sufficient — no `--skill` flag
or in-process loader. sd-tools never loads the skill. It evolves
independently of tool code.

The builder's `agent.py` also emits a `prompts/system.md` base system prompt
that points omp at the skill and constrains its tool surface to
`read,write,search,bash` with the checkout as `--cwd`.

## Testing

Mirrors slupgrader's split:
- **Unit tests** (`tests/unit/`, fast, no LLM, no omp): `archive.py` path
  extraction, `release.py` chisel.yaml parsing, `render.py` sort + quote,
  `validate.py` yamllint/sort/parse, `deps.py` bin-vs-deb detection,
  `prefer.py` conflict scan. Run: `uv run pytest`.
- **Integration tests** (`tests/integration/`, `@slow`, require omp + LLM
  credentials): end-to-end `generate-sdf` against a fixture `.tar.xz` and a
  fixture checkout, asserting the emitted SDF matches the expected shape.
  Gated behind `has_omp()` / `has_llm_credentials()` skip guards, like
  slupgrader's `@slow` marker. Run: `uv run pytest -m slow`.

## Open / future

1. **Path→slice table:** provisional. Needs rules for `/usr/share/man/**`,
   `/usr/share/gocode/pkg/**`, `/usr/include/**`.
2. **Bin-vs-bin prefer:** no default yet. Needs policy if common.
3. **Store name:** hardcoded `bin`. Add `--store` if multiple stores introduced.
4. **Determinism:** agent is non-deterministic. Hybrid approach if
   reproducibility needed.
5. **omp RPC mode:** switch from one-shot `omp -p` per invocation to a
   persistent `omp --mode rpc` session reused across a sd-tools batch, to
   amortise startup and model warm-up.
6. **Extraction to dedicated repo:** if `slice-builder/` outgrows
   `chisel-releases`, lift the directory to its own `canonical/slice-builder`
   repo and have sd-tools clone/pin it (same pattern as `slupgrader` in
   `sd-tools`' `dependencies.lock.yaml`).

