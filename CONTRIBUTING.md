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
    - [1. What package are you slicing?](#1-what-package-are-you-slicing)
    - [2. Which Ubuntu release(s) are you targeting?](#2-which-ubuntu-releases-are-you-targeting)
    - [3. Does a Slice Definitions File (SDF) exist already for that package?](#3-does-a-slice-definitions-file-sdf-exist-already-for-that-package)
    - [4. What other packages do you need to slice?](#4-what-other-packages-do-you-need-to-slice)
    - [5. Get familiar with the packages](#5-get-familiar-with-the-packages)
      - [5.1 What architectures is it available for?](#51-what-architectures-is-it-available-for)
      - [5.2 What are its contents?](#52-what-are-its-contents)
      - [5.3 Does it have maintainer scripts?](#53-does-it-have-maintainer-scripts)
      - [5.4 What does it do?](#54-what-does-it-do)
    - [6. Build/edit the Slice Definitions File(s)](#6-buildedit-the-slice-definitions-files)
    - [7. Test your slices before opening a PR](#7-test-your-slices-before-opening-a-pr)
    - [8. Open the PR(s)](#8-open-the-prs)

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
- you can close a review comment if you applied the proposed change. Otherwise,
or when in doubt, you should simply reply and let the reviewers resolve it.

Please note that in order to get merged, PRs must first be approved at least by
two project maintainers.

### Slicing Debian Packages

If you are slicing Debian packages and thus proposing new slice definitions,
make sure you read the following guidelines. They describe the typical process
for slicing Debian packages, while also highlighting our expectations with
respect to the design of a proper Slice Definitions File.

#### 1. What package are you slicing?

**Pull Requests must be holistic!** I.e. you should avoid proposing multiple
uncorrelated slice definitions in the same Pull Request.

So step 1 is to find the target Debian package you'll be slicing! This is as
simple as thinking about the corresponding `apt install` command. For example,
if your installation command looks like `apt install <pkg-a>`, then `pkg-a` is
your target Debian package and the one your Pull Request shall propose the
slice definitions for.

#### 2. Which Ubuntu release(s) are you targeting?

If you're slicing `pkg-a` for Ubuntu 24.04, then your Pull Request must be
created against this repository's `ubuntu-24.04` branch.

Why is this important? To enforce consistency across the different chisel
releases, **every slice definition that is proposed for a given chisel release
MUST also be proposed for all newer and still supported chisel releases**. For
example, in Dec 2023, if you were proposing new slice definitions for
`ubuntu-22.04`, then you had to ensure they also existed (or were being
proposed) for `ubuntu-23.04`, `ubuntu-23.10` and `ubuntu-24.04`, if applicable.

***Tip**: you can check which Ubuntu releases are still supported via `ubuntu-distro-info --supported -r`*

#### 3. Does a Slice Definitions File (SDF) exist already for that package?

Check if a YAML file with that package's name exists already under the `slices`
folder (e.g. `slices/pkg-a.yaml`).

If it does, then you'll be editing it. Otherwise, you must create it.

#### 4. What other packages do you need to slice?

Debian packages can have dependencies, so more often than not, you'll need to
slice more than one package.

Start by listing which packages you'll need to slice, and remember to
double-check if an SDF already exists for those packages too.

***Tip**: work your way from your target package (e.g. `pkg-a`) to its
dependencies and its dependencies' dependencies...and so on. For example,
`pkg-a` may depend on `pkg-b`, while the latter may depend on `pkg-c` and
`pkg-d`. So those will be the packages you must consider for slicing. Here are some useful references from where you can check a package's dependencies:*

- *run `apt show <pkgName>`;*
- *go to `https://packages.ubuntu.com/<release-adjective>/<pkgName>`*

#### 5. Get familiar with the packages

While you don't need to be a maintainer or an expert in order to slice a Debian
package, you do need to understand the packages' composition and the
functionality they offer.

##### 5.1 What architectures is it available for?

Note that in some occasions, a package might have architecture-specific
contents, which means your slice definitions must include the `{arch: <arch>}`
content path property.

***Tip**: the fastest way to check which architectures a package is available
for is to simply look it up at
`https://packages.ubuntu.com/<release-adjective>/<pkgName>`.*

##### 5.2 What are its contents?

You need to know the contents of the package in order to define the contents
of its slices.

***Tip**: there are multiple ways to look at a package's contents. Here are a
few:*

- *`apt download <pkgName>:<arch>; dpkg-deb -c <pkgName>_*<arch>.deb`*, or
- *via `<https://packages.ubuntu.com/<release-adjective>/<arch>/<pkgName>/filelist>`*.

##### 5.3 Does it have maintainer scripts?

The functionally relevant parts of the package's maintainer scripts must be
reflected by mutation scripts in your slice definitions.

***Tip**: the best way to explore a package's maintainer scripts is to extract
control information from its Deb. E.g.
`apt download <pkgName>; dpkg-deb -e <pkgName>_.deb control-info`. Make sure
you pay special attention to the `preinst` _and `postinst` scripts if _ exist.*

##### 5.4 What does it do?

This is important to know as it will dictate how your
slices should be designed. To make slicing a future-proof, sustainable and
intuitive experience, we must ensure:

1. the slice **naming convention is consistent** across packages and releases.
E.g. many packages deliver configuration files, and these are commonly
arranged in their own package slice. We must **AVOID** having different SDFs
defining configuration slices with different names (e.g. `conf` vs `config` vs
`configuration`...);
1. the slice name must **convey the functionality it delivers**! As a rule of
thumb:
    - if you're slicing a library package (e.g. `libc6`), it is acceptable to
      define the slice names after the *type* of files it delivers. For example `libs` or `config`;
    - if you're slicing an application package, then you should define its
      slices based on the functionality they deliver. For example:
      - a `core` slice for delivering the minimal amount of contents that make
        the package functional, or
      - a `debug` slice for delivering specific libraries or utilities for
        application debugging, or
      - a `crypto` slice for adding optional modules for cryptographic services,
        and so on.

***Tip**: here's an [example](https://github.com/canonical/chisel-releases/blob/ubuntu-20.04/slices/libstdc%2B%2B6.yaml) of an SDF whose slice name is driven by
the **type** of content it delivers, and here's another
[example](https://github.com/canonical/chisel-releases/blob/ubuntu-20.04/slices/libpython3.8-stdlib.yaml)
of an SDF whose slices are designed according to the **functionality** they
deliver*

#### 6. Build/edit the Slice Definitions File(s)

Once you know all the above, you have everything you need to write your own
slice definitions. When writing, here are a few best practices we recommend:

- consider readability, so keep a nice and consistent YAML formatting style;
- provide additional information via comments, whether it is to justify a
design decision or to help clarify the functionality being delivered by a slice;
- use logical sorting for your slices. Sometimes that will result in an
alphabetically ordered SDF, some other times it will result in an SDF where the
topmost slices are the most relevant ones;
- do **NOT** abuse globs! It can be tempting to simply define your slice's
contents with something like `/usr/lib/**`. However, such patterns are too
generic and considered a bad practice, as they have the potential to create
conflicts between slice definitions files;
  - ***Tip**: when pondering about the use of a glob, consider the following
  list of acceptable usages:*
    - *to abstract the architecture name within the path. E.g.:
    `/a/*-b/c` instead of `/a/x86_64-a/c`;*
    - *to simplify application-specific paths. E.g.:
    `/a/appX/module/**` instead of `['/a/appX/module/foo',
    '/a/appX/module/bar/baz', ...]`;*
    - *to deal with upstream version updates. E.g.: `/a/b/lib.so.*` instead of
    `/a/b/lib.so.1`, since an upstream package update could potentially bump
    this version and break the slice definition.*

#### 7. Test your slices before opening a PR

Apart from asserting your slice definitions' formatting, you must also test them
before opening a Pull Request.

Every Chisel release supports the functional testing for slices via
[Spread](https://github.com/snapcore/spread).

**We expect tests to be provided for every slice**, so please ensure you include
those in your PRs.

Here's how you can create and run tests for your slice definitions:

1. under `tests/spread/integration/`, make sure at least one folder matching the
package name you're slicing, exists,
1. inside that folder you must create a `task.yaml` file. This is where you'll
write all the tests for your slide definitions. Please follow the structure from
existing examples, providing at least the `summary` and `execute` fields inside
`task.yaml` (for other possible fields, please check the
[Spread docs](https://github.com/snapcore/spread)),
   1. in `test/spread/lib/` you'll also find a set of helper functions that you
  can call from within your `task.yaml` execution script,
1. once your test is ready, ensure you have Spread installed (we recommend installing it from source with
`go install github.com/snapcore/spread/cmd/spread@latest`, but there's also a
[Spread snap](https://snapcraft.io/spread)) and also ensure you install the
necessary requirements to run the tests locally:
    - with Docker:
      - Docker: you can install it via the [Snap Store](https://snapcraft.io/docker) or
      by following the [official instructions](https://docs.docker.com/engine/install/)
      - QEMU: if testing for multiple architectures, you'll need to install these
      packages: `sudo apt-get install qemu binfmt-support qemu-user-static`

      or
    - with LXD:
      - LXD: [install and configure LXD](https://canonical.com/lxd/install),
1. from the repository's root directory, you can now run

    ```bash
    spread lxd:tests/spread/integration/<pkgA> lxd:tests/spread/integration/<pkgB> ...
    ```

    for running the tests for your slices. Additionally, you can also:
    - replace `lxd` with `docker` to run the tests on all supported
    architectures (NOTE: the `docker` backend might be unable to run tests that
    perform privileged operations);
    - run `spread docker:ubuntu-22.04-amd64` for orchestrating **all** the tests
    (not just yours) with Docker, for amd64 only. 

#### 8. Open the PR(s)

Once you have your new slice definitions and you have tested them, you're ready
to propose them upstream. When opening a
[Pull Request](https://github.com/canonical/chisel-releases/pulls), consider
the above [Pull Request Etiquette](#pull-request-etiquette) in order to make
for a more efficient review process.
