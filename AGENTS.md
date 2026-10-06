# Working in this session

This repository is not the code you are here to change. It is the **client
repo**: a handful of text files that say which caos this session uses and
which tools it offers. The code you work on is **imported into the
conversation**, not checked out onto disk.

That is the one thing to internalise before your first tool call. Your file
tools do not read this container's filesystem — they read the conversation
tree, which starts out holding almost nothing.

List it with `ls` (with no path it lists the root). A fresh conversation holds
`.caos/` and this client repo's own handful of files (`AGENTS.md`, `flake.nix`,
`.caos-expr` and so on) — no code to work on. That is what it is supposed to
look like, not a sign that anything went wrong.

## Start by importing what you were asked to work on

When the user names a repository, import it:

```
import_source(source="https://github.com/<owner>/<repo>.git",
              revision="main",
              into="sources/<repo>/00-base")
```

The server fetches it directly from GitHub — nothing is cloned into this
container and nothing is uploaded from it, so a large repository costs about
the same as a small one. Omit `revision` for the default branch. Public
repositories need no credentials.

Everything for one repo lives in a single directory, `sources/<repo>/`. Do not
use a separate `imports/` directory. Copy the base to a scratch layer, edit
that, and `move` it to a named layer when a chunk of work is finished:

```
copy(from="sources/<repo>/00-base", to="sources/<repo>/99-dirty")
... edit sources/<repo>/99-dirty ...
move(from="sources/<repo>/99-dirty", to="sources/<repo>/01-<name>")
```

Never edit `00-base`: it is the record of where you started, and any later
diff, merge or publication is measured against it. Only `00-base` has a
`.source.json` provenance file beside it; leave that alone too. (Replacing the
base with a newer upstream tip is the one case that touches it; `GIT.md` shows
how.)

This is only the short version. For stacks of layers, updating the base,
merging, squashing, publishing, PRs and creating a new repo, read
`caos-std/GIT.md` first:
`read(root=<hash from eval_path("caos-std")>, file-path="GIT.md")`.

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
tools are switched off, so there is no second set to choose between. Two kinds:

**Registered tools**, called by name:

- `read` / `ls` / `grep` — read the conversation tree.
- `write` / `edit` — change a file. Every accepted change records a child
  commit automatically; there is no staging step and nothing to commit by hand.
- `copy` / `move` / `remove` — copy, move or delete a file or directory. A
  source tree stays a source tree. `copy` and `move` create missing parent
  directories and refuse an existing destination.
- `import_source` — above.
- `merge` — merge a commit into a source tree.
- `publish_source` — push a source tree's commit to a branch on GitHub.
- `log` / `show` / `diff` — a source tree's git history. There is no `git` in
  the shell; these are how you see history and changes.

**Std tools**, reached by path with `run_tool(path="caos-std/<name>",
arguments={...})`. There is no `bash` tool by name; shell is one of these.
`tool_help(path="caos-std/<name>")` prints a tool's parameters. `caos-std/`
exists only in the evaluated tree, so `read` and `ls` cannot see it directly:
`eval_path(path="caos-std")` returns a tree hash, and
`read(root=<hash>, file-path="README.md")` is the index of every std tool. The
ones you will want:

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
  scratch files, and `publish_source` rejects `.`.

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

## Fork-specific instructions

This is a fork. Read `FORK.md` at the conversation root before your first other
tool call; it adds memory and tools on top of everything here.
