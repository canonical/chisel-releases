"""Integration test utility for python3.14-minimal.

This script tests that the modules from python3.14-minimal are importable.
"""

from __future__ import annotations

import importlib
import pathlib

ROOT_PATH = pathlib.Path("/usr/lib/python3.14")
MODULES_NOT_IMPORTABLE = (
    # Encodings that require shared objects from stdlib package
    #  - _codecs_cn.*.so
    "encodings.gb18030",
    "encodings.gb2312",
    "encodings.gbk",
    "encodings.hz",
    #  - _codecs_hk.*.so
    "encodings.big5hkscs",
    #  - _codecs_jp.*.so
    "encodings.cp932",
    "encodings.euc_jis_2004",
    "encodings.euc_jisx0213",
    "encodings.euc_jp",
    "encodings.shift_jis",
    "encodings.shift_jis_2004",
    "encodings.shift_jisx0213",
    #  - _codecs_kr.*.so
    "encodings.cp949",
    "encodings.euc_kr",
    "encodings.johab",
    #  - _codecs_iso2022.*.so
    "encodings.iso2022_jp",
    "encodings.iso2022_jp_1",
    "encodings.iso2022_jp_2",
    "encodings.iso2022_jp_3",
    "encodings.iso2022_jp_2004",
    "encodings.iso2022_jp_ext",
    "encodings.iso2022_kr",
    #  - _codecs_tw.*.so
    "encodings.big5",
    "encodings.cp950",
    # Encodings that require other miscellaneous stdlib items
    "encodings.bz2_codec",  # Requires bz2 from stdlib package
    "encodings.mbcs",  # Requires codecs.mbcs_encode
    "encodings.oem",  # Requires codecs.oem_encode
    "getopt",  # https://bugs.launchpad.net/ubuntu/+source/python3.14/+bug/2127899
    # Needs shutil, blocked by https://bugs.launchpad.net/ubuntu/+source/python3.14/+bug/2127898
    "importlib.metadata",
    "importlib.metadata._adapters",
    "importlib.metadata._collections",
    "importlib.metadata._functools",
    "importlib.metadata._itertools",
    "importlib.metadata._meta",
    "importlib.metadata._text",
    "importlib.metadata.diagnose",
    "importlib.resources",
    "importlib.resources._adapters",
    "importlib.resources._common",
    "importlib.resources._functional",
    "importlib.resources._itertools",
    "importlib.resources.abc",
    "importlib.resources.readers",
    "importlib.resources.simple",
    "importlib.readers",
    "importlib.simple",
    "tempfile",
    "urllib.error",
    "urllib.response",
    "urllib.robotparser",
    "zipfile",  # https://bugs.launchpad.net/ubuntu/+source/python3.14/+bug/2127900
    "zipfile._path",
    "zipfile._path.glob",
    # Other random bits and pieces.
    "logging.config",  # Requires 'queue'
    "logging.handlers",  # Requires 'queue'
    "optparse",  # https://bugs.launchpad.net/ubuntu/+source/python3.14/+bug/2127899
    "urllib.request",  # Requires 'http', which is in stdlib (not minimal)
)

for path in ROOT_PATH.rglob("*.py"):
    relative = path.relative_to(ROOT_PATH)
    module = [parent.name for parent in relative.parents[-2::-1]]
    if path.name not in ("__init__.py", "__main__.py"):
        module.append(path.stem)

    module_name = ".".join(module)

    # These modules cannot be imported without the rest of stdlib installed due to
    # debianization issues.
    if module_name in MODULES_NOT_IMPORTABLE:
        print(f"Skipping {module_name} due to bug...")
        continue

    print(f"Importing module {module_name!r}")
    print(f"   path: {path!r}")
    importlib.import_module(module_name)
