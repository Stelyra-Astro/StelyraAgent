from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
EMAIL = "Stelyra-Astro@proton.me"


def read(path):
    return (ROOT / path).read_text(encoding="utf-8")


def test_required_files_exist():
    for rel in ["index.html", "privacy/index.html", "terms/index.html", "assets/styles.css"]:
        assert (ROOT / rel).is_file(), rel


def test_home_top_nav_links():
    html = read("index.html")
    assert 'href="privacy/"' in html
    assert 'href="terms/"' in html
    nav = re.search(r'<nav class="top-nav".*?</nav>', html, re.S)
    assert nav, "top nav missing"
    assert "Privacy" in nav.group(0) and "Terms" in nav.group(0)


def test_legal_pages_link_home_and_each_other():
    privacy = read("privacy/index.html")
    terms = read("terms/index.html")
    assert 'href="../"' in privacy and 'href="../terms/"' in privacy
    assert 'href="../"' in terms and 'href="../privacy/"' in terms


def test_support_email_consistent():
    for rel in ["index.html", "privacy/index.html", "terms/index.html"]:
        text = read(rel)
        assert EMAIL in text, rel
        assert f"mailto:{EMAIL}" in text, rel


def test_privacy_covers_core_data_flows():
    text = read("privacy/index.html").lower()
    for phrase in ["sign in with apple", "credits", "ai", "astrology", "revenuecat", "supabase", "delete"]:
        assert phrase in text, phrase


def test_terms_cover_purchases_and_ai_disclaimer():
    text = read("terms/index.html").lower()
    for phrase in ["credits", "in-app", "apple", "ai", "astrology", "professional advice", "refund"]:
        assert phrase in text, phrase


def test_no_framework_or_remote_asset_dependency():
    for rel in ["index.html", "privacy/index.html", "terms/index.html"]:
        text = read(rel).lower()
        assert "react" not in text
        assert "vue" not in text
        assert "cdn." not in text
        assert "fonts.googleapis" not in text


def test_pages_have_meta_viewport_and_descriptions():
    for rel in ["index.html", "privacy/index.html", "terms/index.html"]:
        text = read(rel)
        assert 'name="viewport"' in text
        assert 'name="description"' in text
