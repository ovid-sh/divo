---
title: About
date: 2026-10-02
---

# About

Divo walks `content/`, splits a `---` front matter block, renders a small piece of markdown, and fills `templates/page.html`.

## What is in the box

Pages are files. A section is a directory. `index.md` is that directory's page, and every other file becomes its own directory of `index.html`.

---

It is a proof of concept of [Zola](https://www.getzola.org/)'s pipeline, not a replacement for it. Templates are a slice of Tera, and an `ov` fence is highlighted. There is no Sass and no live reload.
