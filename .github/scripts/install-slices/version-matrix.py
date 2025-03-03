#!/usr/bin/python3

import os
import json

arches, releases = json.loads(os.environ["ARCHES"]), json.loads(os.environ["RELEASES"])
matrix = []
for arch in arches:
    for release in releases:
        for chisel_version in release["chisel-versions"]:
            matrix.append({
                "arch": arch,
                "ref": release["ref"],
                "chisel-version": chisel_version,
            })

print(json.dumps(matrix))
