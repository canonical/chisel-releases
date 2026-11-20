import subprocess

# pdb3.11 is "#! /usr/bin/env python3", i.e. python3.10 on this release, and then
# imports the python3.11 stdlib from its own directory, which fails in the deb
# as well. Only pydoc3.11 and pygettext3.11 are tested here.
pydoc = subprocess.run(
    ["/usr/bin/pydoc3.11", "math"],
    capture_output=True,
    text=True,
    check=True,
)
assert "mathematical functions" in pydoc.stdout, pydoc.stdout

with open("/gettext_target.py", "w") as f:
    f.write('_("hello")\n')
subprocess.run(
    ["/usr/bin/pygettext3.11", "-o", "/messages.pot", "/gettext_target.py"],
    check=True,
)
with open("/messages.pot") as f:
    pot = f.read()
assert 'msgid "hello"' in pot, pot
