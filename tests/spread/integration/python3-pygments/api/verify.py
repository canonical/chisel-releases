from pygments import highlight
from pygments.formatters import HtmlFormatter
from pygments.lexers import PythonLexer


output = highlight("answer = 42\n", PythonLexer(), HtmlFormatter())
assert '<span class="n">answer</span>' in output
assert '<span class="mi">42</span>' in output

print("success")
