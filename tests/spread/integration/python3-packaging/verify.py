from packaging.markers import Marker
from packaging.metadata import Metadata
from packaging.requirements import Requirement
from packaging.specifiers import SpecifierSet
from packaging.tags import sys_tags
from packaging.version import Version


assert Version("2.0rc1") < Version("2.0")
assert Version("1!2.0.post1").epoch == 1
assert Version("1.5") in SpecifierSet("~=1.4")
assert Version("2.0") not in SpecifierSet("~=1.4")

requirement = Requirement('demo[cli]>=1.2; python_version >= "3.14"')
assert requirement.name == "demo"
assert requirement.extras == {"cli"}
assert requirement.specifier.contains("1.2")
assert Marker('python_version >= "3.14"').evaluate()

metadata = Metadata.from_email(
    "Metadata-Version: 2.1\n"
    "Name: demo\n"
    "Version: 1.0\n"
)
assert metadata.name == "demo"
assert metadata.version == Version("1.0")

tag = next(sys_tags())
assert tag.interpreter.startswith("cp314")

print("success")
