# AGENTS.md

## Repository rules

- **BRANCH STRUCTURE:**
   - `main` is meta-only (reusable CI workflows, CI scripts and their tests, and docs) - there are no slice definitions in `main`.
   - `ubuntu-XX.XX` branches (like this one) hold [Chisel](https://github.com/canonical/chisel) releases (`chisel.yaml`, Slice Definition Files (aka SDFs) under `slices/`, [Spread](https://github.com/canonical/spread) tests under `tests/spread/`).
   - Write and modify SDFs and Spread tests on a checkout of the target `ubuntu-XX.XX` release branch. `slices/`, `tests/spread/`, and `chisel.yaml` never land on `main`.

## Working on `ubuntu-XX.XX`

### CI / Workflow rules

- **THIN CALLERS:** the workflows under `.github/workflows/` -- `ci.yaml` and `ci-pr-target.yaml` -- are thin callers of the reusable workflows on `main`, so CI logic changes belong on `main`, not here.
- **SPREAD:** `spread.yaml` is the Spread project configuration.
- **LINTING:** YAML is linted with `yamllint`, configured with `.github/yamllint.yaml` from `main`.
