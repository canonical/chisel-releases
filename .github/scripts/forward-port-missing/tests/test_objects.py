import pickle

import pytest

from chisel_releases_data import (
    PR as chr_PR,
)
from chisel_releases_data import (
    Commit as chr_Commit,
)
from chisel_releases_data import (
    UbuntuRelease as chr_UbuntuRelease,
)
from forward_port_missing import (
    Commit as fpm_Commit,
)


def test_commit_picklable() -> None:
    chr_commit = chr_Commit(ref="abc123", repo_name="Test commit", repo_owner="tester", repo_url="", sha="1234abc")
    pickled = pickle.dumps(chr_commit)
    unpickled = pickle.loads(pickled)
    assert chr_commit == unpickled

    # we never expect these to be pickled so we disable it
    fpm_commit = fpm_Commit(ref="abc123", repo_name="Test commit", repo_owner="tester", repo_url="", sha="1234abc")
    with pytest.raises(pickle.PicklingError):
        pickle.dumps(fpm_commit)


def test_commit_getstate() -> None:
    chr_commit = chr_Commit(ref="abc123", repo_name="Test commit", repo_owner="tester", repo_url="", sha="1234abc")

    # drain state
    state = chr_commit.__getstate__()

    # manually create new object and set state
    new_chr_commit = chr_Commit.__new__(chr_Commit)
    new_chr_commit.__setstate__(state)
    assert chr_commit == new_chr_commit

    # we should be able to create the commit from state directly
    fpm_commit = fpm_Commit(ref="abc123", repo_name="Test commit", repo_owner="tester", repo_url="", sha="1234abc")
    state = fpm_commit.__getstate__()
    new_fpm_commit = fpm_Commit.from_state(state)
    assert fpm_commit == new_fpm_commit


def test_pr_picklable() -> None:
    pr = chr_PR(
        number=1,
        title="Test PR",
        user="tester",
        head=chr_Commit(ref="abc123", repo_name="Test commit", repo_owner="tester", repo_url="", sha="1234abc"),
        base=chr_Commit(ref="ubuntu-25.04", repo_name="Base commit", repo_owner="tester", repo_url="", sha="456def"),
        label=True,
        url="http://example.com/pr/1",
    )
    pickled = pickle.dumps(pr)
    unpickled = pickle.loads(pickled)
    assert pr == unpickled


def test_pr_getstate() -> None:
    pr = chr_PR(
        number=1,
        title="Test PR",
        user="tester",
        head=chr_Commit(ref="abc123", repo_name="Test commit", repo_owner="tester", repo_url="", sha="1234abc"),
        base=chr_Commit(ref="ubuntu-25.04", repo_name="Base commit", repo_owner="tester", repo_url="", sha="456def"),
        label=True,
        url="http://example.com/pr/1",
    )
    state = pr.__getstate__()
    new_pr = chr_PR.__new__(chr_PR)
    new_pr.__setstate__(state)
    assert pr == new_pr


def test_prs_by_ubuntu_release_picklable() -> None:
    release = chr_UbuntuRelease("25.04", "noble")
    pickled = pickle.dumps(release)
    unpickled = pickle.loads(pickled)
    assert release == unpickled


def test_prs_by_ubuntu_release_getstate() -> None:
    release = chr_UbuntuRelease("25.04", "noble")
    state = release.__getstate__()
    new_release = chr_UbuntuRelease.__new__(chr_UbuntuRelease)
    new_release.__setstate__(state)
    assert release == new_release
