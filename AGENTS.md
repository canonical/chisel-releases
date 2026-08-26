# AGENTS.md

The authoritative contributor documentation is [CONTRIBUTING.md](./CONTRIBUTING.md).

## Repository layout

This repository is organised by git branch: `main` (this branch) is meta-only (reusable CI workflows, CI scripts and their tests, and contributor documentation -- there are no slice definitions here), and every branch named `ubuntu-XX.XX` is one [Chisel](https://github.com/canonical/chisel) release, holding the release manifest (`chisel.yaml`), the Slice Definition Files (SDFs, `slices/`), and their [spread](https://github.com/canonical/spread) tests (`tests/spread/`). The upstream repository is [`canonical/chisel-releases`](https://github.com/canonical/chisel-releases), but a given clone may be of a fork.

## Working on `main`

- Workflows under `.github/workflows/` are reusable workflows that are called by the release branches. A change merged to `main` takes effect immediately for every release branch, so treat workflow changes as affecting all branches at once.
- CI helper scripts and their test suites live under `.github/scripts/<name>/`.
- YAML is linted with yamllint, configured at `.github/yamllint.yaml`.
- Never add `slices/` or `chisel.yaml` to `main`. If writing or modifying slice definitions or their spread tests, work on a checkout of the target `ubuntu-XX.XX` release branch.
