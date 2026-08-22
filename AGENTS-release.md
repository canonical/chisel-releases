# AGENTS-release.md

Guidance for coding agents working on a Chisel release branch (`ubuntu-XX.XX`) of this repository. This file lives on the `main` branch so there exists only one source of truth; each release branch carries a short `AGENTS.md` pointing here.

Guidance for contributors can be found at [CONTRIBUTING.md](./CONTRIBUTING.md) on `main`. ALWAYS read it.

## Repository layout

This repository is organised by git branch: `main` is meta-only (reusable CI workflows, CI scripts and their tests, and contributor documentation -- there are no slice definitions there), and every branch named `ubuntu-XX.XX` is one [Chisel](https://github.com/canonical/chisel) release, holding the release manifest (`chisel.yaml`), the Slice Definition Files (SDFs, `slices/`), and their [spread](https://github.com/canonical/spread) tests (`tests/spread/`). The upstream repository is [`canonical/chisel-releases`](https://github.com/canonical/chisel-releases), but a given clone may be of a fork.

In full, each release branch holds:

```
chisel.yaml                                  # release manifest
slices/<package>.yaml                        # one Slice Definition File (SDF) per package
spread.yaml                                  # spread test project config
tests/spread/integration/<package>/task.yaml # per-package integration test
tests/spread/lib/                            # shared test helpers
```

### Release status

A branch is in one of three states, and `maintenance:` in its own `chisel.yaml` says which:

```bash
today=$(date -u +%F)
if   [[ $(yq '.maintenance.standard' chisel.yaml)      > $today ]]; then echo "devel"
elif [[ $(yq '.maintenance."end-of-life"' chisel.yaml) < $today ]]; then echo "EOL"
else                                                                     echo "maintained"
fi
```

- `devel` -- While `maintenance.standard` is still in the future the release has not shipped, so package versions and even package names can change. `chisel cut` refuses to run without `--ignore=unstable`. The "Removed slices" CI check skips pull requests against this branch entirely since this is the only time we are allowed to remove slices / SDFs.
- `maintained` -- Once it has shipped and before `maintenance.end-of-life`. This is the normal target for work.
- `eol` -- Past `maintenance.end-of-life`. These branches are frozen. Do not propose changes. `chisel cut` needs `--ignore=unmaintained` to read it at all.

See [README](./README.md) on `main` for the live branch list. The dates in `maintenance:` mirror Ubuntu's own -- `standard` is the release date and `end-of-life` the EOL date, both from [distro-info-data](https://git.launchpad.net/ubuntu/+source/distro-info-data/tree/ubuntu.csv):

```bash
ubuntu-distro-info --series=<codename> --eol  # from the distro-info package
# or
curl -fsSL https://git.launchpad.net/ubuntu/+source/distro-info-data/plain/ubuntu.csv
```

## Format versions

ALWAYS read `format:` in `chisel.yaml` since it determines the available SDF features. The [`format` reference](https://documentation.ubuntu.com/chisel/en/latest/reference/chisel-releases/chisel.yaml/#chisel-yaml-format-spec-format) documents what each version changes, and its [compatibility matrix](https://documentation.ubuntu.com/chisel/en/latest/reference/chisel-releases/chisel.yaml/#chisel-yaml-format-spec-compatibility-matrix) maps every release branch to its format and the minimum chisel version that understands it; the per-field rules are in the [slice definitions reference](https://documentation.ubuntu.com/chisel/en/latest/reference/chisel-releases/slice-definitions/). In short:

- The map form of `essential:` is v3. On a v3 branch `essential:` must be a map; the list form is a parse error.
- On v1/v2 branches `essential:` is a list, and arch-gated dependencies use the parallel `v3-essential:` map.
- `prefer:` is v2+.
- `hint:` is v3.

## Archive reference

A slice definition describes files that exist in a real `.deb`. NEVER write a content path from memory or by analogy to another package. ALWAYS read the package contents first, and read the one built for the branch you are targeting, since contents may differ between Ubuntu releases. ALWAYS read the contents of the package on all the available architectures.

First pull the package into a temporary directory. Choose the highest priority archive which carries the package:

```bash
pkg=bash; arch=s390x
base=http://ports.ubuntu.com/ubuntu-ports   # amd64 and i386: http://archive.ubuntu.com/ubuntu

# every archive/suite/component chisel would consult, highest priority first, pro archives skipped
yq '.archives | to_entries | sort_by(.value.priority // 0) | reverse | map(select(.value.pro == null))
    | .[] as $a | $a.value.suites[] as $s | $a.value.components[] as $c
    | $a.key + " " + $s + " " + $c' chisel.yaml |
while read -r archive s comp; do
  curl -fsSL "$base/dists/$s/$comp/binary-$arch/Packages.gz" 2>/dev/null | gunzip 2>/dev/null |
    awk -v p="$pkg" -v tag="$archive $s/$comp" '
      $1=="Package:" {c=$2} $1=="Version:" && c==p {v=$2}
      $1=="Filename:" && c==p {print tag, v, $2; exit}'
done
```

Archives print in the order chisel considers them, so take the highest version under the first archive listed, then fetch it:

```bash
curl -fsSL "$base/<filename from above>" -o "$pkg.deb"
```

Once you have the `.deb` you can inspect it with:

```bash
dpkg-deb --contents <package>_*.deb            # every file the package ships
dpkg-deb --info <package>_*.deb                # all control metadata
dpkg-deb --info <package>_*.deb postinst       # contents of a control file
dpkg-deb --fsys-tarfile <package>_*.deb | tar -xO ./<path>   # read a shipped file in place
```

Chisel never runs any control files, specifically not the `postinst` script. Any relevant actions of the `postinst` script have to be expressed declaratively in the SDF instead. A symlink a `postinst` creates becomes a [`symlink:`](https://documentation.ubuntu.com/chisel/en/latest/reference/chisel-releases/slice-definitions/#slice-definitions-format-slices-contents-symlink) entry under `contents:`; file content it generates or merges is reproduced in a [`mutate:`](https://documentation.ubuntu.com/chisel/en/latest/reference/chisel-releases/slice-definitions/#slice-definitions-format-slices-mutate) script.

## Slicing a package

The canonical workflow for slicing a package is the [Slice a package](https://documentation.ubuntu.com/chisel/en/latest/how-to/slice-a-package/) how-to. Additional rules are:

- Paths under `contents:` MUST be sorted in byte-wise ASCII order within each slice (`LC_ALL=C sort`).
- File-level `essential:` MUST come right after `package:`.
- The `copyright` slice MUST be present in each SDF and MUST be the last slice.
- Architecture names in `arch:` fields are Debian names only: `amd64`, `arm64`, `armhf`, `i386`, `ppc64el`, `riscv64`, `s390x`. Never `x86_64` or `aarch64`.
- Dependencies come from the package's `Depends:` field only -- never `Recommends:` or `Suggests:`. NOT every deb dependency must appear as an `essential:` entry -- the slice `essential:`s are the dependencies only of its `contents:`, not the entire package. `essential:` entries pull in dependencies transitively. Hence, the transitive deps SHOULD NOT be listed in slice dependencies UNLESS they are also its direct dependencies. Do not add dependencies without a demonstrated need.
- Published slices are append-only: removing an SDF, a slice, or a content path from a maintained release is a regression. Regressions MUST NOT happen. Only a devel release can have removals.
- Slices SHOULD be use-case agnostic: name and describe what a slice ships, not the application it was sliced for.

### Slice naming

Use the established slice names. The two groupings below are the ones chisel documents in [Slice design approaches](https://documentation.ubuntu.com/chisel/en/latest/explanation/slice-design-approaches/); pick whichever suits the package.

By function, in increasing size:

| Name | Contents |
|------|----------|
| `minimal` | Bare essentials to make the software run; usually only useful as a base to build on |
| `core` | Slim but complete enough for the majority of simple use cases |
| `standard` | A normal installation: full operation, runtime libraries and utilities, no debug or dev tooling |
| `dev` | `standard` plus debugging and development utilities; close to full size, for development rather than production |

By type of content:

| Name | Contents |
|------|----------|
| `bins` | Executables |
| `libs` | Shared libraries |
| `scripts` | Non-binary executables |
| `copyright` | deb copyright file |
| `config` | Configuration files; large slices can be split into `<purpose>-config` |
| `data` | Static data |
| `fonts` | Font files, in `fonts-*` packages |
| `headers` | `/usr/include/...` |
| `modules` | Loadable modules or plugins |

Beyond these, a slice may be scoped and named after the functionality it provides, and some package families carry their own additional names, e.g. `jars` across openjdk. When slicing a package you SHOULD find and follow the family conventions. Do not invent a new name where an existing one fits.

### What not to include

Chisel slices are targeted towards creating minimal root filesystems. Most debs ship files a minimal root filesystem never needs. NEVER slice these UNLESS a concrete runtime need is proven:

- man pages (`/usr/share/man/`)
- shell completions (bash-completion, fish, zsh)
- documentation and changelogs (`/usr/share/doc/**`) EXCEPT the legal files: `copyright` always, plus upstream `NOTICE` / `LICENSE` / `COPYING` / `AUTHORS` where the package carries them for licence compliance
- `doc-base` and `lintian` packaging metadata
- examples

### Content entry options

A bare path extracts that path from the deb. The overwhelming majority of entries are bare paths, but they can also carry additional options, e.g. `copy:`, `make:`, `mode:`, `text:`, `symlink:`, `arch:`, `mutable:`, `until:`, or `prefer:`. Read about the additional path options in [`slices.<name>.contents`](https://documentation.ubuntu.com/chisel/en/latest/reference/chisel-releases/slice-definitions/#slice-definitions-format-slices-contents).

Paths may use wildcards: `?` matches one character except `/`, `*` matches any run of characters except `/`, and `**` matches across `/`. Prefer `*`. Use `**` only where a whole subtree genuinely has to be taken wholesale, because it crosses directory boundaries and will silently absorb whatever a later version of the package adds beneath that point.

`mutate:` starlark scripts run once after every slice in the install set has been placed -- see [`slices.<name>.mutate`](https://documentation.ubuntu.com/chisel/en/latest/reference/chisel-releases/slice-definitions/#slice-definitions-format-slices-mutate). Use one to merge or rewrite files the package already ships, never to synthesise a file that should have come from the deb.

### Style details

- Multiarch library directories use the `*-linux-*` glob, not explicit triplets. The exception is cross-toolchain packages (e.g. `binutils-<triplet>`, `gcc-N-<triplet>`, `cpp-N-<triplet>`, and the base `binutils`/`gcc`/`cpp` SDFs), where the triplet names the compilation target rather than a multiarch directory and is spelled out.
- The binary package name decides how much of a library version is written out. Whatever version the name pins is kept, and a single `*` globs everything after it. E.g. in package `libzstd1` the major version is guaranteed so its path is `libzstd.so.1*:`, which matches `libzstd.so.1.5.7` today and will match `libzstd.so.1.6` after a point release. Never glob a component pinned by the package name.
- Do not add explicit `symlink:` entries for symlinks the deb already ships; annotate manually-created ones with a comment.
- `hint:` is a noun phrase, not a sentence: `hint: System log viewer`, not `hint: Views system logs`. It must be no longer than 40 characters and contain only printable characters.

## Testing

Each slice MUST be installable by chisel, and its functionality SHOULD be exercised by the spread tests. A spread test installs a slice into a minimal rootfs and chroots into it to exercise it. The spread test entry point for each package lives at `tests/spread/integration/<package>/task.yaml` where `<package>` MUST match the name of the SDF.

Conventions:

- ALWAYS use the `install-slices` helper (on `PATH` in spread tasks): `rootfs="$(install-slices <pkg>_<slice> ...)"`. It appends `base-files_chisel` slice which ensures chisel generates a manifest in the target rootfs.
- One fresh root filesystem per test; a reused rootfs lets leftover slices mask a missing dependency.
- A test MUST exercise ALL shipped binaries and scripts. At bare minimum every binary/script ought to be run with `--help` OR `--version` OR `--invalid-flag` OR otherwise, to check all the linked libraries / imports are present in the cut rootfs.
- A test SHOULD exercise shipped binaries / scripts with functional checks. This is especially true for applications.
- A cut rootfs in the tests SHOULD only contain the slice under test. If additional slices are cut at test time, they could mask defects in the slice under test. Note that the `base-files_chisel` added by `install-slices` is fine and does not pollute the tests.
- Tests are hermetic: generate inputs inline, no apt-installed extras, bounded waits. Only packages whose purpose is the network path (e.g. CA certificates, TLS clients) may contact one stable, well-known endpoint.
- Slices which are exempt from functionality tests are those whose functionality is purely transitive, for example `libs` and `data` slices.

A sliced root filesystem is minimal, so a test that chroots into it usually has to set it up first:

| Need | Pattern |
|------|---------|
| DNS | `cp /etc/resolv.conf "${rootfs}/etc/"` |
| `/dev/null` | `mkdir -p "${rootfs}/dev" && touch "${rootfs}/dev/null"` |
| `/dev/random`, `/dev/urandom` | `head -c 10000 /dev/urandom > "${rootfs}/dev/random"`, same for `urandom` |
| `/bin/sh` | `ln "${rootfs}/bin/bash" "${rootfs}/bin/sh"`, or whichever shell the slice ships |
| `/proc`, `/sys`, `/dev`, `/tmp` | `mount --bind /proc "${rootfs}/proc"` |

Only set up the parts of the rootfs needed for execution of the test. Avoid `mount` if possible. If using `mount` ALWAYS `unmount` cleanup in `trap`, e.g. `trap 'umount -l "${rootfs}/proc" || true' EXIT` immediately after the mount, so a failing test still unmounts. Guard every command in a trap with `|| true`: cleanup runs on the failure path too, and a cleanup that fails there replaces the real error with its own.
