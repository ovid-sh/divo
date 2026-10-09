# divo

A static site generator written in [Ovid](https://github.com/ovid-sh/ovid). It is a proof of concept of the pipeline [Zola](https://www.getzola.org/) is built around: find content, read front matter, render markup, fill one template, write a directory of HTML.

On 2026-10-09 the binary was 21920 bytes. `ovid build` reported the system calls it can reach: `read`, `write`, `close`, `fstat`, `mmap`, `munmap`, `madvise`, `exit`, `getdents64`, `openat`, `mkdirat`, `fstatat`. The self-hosted compiler (`../ovid/prog`, given `--std ../ovid/std`) emitted the same bytes.

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

Markdown is a subset, parsed by a line scan:

- paragraphs, separated by a blank line
- `#`, `##`, `###` headings (the hashes need a following space)
- `- ` lists
- a line that is `---` becomes `<hr>`
- fences opened and closed by a line that starts with ` ``` `
- inline `**strong**`, `` `code` ``, and `[text](url)`

Those constructs do not nest. The inside of each is escaped text. `&`, `<`, `>`, and `"` are escaped. An unclosed marker is copied through.

`config.txt` is `key: value` lines. Blank lines and `#` comments are ignored. `title` is required.

Template slots:

| slot | inserted as |
|---|---|
| `{{title}}` `{{date}}` `{{href}}` `{{site_title}}` `{{root}}` | escaped text |
| `{{body}}` `{{pages}}` | HTML already rendered |
| anything else | left as written |

`{{root}}` is `/`, so `href="{{root}}style.css"` is `/style.css`. Serve `public/` as the root of the site. A page with no `title` in its front matter uses its first heading, or else the file name (`index.md` becomes "Home").

## What it does not do

Zola's binary also does Tera templates, CommonMark, syntax highlighting, Sass, taxonomies, pagination, search, image processing, multilingual sites, and a live-reload server. divo does not. Those are large programs. Ovid has no string type, map, slice, regular expression, or function pointer, so each one is a hand-written scan over bytes and a linked list of structs. The standard library can read and write files and list directories, which is the part a generator cannot do without. It cannot listen on a socket: an HTTP program is a handler on stdin and stdout. `zola serve` does not fit that shape. `divo build` does.

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
html/     front matter, the markdown subset, template slots
divo/     build: load, sort, render, write
```

There is no per-allocation free. `Build` keeps the inputs and drops each rendered page with `ovid/io.MarkHeap` and `ResetHeap` after the file is written. A page's bytes have to be finished before that reset: the mark is the free.
