# Contributing <!-- omit from toc -->

Thank you for taking the time to contribute to the `chisel-releases` project.
We welcome quality external contributions in the form of
[Pull Requests](https://github.com/canonical/chisel-releases/pulls) or
[Issues](https://github.com/canonical/chisel-releases/issues).

Please note that while we acknowledge that there are many conventions and
styles, we must strive for consistency and thus your contributions are expected
to match the existing codebase, as described by the following guidelines.
Any non-conforming proposals will be subject to immediate rejection.

- [Code of Conduct](#code-of-conduct)
- [Canonical Contributor Licence Agreement](#canonical-contributor-licence-agreement)
- [How to Contribute](#how-to-contribute)
  - [Creating Issues](#creating-issues)
  - [Submitting Code](#submitting-code)
    - [Commit Conventions](#commit-conventions)
    - [Pull Request Etiquette](#pull-request-etiquette)
  - [Slicing Debian Packages](#slicing-debian-packages)

## Code of Conduct

This project and everyone participating in it must follow a [Code of
Conduct](https://ubuntu.com/community/ethos/code-of-conduct).
By participating, you are expected to uphold this code.

## Canonical Contributor Licence Agreement

Before creating a pull request you should sign the [Canonical contributor
license agreement](https://ubuntu.com/legal/contributors).
It is the easiest way for you to give us permission to use your contributions.

## How to Contribute

### Creating Issues

This project's issues can be found
[here](https://github.com/canonical/chisel-releases/issues). Everyone is welcome
to comment and add value to existing issues.

If you spot a problem or have a feature request, and a related issue doesn't
exist yet, then you can open a new issue.

### Submitting Code

Code contributions must be submitted in the form of a [Pull
Request](https://github.com/canonical/chisel-releases/pulls).

#### Commit Conventions

Please format your commits following the [conventional
commit](https://www.conventionalcommits.org/en/v1.0.0/#summary) style.

See below for some examples of commit messages:

```text
feat: add new archive to ubuntu-24.04 release
test: increase the smoke tests' verbosity
fix(pkg-a): add missing file to pkg-a_slice
ci(linter): add CI job for linting YAML files
chore(test): update pip dependencies for tests
docs: add new section 'Foo' to README.md
```

Other common best practices are:

- separate the commit's message subject from the body with a blank line,
- limit the subject line to 50 characters,
- do not capitalize the subject line,
- do not end the subject line with a period,
- use the imperative mood in the subject line,
- wrap the body at 72 characters,
- use the body to explain what and why (instead of how).

#### Pull Request Etiquette

Once you're ready to open a PR, please make sure you abide by the following
rules:

- you should be branching off a release branch and not `main` or any other
development branch,
- use the draft mode if your PR is not yet ready to be reviewed,
- provide good PR descriptions as the project maintainers aren't necessarily
familiar with the packages you are slicing,
- provide proof of testing and testing instructions, when applicable, to help
speed up the review process,
- if you have inter-dependent PRs, make those dependencies explicit in the PRs'
descriptions,
- keep an eye out for CI failures as reviewers will look at your proposal once
all checks are green,
- if possible, use "Labels" to help the maintainers navigate and prioritize their reviews,
- do not force push once you already have review comments,
- when needed, update your PR by merging the latest changes from the target
branch,
- be holistic! I.e. you should avoid proposing multiple
uncorrelated slice definitions in the same PR,
- you can close a review comment if you applied the proposed change. Otherwise,
or when in doubt, you should simply reply and let the reviewers resolve it.

> [!IMPORTANT]
> All PRs must be forward ported! E.g. if opening a PR against
> `ubuntu-24.04`, you must also forward port it to all maintained
> releases at the time of opening the PR.

Please note that in order to get merged, PRs must first be approved at least by
two project maintainers.

### Slicing Debian Packages

If you are slicing Debian packages and thus proposing new slice definitions,
make sure you read the [package slicing guidelines available in the
Chisel documentation](https://documentation.ubuntu.com/chisel/en/latest/how-to/slice-a-package/).


