import subprocess

# pdb3.11 and pygettext3.11 ship with "#! /usr/bin/env python3". Run all three
# scripts through their own shebang, which must reach this Python.
with open("/pdb_target.py", "w") as f:
    f.write("value = 21\nprint(value * 2)\n")
pdb = subprocess.run(
    ["/usr/bin/pdb3.11", "/pdb_target.py"],
    input="next\np value * 2\np __import__('sys').version_info[:2]\ncontinue\n",
    capture_output=True,
    text=True,
    check=True,
)
assert "(Pdb) 42" in pdb.stdout, pdb.stdout
assert "(Pdb) (3, 11)" in pdb.stdout, pdb.stdout

pydoc = subprocess.run(
    ["/usr/bin/pydoc3.11", "math"],
    capture_output=True,
    text=True,
    check=True,
)
assert "mathematical functions" in pydoc.stdout, pydoc.stdout

with open("/usr/bin/pygettext3.11", "rb") as f:
    shebang = f.readline()
assert shebang == b"#!/usr/bin/python3.11\n", shebang
with open("/gettext_target.py", "w") as f:
    f.write('_("hello")\n')
subprocess.run(
    ["/usr/bin/pygettext3.11", "-o", "/messages.pot", "/gettext_target.py"],
    check=True,
)
with open("/messages.pot") as f:
    pot = f.read()
assert 'msgid "hello"' in pot, pot
