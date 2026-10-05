# A caos client repo

The tree an agent session starts from when it works through caos. It holds no
code of its own: a pin saying which caos to use, an expression mounting caos'
`std/`, the instructions the agent reads, and whatever tools you choose to add.

**The repository you actually want to change is imported into the
conversation, not cloned here.** That is the point of the arrangement. The
caos server fetches it from GitHub directly, so starting work on a large
repository costs no clone, no history fetch and no upload — a session on a
100k-commit repo begins as fast as one on an empty repo.

## Using it

Fork this directory into a repository of its own, then point a Claude Code
cloud environment at it:

- **Repository**: your fork.
- **Setup script**: these lines, with your server's ticket and your secret
  store's key filled in —

  ```
  echo last modified 2026-10-05
  B=https://raw.githubusercontent.com/Metta-AI/caos/main
  curl -fsSL "$B/integrations/claude-code/cloud/bootstrap.go" -o /tmp/caos-bootstrap.go
  go run /tmp/caos-bootstrap.go --base="$B" --server=caos://<ticket> --secret-readers=<key>
  ```

  `--base` only says where the *bootstrap scripts* come from. The caos that
  actually gets installed is the one **your fork pins**, which the setup
  script reads out of `flake.lock` before installing anything.

  `--server` is the `caos://…` ticket `caosd ticket` prints on the machine
  running your server. It is a credential: whoever holds it can drive that
  server. It goes here and nowhere else — `CAOS_SERVER_URL` is not read, and
  the environment needs no variables.

  The `echo` line does nothing but change the script's text, which is what
  makes an environment re-run setup (see *Moving the pin*).

- **Secrets** (a GitHub token for private repositories or for publishing)
  are not environment variables and are not in this repo. They live in your
  secret store on the caos server, pushed with `caos-cli secrets-push`, and
  the setup line's `--secret-readers=<key>` names it — the key
  `caos-cli secrets-init` printed. It is a credential too. See caos' README,
  "Secrets".

Then start a session and say what to work on: *"import owner/repo and fix the
flaky test in its scheduler"*.

## Moving the pin

```sh
nix flake update caos
```

then set every `rev=` in `.caos-expr` (three of them: the loader, the std tree
it splices, and the deep-deps line) to the commit `flake.lock` now records.
They must match: `std/flake-input-loader` compares them and refuses the
evaluation if any differs, naming both revisions.

**Then change the environment's setup script** — bumping the date on its
`echo` line is enough. An environment caches its setup and re-runs it only
when the script's text changes, while it fetches this repo before every
session; so a pushed re-pin moves the checkout and leaves the installed client
behind. The session hook notices — it prints `STALE INSTALL`, naming both
revisions, and blocks every call — rather than running a client from one caos
against tools from another. It cannot install the new pin itself: Claude Code
has already started on the old files by the time it runs.

**Pin a commit that already has a published build.** The client is downloaded
from that commit's release, while the tools resolve through the same rev, so
the two are one choice — and a commit whose build has not landed is refused
rather than paired with an older client. If you are moving the pin to your own
caos branch: push it, wait for the workflow to publish `build-<commit>`, and
re-pin after. `gh run list --branch <branch>` says when.

## What each file does

```
flake.nix / flake.lock   the pin: which caos, by commit
.caos-expr               mounts caos' std/ at caos-std/ (evaluated only, never on disk),
                         then resolves this repo's own DEPS files
AGENTS.md                what the agent is told at the start of every session
.gitignore               /caos-std/, which must not exist as a real directory
caos-tools/              this repo's own tools; hello-go is the worked example
.github/                 the upstream-sync workflow (below)
```

## Your own tools

Add a directory under `caos-tools/` and the agent is offered it alongside the
standard set, as `caos-tools/<name>`. Nothing is built here or by you: the
server builds a tool the first time it is evaluated and caches it by content.

`caos-tools/hello-go` is the smallest one, and the pattern for any other Go
tool:

```
caos-tools/hello-go/
  .caos-expr   HELP here-string + `curry --base:@=DEEP-DEPS/go --worker1:@=worker.go --help=$HELP`
  DEPS         `../../caos-std/go go`
  worker.go    one Go file; `import "caos/w"` for Main/Check/True/Report
```

The one thing that is not obvious: a tool's expression is evaluated against
its own directory and cannot name anything outside it, so `../../caos-std/go`
does not work as a `--base`. The dependency is declared in `DEPS` instead and
caos' deep-deps worker — chained as the second line of the root `.caos-expr` —
mounts it at `DEEP-DEPS/go` inside the tool before the tool is evaluated. A
Rust tool is the same shape with `../../caos-std/rustc rustc` in `DEPS`,
`Cargo.toml` + `src/`, and `run --base:@=DEEP-DEPS/rustc --src:@=.`; caos'
own `std/hello` and `std/bash-tool` are the models.

Try it in a session:

```
tool_help(path="caos-tools/hello-go")
run_tool(path="caos-tools/hello-go", arguments={"name": "caos"})   → Hello, caos!
```

`tool_help` builds the tool and prints its parameters, so it is also the
quickest check that a new tool's expression is well-formed.

## Staying in sync with upstream

A fork drifts from this repository as the pin and the instructions move.
`.github/workflows/sync-upstream.yml` rebases the fork's branch onto upstream
every day (and on demand from the Actions tab), and force-pushes the result.
Where the rebase stops on a conflict, the driver
`.github/sync-upstream/rebase.sh` hands the conflicted files to the Claude
Code CLI with `.github/sync-upstream/PROMPT.md` as its brief, checks that no
markers remain, and continues; a commit the model cannot merge aborts the
rebase and fails the job without pushing anything.

To turn it on in your fork:

- **`ANTHROPIC_API_KEY`** as a repository secret. It is used only when a
  conflict actually occurs; a clean rebase needs no model.
- **`UPSTREAM_REPO`** / **`UPSTREAM_BRANCH`** as repository variables if the
  upstream is not `Metta-AI/caos-session` `main`.
- The synced branch must allow force-pushes from `GITHUB_TOKEN`; the push is
  lease-guarded, so a commit that lands during a run is never overwritten,
  and the next run picks it up.

In this repository itself the workflow skips, since there is nothing to
rebase onto. The repo-specific merge rules (take upstream's `flake.lock`, keep
every `rev=` in `.caos-expr` equal to it, keep both sides' `caos-tools/`) live
in `PROMPT.md`; edit that file to teach it about your own files.
