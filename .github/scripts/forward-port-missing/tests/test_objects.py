import pickle

from chisel_releases_data import PR, Commit, UbuntuRelease


def test_commit_picklable() -> None:
    commit = Commit(ref="abc123", repo_name="Test commit", repo_owner="tester", repo_url="", sha="1234abc")
    pickled = pickle.dumps(commit)
    unpickled = pickle.loads(pickled)
    assert commit == unpickled


def test_commit_getstate() -> None:
    commit = Commit(ref="abc123", repo_name="Test commit", repo_owner="tester", repo_url="", sha="1234abc")

    # drain state
    state = commit.__getstate__()

    # manually create new object and set state
    new_commit = Commit.__new__(Commit)
    new_commit.__setstate__(state)
    assert commit == new_commit


def test_pr_picklable() -> None:
    pr = PR(
        number=1,
        title="Test PR",
        user="tester",
        head=Commit(ref="abc123", repo_name="Test commit", repo_owner="tester", repo_url="", sha="1234abc"),
        base=Commit(ref="ubuntu-25.04", repo_name="Base commit", repo_owner="tester", repo_url="", sha="456def"),
        label=True,
        url="http://example.com/pr/1",
    )
    pickled = pickle.dumps(pr)
    unpickled = pickle.loads(pickled)
    assert pr == unpickled


def test_pr_getstate() -> None:
    pr = PR(
        number=1,
        title="Test PR",
        user="tester",
        head=Commit(ref="abc123", repo_name="Test commit", repo_owner="tester", repo_url="", sha="1234abc"),
        base=Commit(ref="ubuntu-25.04", repo_name="Base commit", repo_owner="tester", repo_url="", sha="456def"),
        label=True,
        url="http://example.com/pr/1",
    )
    state = pr.__getstate__()
    new_pr = PR.__new__(PR)
    new_pr.__setstate__(state)
    assert pr == new_pr


def test_prs_by_ubuntu_release_picklable() -> None:
    release = UbuntuRelease("25.04", "noble")
    pickled = pickle.dumps(release)
    unpickled = pickle.loads(pickled)
    assert release == unpickled


def test_prs_by_ubuntu_release_getstate() -> None:
    release = UbuntuRelease("25.04", "noble")
    state = release.__getstate__()
    new_release = UbuntuRelease.__new__(UbuntuRelease)
    new_release.__setstate__(state)
    assert release == new_release
