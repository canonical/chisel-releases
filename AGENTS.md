# AGENTS.md

- Contributor documentation is in [CONTRIBUTING.md](https://github.com/canonical/chisel-releases/blob/main/CONTRIBUTING.md) on `main`.
- `main` is meta-only. It contains reusable CI workflows, CI scripts and their tests, and contributor documentation.
- Every branch named `ubuntu-XX.XX` (like this one) is one [Chisel](https://github.com/canonical/chisel) release, holding the release manifest (`chisel.yaml`), the Slice Definition Files (SDFs, `slices/`), and their [spread](https://github.com/canonical/spread) tests (`tests/spread/`). SDFs and spread tests are written and modified on a checkout of the target `ubuntu-XX.XX` release branch; `slices/`, `tests/spread/`, and `chisel.yaml` never land on `main`.
- The upstream repository is [`canonical/chisel-releases`](https://github.com/canonical/chisel-releases), but this clone may be of a fork.
- The workflow under `.github/workflows/`, `ci.yaml`, is a thin caller of the reusable workflows on `main`.
- YAML is linted with `yamllint`, configured with `.github/yamllint.yaml` from `main`.
- `essential` and `contents` keys of every slice are sorted with `LC_ALL=C sort`.
- A slice added to one release usually needs forward porting to any later *maintained* `ubuntu-XX.XX` releases.
- `spread.yaml` is the spread project configuration.
