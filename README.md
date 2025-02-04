# Chisel Releases <!-- omit from toc -->

*The collection of package slice definitions, for
[Chisel](https://github.com/canonical/chisel).*

- [The Basics](#the-basics)
- [Using a Specific Chisel Release](#using-a-specific-chisel-release)
- [Adding New Slice Definitions](#adding-new-slice-definitions)

## The Basics

This repository is the official source of all package slice definitions that
are supported by [Chisel](https://github.com/canonical/chisel).

Every Chisel release is represented by a Git branch within this repository. At
the moment, the officially supported Chisel releases are:

- [ubuntu-20.04](https://github.com/canonical/chisel-releases/tree/ubuntu-20.04)
\- Focal
- [ubuntu-22.04](https://github.com/canonical/chisel-releases/tree/ubuntu-22.04)
\- Jammy
- [ubuntu-22.10](https://github.com/canonical/chisel-releases/tree/ubuntu-22.10)
\- Kinetic (EOL)
- [ubuntu-23.04](https://github.com/canonical/chisel-releases/tree/ubuntu-23.04)
\- Lunar (EOL)
- [ubuntu-23.10](https://github.com/canonical/chisel-releases/tree/ubuntu-23.10)
\- Mantic (EOL)
- [ubuntu-24.04](https://github.com/canonical/chisel-releases/tree/ubuntu-24.04)
\- Noble
- [ubuntu-24.10](https://github.com/canonical/chisel-releases/tree/ubuntu-24.10)
\- Oracular

In each release branch, you'll find a `chisel.yaml` file that defines the Chisel
release, plus a `slices` folder with all the Slice Definitions Files (SDFs) for
that release.

For more information on the SDFs' YAML schema and how to install slices, please
refer to the
[Chisel documentation](https://documentation.ubuntu.com/chisel/en/latest/).

## Using a Specific Chisel Release

Chisel releases are meant to be used with the `chisel` CLI. Many of the `chisel`
commands have a `--release` optional argument (to know which commands support
this option, please refer to the
[Chisel documentation](https://documentation.ubuntu.com/chisel/en/latest/).

When running a `chisel` command where `--release` is supported,

- **if** `--release` is not given, Chisel will default to the host's Ubuntu
release, mapping it to its corresponding branch in this repository. E.g.: if
running the `chisel` command without `--release` on a Jammy host, Chisel will
automatically default to the `ubuntu-22.04` Chisel release;
- **if** `--release` is an absolute system path, then Chisel will look at the directory tree under that path to find a valid Chisel release (this is
especially useful when you're working with custom Chisel releases and/or
defining new slices);
- **if** `--release` is a string that matches the `ubuntu-##.##` pattern, then
Chisel will use the corresponding Git branch from this repository if it exists.

## Adding New Slice Definitions

We welcome and encourage community contributions! To better understand how to
write and propose new package slice definitions, please read the
[contributing guidelines](./CONTRIBUTING.md).
