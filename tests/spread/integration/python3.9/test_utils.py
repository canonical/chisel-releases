import subprocess

# pdb3.9 is "#! /usr/bin/env python3", i.e. python3.8 on this release, and then
# imports the python3.9 stdlib from its own directory, which fails in the deb
# as well. Only pydoc3.9 and pygettext3.9 are tested here.
pydoc = subprocess.run(
    ["/usr/bin/pydoc3.9", "math"],
    capture_output=True,
    text=True,
    check=True,
)
assert "mathematical functions" in pydoc.stdout, pydoc.stdout

with open("/gettext_target.py", "w") as f:
    f.write('_("hello")\n')
subprocess.run(
    ["/usr/bin/pygettext3.9", "-o", "/messages.pot", "/gettext_target.py"],
    check=True,
)
with open("/messages.pot") as f:
    pot = f.read()
assert 'msgid "hello"' in pot, pot
