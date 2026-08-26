# AGENTS.md

- Contributor documentation is in [CONTRIBUTING.md](./CONTRIBUTING.md).
- `main` (this branch) is meta-only. It contains reusable CI workflows, CI scripts and their tests, and contributor documentation.
- Every branch named `ubuntu-XX.XX` is one [Chisel](https://github.com/canonical/chisel) release, holding the release manifest (`chisel.yaml`), the Slice Definition Files (SDFs, `slices/`), and their [spread](https://github.com/canonical/spread) tests (`tests/spread/`). SDFs and spread tests are written and modified on a checkout of the target `ubuntu-XX.XX` release branch; `slices/`, `tests/spread/`, and `chisel.yaml` never land on `main`.
- The upstream repository is [`canonical/chisel-releases`](https://github.com/canonical/chisel-releases), but a given clone may be of a fork.
- Workflows under `.github/workflows/` are reusable workflows called by the release branches, so a change merged to `main` takes effect immediately for every release branch.
- CI helper scripts and their test suites live under `.github/scripts/<name>/`.
- YAML is linted with `yamllint`, configured at `.github/yamllint.yaml`.
