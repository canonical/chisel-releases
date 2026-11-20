import subprocess

with open("/pdb_target.py", "w") as f:
    f.write("value = 21\nprint(value * 2)\n")
pdb = subprocess.run(
    ["/usr/bin/pdb3.10", "/pdb_target.py"],
    input="next\np value * 2\ncontinue\n",
    capture_output=True,
    text=True,
    check=True,
)
assert "(Pdb) 42" in pdb.stdout, pdb.stdout

pydoc = subprocess.run(
    ["/usr/bin/pydoc3.10", "math"],
    capture_output=True,
    text=True,
    check=True,
)
assert "mathematical functions" in pydoc.stdout, pydoc.stdout

with open("/gettext_target.py", "w") as f:
    f.write('_("hello")\n')
subprocess.run(
    ["/usr/bin/pygettext3.10", "-o", "/messages.pot", "/gettext_target.py"],
    check=True,
)
with open("/messages.pot") as f:
    pot = f.read()
assert 'msgid "hello"' in pot, pot
