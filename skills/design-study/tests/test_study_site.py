"""Runnable check for study_site.py. Run with the isaham venv python; prints ok."""
import json
import re
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "scripts"))
sys.dont_write_bytecode = True  # keep __pycache__ out of the skill folder

import study_site  # noqa: E402


def values(tally, prop):
    return [value for value, _count in tally[prop]]


def test_rgb_to_hex():
    assert study_site.rgb_to_hex("rgb(10, 124, 255)") == "#0a7cff"
    assert study_site.rgb_to_hex("rgba(10, 124, 255, 1)") == "#0a7cff"
    assert study_site.rgb_to_hex("rgba(0, 0, 0, 0)") is None
    assert study_site.rgb_to_hex("rgba(0, 0, 0, 0.2)") == "rgba(0, 0, 0, 0.2)"
    assert study_site.rgb_to_hex("oklch(0.7 0.1 200)") == "oklch(0.7 0.1 200)"


def test_tally():
    samples = [
        {"font-size": "16px", "padding": "8px 16px", "color": "rgb(0, 0, 0)"},
        {"font-size": "16px", "padding": "0px", "color": "rgba(0, 0, 0, 0)"},
        {"font-size": "32px", "gap": "normal", "color": "rgb(0, 0, 0)"},
    ]
    tally = study_site.tally(samples)
    assert tally["font-size"] == [["16px", 2], ["32px", 1]]
    assert tally["color"] == [["#000000", 2]]
    assert sorted(values(tally, "spacing")) == ["16px", "8px"]
    many = [{"font-size": f"{n}px"} for n in range(30)]
    assert len(study_site.tally(many)["font-size"]) == 20


def test_slugify():
    slug = study_site.slugify("https://Ex.com/a/../b?x=1")
    assert re.fullmatch(r"[a-z0-9-]+", slug), slug
    assert slug.startswith("ex-com")


def test_capture():
    with tempfile.TemporaryDirectory() as tmp:
        out = Path(tmp)
        study_site.capture((HERE / "fixture.html").as_uri(), out)
        assert (out / "390.png").stat().st_size > 0
        assert (out / "1440.png").stat().st_size > 0
        data = json.loads((out / "tokens.json").read_text())
        tally = data["tally"]
        assert data["custom_properties"]["--brand"] == "#0a7cff"
        assert "#0a7cff" in values(tally, "background-color")
        assert "12px" in values(tally, "border-radius")
        assert "32px" in values(tally, "font-size")
        assert "8px" in values(tally, "spacing")
        # centered <main> must not leak its auto margins (420px at 1440) into spacing
        assert max(float(v.rstrip("px")) for v in values(tally, "spacing")) < 100
        assert "Georgia, serif" in values(tally, "font-family")
        assert data["widths"] == [390, 1440]


if __name__ == "__main__":
    test_rgb_to_hex()
    test_tally()
    test_slugify()
    test_capture()
    print("ok")
