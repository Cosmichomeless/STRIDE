#!/usr/bin/env python3
"""Render docs/privacy.md and docs/support.md to docs/privacy/index.html and docs/support/index.html.

The pages are generated and committed (docs/.nojekyll turns Jekyll off), and they live in folders so
that the URLs App Store Connect and the app point to keep working:

    https://cosmichomeless.github.io/STRIDE/privacy/
    https://cosmichomeless.github.io/STRIDE/support/

Each .md file holds the English text, a line with `---`, then the Spanish text. Run after editing
either file:

    pip install markdown && python3 scripts/build-pages.py
"""
import re
from pathlib import Path

import markdown

DOCS = Path(__file__).resolve().parent.parent / "docs"

PAGE = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title}</title>
<meta name="description" content="{description}">
<meta name="theme-color" content="#f66534">
<link rel="icon" type="image/png" href="../assets/icon.png">
<link rel="apple-touch-icon" href="../assets/apple-touch-icon.png">
<link rel="stylesheet" href="../assets/site.css">
</head>
<body>
<header class="bar">
  <div class="wrap">
    <a class="brand" href="../"><img src="../assets/icon.png" alt="" width="40" height="40">STRIDE</a>
    <a class="back" href="../">&larr; Home</a>
  </div>
</header>
<main class="doc-wrap">
  <div class="langs"><a href="#en">English</a><a href="#es">Español</a></div>
  <article class="doc">
    <section id="en" lang="en">
{english}
    </section>
    <section id="es" lang="es">
{spanish}
    </section>
  </article>
</main>
<footer>
  <div class="wrap">
    <span>&copy; 2026 David Rodríguez</span>
    <nav aria-label="Footer">
      <a href="../privacy/">Privacy policy</a>
      <a href="../support/">Support</a>
      <a href="https://github.com/Cosmichomeless/STRIDE">Source</a>
    </nav>
  </div>
</footer>
</body>
</html>
"""

PAGES = {
    "privacy": ("Privacy Policy — STRIDE", "STRIDE does not collect your data: no accounts, no analytics, no ads, no tracking."),
    "support": ("STRIDE — Support", "Get help with STRIDE, the run tracker with no account."),
}


def render(text: str) -> str:
    html = markdown.markdown(text.strip())
    html = re.sub(r"<p>(<strong>(?:Summary|Resumen):)", r'<p class="summary">\1', html)
    return re.sub(r'<p>(<a id="[^"]+"></a>)</p>', r"\1", html)


for name, (title, description) in PAGES.items():
    source = (DOCS / f"{name}.md").read_text(encoding="utf-8")
    english, spanish = re.split(r"^---\s*$", source, maxsplit=1, flags=re.MULTILINE)
    page = PAGE.format(title=title, description=description, english=render(english), spanish=render(spanish))
    out = DOCS / name / "index.html"
    out.parent.mkdir(exist_ok=True)
    out.write_text(page, encoding="utf-8")
    print(f"wrote {out.relative_to(DOCS.parent)}")
