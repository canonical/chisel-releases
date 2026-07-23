# slice-builder

`slice-builder` generates [Chisel](https://canonical-chisel--72.com.readthedocs.build/72/)
slice definition files (SDFs) for **superdistro bin** packages (`.tar.xz` archives produced by
`bincraft pack`). Bin packages are not Debian debs, so the standard deb-slicing workflow does
not apply; this tool wraps an `omp` (oh-my-pi) agent — guided by the `sdf-generation` skill — to
classify archive paths into slices, resolve `essential` dependencies, and emit a validated SDF.

## Install

The tool is managed with [`uv`](https://docs.astral.sh/uv/). No install step is required; `uv`
resolves dependencies from `pyproject.toml` into an ephemeral environment:

```bash
uv run slice-builder --help
```

## Usage

```bash
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
| --- | --- |
| `--bin-archive` | `.tar.xz` archive from `bincraft pack`. |
| `--base` | Ubuntu base (e.g. `26.04`). Derives branch `ubuntu-26.04`, fetched shallow. |
| `--package` | Bin's SD name, bare (e.g. `curl`). |
| `--track` | Bin's track (e.g. `v1.2.3`). Always YAML-quoted in output. |
| `--dependencies` | Comma-separated `sd_name` values (may be empty). |
| `--sdf-lookup-dir` | Read-only cache of already-generated bin SDFs, overlaid onto the checkout. |
| `--output` | Full output path. |
| `--omp` | (opt) Path to `omp` binary; default `omp` on PATH. |
| `--omp-model` | (opt) Model selector for omp. |
| `--retries` | (opt) Max agent retries on validation failure. Default 3. |

## Exit codes

- `0` success
- `1` SDF generation failed (agent/ validation failure)
- `2` input/config error (bad archive, missing dep SDF, bad args, `omp` not on PATH, output exists)

## Development

```bash
just test          # unit tests
just test-integration  # @slow, requires omp + LLM credentials
just fmt           # format
just lint          # ruff check
```

## Layout

Everything lives under `slice-builder/` so the directory can be lifted into its own repository
without rework. The `sdf-generation` skill (`skills/sdf-generation/SKILL.md`) evolves
independently of the tool code.
