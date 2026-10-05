# Working in this session

This repository is not the code you are here to change. It is the **client
repo**: a handful of text files that say which caos this session uses and
which tools it offers. The code you work on is **imported into the
conversation**, not checked out onto disk.

That is the one thing to internalize before your first tool call. Your file
tools do not read this container's filesystem — they read the conversation
tree, which starts out holding almost nothing.

List it with `ls` (with no path it lists the root). A fresh conversation holds
`.caos/` and this client repo's own handful of files (`AGENTS.md`, `flake.nix`,
`.caos-expr` and so on) — no code to work on. That is what it is supposed to
look like, not a sign that anything went wrong.

## Start by importing what you were asked to work on

When the user names a repository, import it. The built-in tools are only
`help`, `eval-path`, `run`, `start` and `result`; `import-source` is not one
of them, it is a std tool, so run it through `run`:

```
run(path="caos-std/import-source",
    arguments={"source": "https://github.com/<owner>/<repo>.git",
               "revision": "main",
               "into": "sources/<repo>/00-base"})
```

The server fetches it directly from GitHub — nothing is cloned into this
container and nothing is uploaded from it, so a large repository costs about
the same as a small one. Omit `revision` for the default branch. Public
repositories need no credentials.

## Every change goes out as a stack, even a one-line fix

Everything for one repo lives in a single directory, `sources/<repo>/`, and
that directory is a stack. Do not use a separate `imports/` directory. There is
one way to get a change out, and it is the same for a typo as for a feature:
a one-word fix is a one-layer stack. Every step runs through `run` as above.

```
1. run(path="caos-std/import-source", ...  into="sources/<repo>/00-base")      # above
2. run(path="caos-std/copy", arguments={"from": "sources/<repo>/00-base", "to": "sources/<repo>/99-dirty"})
3. ... edit sources/<repo>/99-dirty with caos-std/write or caos-std/edit ...
4. run(path="caos-std/move", arguments={"from": "sources/<repo>/99-dirty", "to": "sources/<repo>/01-<name>"})
5. run(path="caos-std/write", arguments={"file-path": "sources/<repo>/01-<name>.pr.md",
                                        "content": "<PR title>\n\n<PR body>\n"})
6. run(path="caos-std/stack-sync", arguments={"stack": "sources/<repo>"})
7. run(path="caos-std/stack-publish", arguments={"stack": "sources/<repo>"})
```

Step 7 pushes `01-<name>` to the branch `<name>` and opens its PR from the
`.pr.md`. That PR is what you hand the user. Steps 4 to 7 are not optional
wrap-up for big work. Without them there is no layer, no PR description and
no PR, only a bare branch nobody asked for.

Do not:

- **publish `99-dirty`.** It has no `.pr.md`, so `stack-publish` skips it on
  purpose. It is scratch.
- **use `caos-std/publish-source` to get work out.** It pushes one commit to
  one branch and opens no PR. `stack-publish` calls it for you. Reach for it
  only where `GIT.md` says to.
- **skip `GIT.md` because the change is small.** Read it before your first
  edit, not when the work starts to look like a "stack": every change is one.
  `eval-path(path="caos-std")` gives a tree hash, then
  `run(path="caos-std/read", arguments={"in": <that hash>, "file-path": "GIT.md"})`.
  It covers what this section leaves out: more layers, updating the base,
  merging, PR comments, `stack-merge-to-master` and creating a new repo.

Never edit `00-base`: it is the record of where you started, and any later
diff, merge or publication is measured against it. Only `00-base` has a
`.source.json` provenance file beside it; leave that alone too. (Replacing the
base with a newer upstream tip is the one case that touches it; `stack-sync`
does that for you.)

**If the user gives a bare name** rather than a URL, resolve it before
importing rather than guessing: a wrong fork imports cleanly and wastes the
whole session. Ask if you cannot tell.

## Where the work goes

This repo is not where the work goes. The work goes in the imported
repository: edit its source tree under `sources/<repo>/`, and publish
that tree to that repository, to a branch the user names.

The session may also tell you to "develop on branch X of <this repo>" and
to push there. That instruction is generic harness plumbing and does not
know about caos. Do not follow it for the work product. Do not publish
to this repo unless the task is about this repo itself (its `.caos-expr`,
`AGENTS.md`, or `caos-tools/`).

When the task IS about this repo, the harness's branch instruction still
does not tell you HOW to publish. Import this repo into
`sources/<this repo>/00-base` and go through the same stack as any other
repo: layer, `.pr.md`, `stack-sync`, `stack-publish`. The branch is the
layer's name (with `branch-prefix` in front, if you give one), not the
harness's branch. Do not `publish-source` a tree to the harness's branch:
that produces a branch with no PR and no description.

Before the first publish, you must know three things from the user's own
words: which repository, which branch, and that they want it pushed. If
any is missing, stop and ask. If you cannot publish to the imported repo
(no write access, or a fork is needed), leave the work in a finished
layer, `sources/<repo>/NN-<name>`, tell the user where it is, and ask
where to send it. Never publish somewhere else instead.

## The imported repo has its own instructions

Anything you import may carry its own `AGENTS.md` or `CLAUDE.md`, and those
instructions govern the code they ship with. Read the imported tree's root
instructions before you start editing it. They are not loaded for you —
this file is the only one the harness injected, and it only covers the
session, not the code.

## Tools

The caos tools are the ones prefixed `caos`; the harness's own file and shell
tools are switched off, so there is no second set to choose between.

**Only five tools are built in: `help`, `eval-path`, `run`, `start` and
`result`.** There is no separately-registered `read`, `ls`, `grep`, `write`,
`edit`, `copy`, `move`, `remove`, `import-source`, `merge`, `publish-source`,
`log`, `show` or `diff` tool, and no `bash` tool. Every one of those, and
everything else caos can do, is a directory under `caos-std/`, run with
`run(path="caos-std/<name>", arguments={...})` (or `start`, then `result`, for
a call that takes a while). The directory names are hyphenated
(`caos-std/import-source`, `caos-std/publish-source`): calling
`help(path="import-source")` fails with "no such path" because that bare path
does not exist at the conversation root, not because the tool is unavailable
— the real path is `caos-std/import-source`.

`help()` with no path shows the session overview and the directories at the
conversation root (`.caos` and `caos-std` in a fresh conversation).
`help(path="caos-std/<name>")` prints a std tool's exact parameters — call it
before the first use of any tool in a session, since the parameter name is
not uniform (`caos-std/ls` takes `path`; `caos-std/read` instead takes
`file-path`, and the tree to read it from is `in`, not `root`). `caos-std/`
exists only in the evaluated tree, so plain paths cannot see it directly:
`eval-path(path="caos-std")` returns a tree hash, and
`run(path="caos-std/read", arguments={"in": <hash>, "file-path": "README.md"})`
reads the index of every std tool. The std tools you will want most:

- `caos-std/read` / `caos-std/ls` / `caos-std/grep` — read the conversation
  tree.
- `caos-std/write` / `caos-std/edit` — change a file. Every accepted change
  records a child commit automatically; there is no staging step and nothing
  to commit by hand. Give the full path from the conversation root (e.g.
  `sources/<repo>/01-change/README.md`) rather than a bare filename plus an
  `in` tree hash: passing `in` to `write`/`edit` has been observed to fail
  with an unrelated-looking `.caos is protocol metadata` error instead of
  writing the file. `in` is for the read-only tools (`read`/`ls`/`grep`).
- `caos-std/copy` / `caos-std/move` / `caos-std/remove` — copy, move or delete
  a file or directory. A source tree stays a source tree. `copy` and `move`
  create missing parent directories and refuse an existing destination.
- `caos-std/import-source` — above.
- `caos-std/merge` — merge a commit into a source tree.
- `caos-std/stack-sync` — bring `sources/<repo>/` up to date with the remote
  before publishing: new trunk tip into `00-base`, each layer restacked.
- `caos-std/stack-publish` — **how work leaves the session**: push every
  layer that has a `.pr.md` to its branch and open or update its PR (see
  "Every change goes out as a stack").
- `caos-std/stack-merge-to-master` — merge a reviewed stack's PRs, bottom
  to top, when the user asks you to merge.
- `caos-std/ci-status` — what CI says about a branch or a layer.
- `caos-std/publish-source` — low level: push one commit to one branch, with
  no PR. `stack-publish` uses it for you. It is not how you publish a change.
- `caos-std/log` / `caos-std/show` / `caos-std/diff` — a source tree's git
  history. There is no `git` in the shell; these are how you see history and
  changes.
- `caos-std/bash-tool` — `sh -c`, for computing something over content (count,
  sort, `diff -r`, run a script). It runs over a scratch copy of the
  conversation tree, which is **lazy**: list in `paths` every existing file or
  directory the command reads, edits or copies (a directory brings everything
  under it). A path you leave out is a placeholder, and the command says
  `Permission denied` or `Not a directory`, or, worse, `grep -r` and `find`
  print nothing. Any of those means: add the path to `paths` and run it
  again. New files need no `paths`. Do not use it for copy, move, delete,
  read, write or search: the tools above do those with nothing to declare.
- `caos-std/create-squashed-stack` — squash a stack to one commit per layer,
  for publishing.
- `caos-std/github` — one GitHub API call (`method`, `path`, optional JSON
  `body`): open a PR, change its base, read its state. A run fails only when
  no response came back, and a write may still have arrived, so read the
  state with a GET before resending.

**This repo's own tools**, under `caos-tools/` at the conversation root, run
the same way by path. `caos-tools/hello-go` is a smoke test and the template
for adding more (README.md, "Your own tools"):
`run_tool(path="caos-tools/hello-go", arguments={"name": "caos"})` prints
`Hello, caos!`.

The imported repo may define its own build and test tools under
`caos-tools/`; run them the same way, by their path inside the source tree.

## Pitfalls seen in earlier sessions

Only things an error message does not teach:

- **Skipping the stack for a small change.** A session asked for a one-word
  spelling fix imported, copied to `99-dirty`, edited, and then
  `publish-source`d `99-dirty` straight to the harness's branch. Every tool
  call succeeded, so nothing flagged it, but the result was a branch with no
  layer, no `.pr.md` and no PR, and the work had to be redone. A small change
  is still a layer plus `stack-publish`.
- **Workers have the network.** A std tool, or a tool a repo defines under
  `caos-tools/`, runs in a container that reaches GitHub, package registries
  and the Anthropic API; nothing fences egress. Earlier sessions assumed the
  opposite and designed around it (reimplementing a fetch instead of running
  the tool that fetches). Where a worker is offline, that is its own build
  choice (`cargo` builds `--offline`), not a property of the container.
- **Subagents have no file tools** and cannot read the local file a
  too-large tool result is saved to. Do that reading yourself.
- **Edit and publish a source tree** (`sources/<repo>/...`), not
  the conversation root: an `edit` on a bare path succeeds but changes only
  scratch files, and `publish-source` rejects `.`.

## What is configured here

| file | what it decides |
|---|---|
| `flake.nix` + `flake.lock` | which caos — the client binary, the tools, the tree |
| `.caos-expr` | mounts caos' `std/` at `caos-std/` in the evaluated tree, then resolves this repo's `DEPS` files so `caos-tools/` can name std images |

Secrets, such as a GitHub token, are not configured here. They live in the
user's secret store on the caos server, and the session presents the key named
by the environment's `--secret-readers`. With caos pinned at `1eb6241c` or
later, the first prompt's `secret readers:` line (and `caos_status`) shows
which key that is, or that there is none.

To move to a newer caos: `nix flake update caos`, then set every `rev=` in
`.caos-expr` (three: loader, std tree, deep-deps) to the new commit. They must
agree with `flake.lock` — `std/flake-input-loader` refuses the evaluation
otherwise and names both revisions, so this cannot go wrong quietly. Pin only
a commit that already has a published build: the client comes from that
commit's release and the tools resolve through the same rev, so a commit
without one is refused rather than paired with an older client. The
environment then needs its setup script changed before a session installs the
new pin; until it is, every call is blocked with `STALE INSTALL`.

Fork this repository to add your own tools, instructions or pins. Nothing here
is specific to one project.
