# SDF Generation Skill

This skill guides an agent in generating a Chisel **Slice Definition File (SDF)** for a
`bin` package, given a list of archive paths, dependency SDFs, and a release
prefix.

The agent focuses on **path classification** and **essential dependency resolution**. The
`prefer` computation, sorting, and yamllint validation are handled deterministically by the
`slice-builder` tool after the agent runs.

## SDF format reference (v3/v4)

### Top-level fields

| Field          | Type   | Required | Notes |
| -------------- | ------ | -------- | ----- |
| `package`      | string | Required | Bare package name; must match the YAML file basename. For bin packages this is the bare SD name (e.g. `curl`), NOT the prefixed identifier. |
| `store`        | string | Optional (>= v3) | For bin packages, set to `bin`. Mutually exclusive with `archive`. |
| `default-track`| string | Required when `store` is set (>= v3) | The track (e.g. `v1.2.3`). MUST always be YAML double-quoted so values like `0.1` are not parsed as floats. |
| `essential`    | object | Optional | A map of slice full-names to their essential-specific properties. Emit each entry as a null-valued key, e.g. `bin-curl_copyright:` (NOT `bin-curl_copyright: {}`). |
| `slices`       | object | Required | Map of slice name -> slice object. |

### Slice-level fields

| Field                        | Type   | Required | Notes |
| ---------------------------- | ------ | -------- | ----- |
| `slices.<name>`              | object | -        | A slice object. Slice names: lowercase `a-z`, digits `0-9`, minus `-`; at least 3 chars; must start with a letter. |
| `slices.<name>.essential`    | object | Optional (v3/v4) | Same map format as top-level `essential`; slice full-names (e.g. `libc6_libs`). |
| `slices.<name>.contents`     | object | Optional | Map of absolute path -> path properties (or null for a bare path). Paths MUST be absolute (start with `/`). |
| `slices.<name>.contents.<path>.prefer` | string | Optional (>= v2) | Resolves a path conflict across packages. Value must be the name of an existing package. CANNOT be used with glob paths. |

### Path globs

Paths may contain globs:

- `?` matches any one character, except `/`.
- `*` matches zero or more characters, except `/`.
- `**` matches zero or more characters, including `/`.

### Example SDF (bin package)

```yaml
package: curl
store: bin
default-track: "0.1"

essential:
  bin-curl_copyright:

slices:
  bins:
    contents:
      /usr/bin/curl-bin:

  copyright:
    contents:
      /usr/share/doc/curl-bin/copyright:
```

## Path -> slice classification

| Path pattern | Slice |
| --- | --- |
| `/usr/bin/**`, `/bin/**` | `bins` |
| `/usr/lib/**`, `/lib/**` | `libs` |
| `/etc/**` | `config` |
| `/usr/share/doc/**/copyright` | `copyright` |
| `/usr/share/gocode/src/**` | `src` |

Rules:

- Only emit slices that contain at least one path.
- `copyright` slice: only created if the archive actually contains a copyright file. If created,
  add `bin-<package>_copyright` to the top-level `essential` map.
- Unmatched paths: the agent MUST NOT silently drop them. Flag them for human review (emit a
  comment or a dedicated slice and note them in the response text).
- The table is provisional; the agent may deviate with justification, but must never drop paths.

## Essential resolution

For each dependency:

1. The dependency's SDF is provided in the prompt. Determine if it is a **bin dep** (its SDF has
   `store: bin`) or a **deb dep** (no `store` field).
2. For bin deps, slice references use the release's bin prefix (e.g. `bin-<dep>_<slice>`). For
   deb deps, references use the bare name (`<dep>_<slice>`).
3. Read the dep's slices and contents, and select the slice(s) that provide what the current bin
   needs (e.g. `libs` for a library, `bins` for a binary). This is a judgment call.
4. Emit selected refs in the v3/v4 map format under the appropriate slice's `essential` (usually
   the `bins` slice's `essential`):

   ```yaml
   slices:
     bins:
       essential:
         libc6_libs:
         bin-go-github-some-dep_bins:
   ```

5. If a dependency SDF is missing, that is an error in the builder (not the agent's concern); the
   builder will not invoke the agent with unresolved deps.

## Prefer rules

The `prefer` computation is performed **deterministically by the builder** after the agent runs;
the agent does not need to compute `prefer` itself. The rules below describe what the builder
does, for the agent's awareness:

- Collect all LITERAL (non-glob) paths in the generated SDF's contents.
- For each literal path that also appears in another package's SDF in the release checkout:
  - **Bin vs deb conflict:** emit `prefer: <deb-package-name>` on the bin's path (deb wins by
    default).
  - **Bin vs bin conflict:** flag for human review; no default resolution.
- `prefer` is FORBIDDEN on glob paths.
- The `prefer` value is the unique package identifier of the preferred package (bare name for
  debs, `bin-<name>` for bins).

## Validation rules

The builder validates the SDF in two passes. The agent is only retried for **semantic** failures
(pass 1); style and ordering are fixed deterministically by the builder (pass 2), so the agent
need not optimise for them.

**Pass 1 — semantic (agent is retried on failure):**

- The SDF must be valid YAML that parses into the expected structure.
- Required fields: `package`, `store`, `default-track`, `slices`.
- `store` must be `bin` for bin packages.
- All content paths must be absolute (start with `/`).
- Slice names: lowercase `a-z`, digits `0-9`, minus `-`; at least 3 chars; start with a letter.

**Pass 2 — style (builder fixes via `render()`, agent is NOT retried):**

- `contents` paths and `essential` entries are byte-sorted (`LC_COLLATE=C`, lexicographic by
  UTF-8 bytes) by the builder.
- The SDF is re-dumped to pass yamllint (2-space indentation, 100-char line limit, no
  document-start `---` marker, block style only, no flow style, no anchors/`!!` tags).
- `default-track` is re-quoted by the builder's dumper.

The agent should still aim for compliant output, but it should focus its effort on correct
path classification and essential resolution, not on YAML formatting.

## Non-deb slicing methodology

Bin packages are not Debian debs, so there is no `dpkg -c` / apt download step. The archive
(`.tar.xz`) is extracted to a directory by the builder and its member paths are classified into
slices using the table above. The agent has access to the extracted directory (its path is given
in the task) and should inspect file types and contents with its `read`/`bash` tools (e.g.
`file`, `cat`) when the path name alone is ambiguous — for example, a `/usr/lib/` entry could be
a shared library, a static archive, or data, and the correct slice depends on the file type.
Essential dependencies are resolved from previously-generated bin SDFs and Ubuntu archive (deb)
SDFs in the checkout.
