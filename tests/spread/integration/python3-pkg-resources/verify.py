from pathlib import Path

import pkg_resources

assert pkg_resources.parse_version("1.0rc1") < pkg_resources.parse_version("1.0")

requirement = pkg_resources.Requirement.parse("demo[cli]>=1.0")
assert requirement.project_name == "demo"
assert requirement.extras == ("cli",)

site = Path("/site/demo-1.0.dist-info")
site.mkdir(parents=True)
(site / "METADATA").write_text("Metadata-Version: 2.1\nName: demo\nVersion: 1.0\n")
working_set = pkg_resources.WorkingSet(["/site"])
assert working_set.require("demo>=1.0")[0].version == "1.0"
