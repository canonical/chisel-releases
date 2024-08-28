"""
Tests some of the standard Python functionality
"""

import html
import json
import uuid


def check_json_loading():
    print("Checking JSON loading...")

    sample = '{"foo": ["bar"]}'
    assert json.loads(sample) == {"foo": ["bar"]}


def check_html_escaping():
    print("Checking HTML escaping...")

    sample = "Some <sample> & 'text' with \"HTML\" characters"
    exp = "Some &lt;sample&gt; &amp; &#x27;text&#x27; with &quot;HTML&quot; characters"
    assert html.escape(sample) == exp


def check_uuid_gen():
    print("Checking UUID generation...")

    assert type(uuid.uuid1().int) == int


if __name__ == "__main__":
    check_json_loading()
    check_html_escaping()
    check_uuid_gen()
