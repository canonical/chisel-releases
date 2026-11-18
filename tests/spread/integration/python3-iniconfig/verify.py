from iniconfig import IniConfig, ParseError


config = IniConfig(
    "example.ini",
    data="[pytest]\naddopts = -q\nmarkers =\n    slow\n[tool]\ncount = 3\n",
)
assert [section.name for section in config] == ["pytest", "tool"]
assert config["pytest"]["addopts"] == "-q"
assert config["pytest"]["markers"] == "slow"
assert config["tool"].get("count", convert=int) == 3
assert config.lineof("tool", "count") == 6

try:
    IniConfig("broken.ini", data="value = no-section\n")
except ParseError as error:
    assert error.path == "broken.ini"
    assert error.lineno == 0
else:
    raise AssertionError("invalid INI did not raise ParseError")

print("success")
