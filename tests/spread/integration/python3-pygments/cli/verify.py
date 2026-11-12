from pathlib import Path


output = Path("/tmp/example.html").read_text()
assert '<span class="k">def</span>' in output
assert '<span class="nf">greet</span>' in output

print("success")
