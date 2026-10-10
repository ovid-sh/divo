# Divo

Divo is a static site generator written in [Ovid](https://github.com/ovid-sh/ovid). It follows the pipeline [Zola](https://www.getzola.org/) is built around: find content, read front matter, render markup, fill one template, and write a directory of HTML. It is a proof of concept of that pipeline, not a replacement for Zola.

A site is `config.txt`, `content/**/*.md`, one `templates/page.html`, and an optional `static/` tree. `divo build` reads them and writes `public/`.

The markup, the template language, and the syntax highlighting are slices. Markdown covers a CommonMark subset. Templates cover variables, `if`, and `for`. Highlighting covers `ov` and `ovid` fences only. There is no Sass, taxonomy, pagination, search, image processing, or live reload.

On 2026-10-09 the binary was 34200 bytes, built with Ovid `7b0b9c7`. `ovid build` reported the system calls it can reach: `read`, `write`, `close`, `fstat`, `mmap`, `munmap`, `madvise`, `exit`, `getdents64`, `openat`, `mkdirat`, `fstatat`.

## What it does

```text
site/
  config.txt              title: ...
  content/**/*.md         --- front matter, then markdown
  templates/page.html     {{slots}}
  static/**               copied as-is
public/                   written by `divo build`
```

`content/index.md` becomes `public/index.html` at `/`. `content/about.md` becomes `public/about/index.html` at `/about/`. `content/blog/hello.md` becomes `public/blog/hello/index.html`. A directory's `index.md` is that directory's page (`content/blog/index.md` would be `/blog/`).

Pages are ordered newest `date` first. A page with no date sorts last. Equal dates sort by path. The same list is inserted into every page as `{{pages}}`.

Markdown is a CommonMark slice, parsed by a line scan:

- paragraphs, separated by a blank line
- ATX headings `#` through `######` (the hashes need a following space; a closing hash run is stripped)
- one level of `- `, `* `, `+ `, and `1. ` / `1) ` lists (the ordered number is ignored)
- thematic breaks: three or more of `-`, `*`, or `_`, spaces allowed between them
- `>` block quotes, kept as one paragraph until a blank line
- fences of three or more backticks, with an optional info word (`class="language-..."`)
- inline `**strong**`, `__strong__`, `*em*`, `_em_` (not inside a word), `` `code` ``, and `[text](url)`

Those constructs do not nest, lists do not continue onto the next line, and emphasis is not the full flanking-delimiter rule. The inside of each inline marker is escaped text. `&`, `<`, `>`, and `"` are escaped. An unclosed marker is copied through.

An `ov` or `ovid` fence is highlighted: keywords, `"strings"`, `//` comments, and numbers become `<span class="tok-kw">`, `tok-str`, `tok-com`, and `tok-num`. Any other info word only sets the class. This is a hand-written lexer for one language, not syntect and not a TextMate grammar.

`config.txt` is `key: value` lines. Blank lines and `#` comments are ignored. `title` is required.

Templates are a Tera slice. Spaces inside the tags are ignored.

| tag | effect |
|---|---|
| `{{title}}` `{{date}}` `{{href}}` `{{site_title}}` `{{root}}` `{{page.title}}` | escaped text |
| `{{body}}` `{{pages}}` | HTML already rendered |
| `{{name \| safe}}` | that value, unescaped |
| `{{name \| escape}}` | that value, escaped |
| `{% if date %}...{% else %}...{% endif %}` | the branch whose value is non-empty |
| `{% for page in pages %}...{% endfor %}` | the body once per page, newest date first |
| anything else | left as written |

`page.title` outside a loop is the page being rendered. Inside `{% for page in pages %}`, `page.title` is the loop value. The only list is `pages`. There is no `{% extends %}`, no macros, no filters beyond `safe` and `escape`, and whitespace is kept.

`{{root}}` is `/`, so `href="{{root}}style.css"` is `/style.css`. Serve `public/` as the root of the site. A page with no `title` in its front matter uses its first heading, or else the file name (`index.md` becomes "Home"). `{{pages}}` is still the prebuilt `<ul>`; the loop is how a template builds that list itself.

## What it does not do

Zola's binary also does the rest of Tera, the rest of CommonMark, syntect highlighting for every language, Sass, taxonomies, pagination, search, image processing, multilingual sites, and a live-reload server. Divo does not. Those are large programs. Ovid has no string type, map, slice, regular expression, or function pointer, so each piece is a hand-written scan over bytes and a linked list of structs. The standard library can read and write files and list directories, which is the part a generator cannot do without. It cannot listen on a socket: an HTTP program is a handler on stdin and stdout. `zola serve` does not fit that shape. `divo build` does.

## Build and run

From this directory, with the Ovid toolchain at `../ovid`:

```sh
../ovid/bin/ovid test -C .
../ovid/bin/ovid build -C . -o bin/divo
./bin/divo build examples/notes
```

`ovid run` is the wrong way to try a build. On Linux it confines the program to a fresh writable directory, so `public/` would not be written next to the site. `ovid run --no-confine -- build examples/notes` works. The built `bin/divo` is an ordinary static executable and needs no confine flag.

```sh
./bin/divo build examples/notes
python -m http.server -d examples/notes/public 8080
```

`script/check.sh` runs the tests, rebuilds the binary, builds a copy of `examples/notes`, and diffs `public/` against `examples/notes/expected/`.

## Layout of the program

```text
bytes/    path join, compare, trim, search
fs/       getdents walk, mkdir -p, read, write, copy a tree
html/     front matter, the CommonMark slice, the Tera slice
divo/     build: load, sort, render, write
```

There is no per-allocation free. `Build` keeps the inputs and drops each rendered page with `ovid/io.MarkHeap` and `ResetHeap` after the file is written. A page's bytes have to be finished before that reset: the mark is the free.
