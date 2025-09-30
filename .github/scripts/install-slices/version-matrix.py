#!/usr/bin/python3

import os
import json

# NOTE: This is a temporary function to determine the ignore flag which we then
#       pass to install-slices.py. We will likely refactor this in the future
#       to be a neater and the logic will be moved away from here.
#       See: https://github.com/canonical/chisel-releases/issues/675
def determine_ignore_flag(ignore: str, chisel_version: str) -> str:
    ignore_flag = ""
    if chisel_version == "main":
        if ignore == "unstable":
            ignore_flag = "--ignore-unstable"
        elif ignore == "unmaintained":
            ignore_flag = "--ignore-unmaintained"
    return ignore_flag

arches, releases = json.loads(os.environ["ARCHES"]), json.loads(os.environ["RELEASES"])
matrix = []
for arch in arches:
    for release in releases:
        for chisel_version in release["chisel-versions"]:
            matrix.append({
                "arch": arch,
                "ref": release["ref"],
                "chisel-version": chisel_version,
                "ignore-flag": determine_ignore_flag(release.get("ignore", ""), chisel_version)
            })

print(json.dumps(matrix))
