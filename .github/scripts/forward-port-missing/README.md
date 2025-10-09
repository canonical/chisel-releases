# forward_port_missing

Script to check whether a PR needs a forward port label.


Tested in Python 3.9+.

<!-- spellchecker: ignore venv pytest mypy -->
## Testing and development

Setup with:

```bash
uv sync && source .venv/bin/activate
```

Test with:

```bash
pytest
```

Format and typecheck with:


```bash
ruff format . && ruff check --fix . && mypy
```

### Tox

To test with [tox](https://tox.wiki/en/latest/index.html), I recommend [tox-uv](https://github.com/tox-dev/tox-uv):

```bash
uv tool install tox --with tox-uv # use uv to install
```

and then just

```bash
tox
```

<!-- spellchecker: ignore joblib -->
### Memoisation

We don't own the apis we're calling. During development it is likely one will
re-run the script more often than reasonable, and therefore hit the rate limit.
An option to memoise the results of the network calls with `joblib` is therefore
provided through the `USE_MEMORY` env variable.

Likewise, for the purposes of development, a `CHISEL_RELEASES_URL` env variable
is available. The default url is `https://github.com/canonical/chisel-releases`.

Here is an example call one might use during development:

```bash
USE_MEMORY=1 GITHUB_TOKEN="github_pat_123456789" ./forward_port_missing.py --log-level=debug -j=-1
```