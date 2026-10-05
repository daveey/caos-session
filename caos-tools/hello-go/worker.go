// caos-tools/hello-go's worker: greet whoever `name` says. Its docs live in
// the sibling `.caos-expr` here-string, not here.
//
// The runner starts this with /cas set up and the arguments under
// /cas/args, one file per parameter, fetched on demand with `caos get`. The
// result is whatever lands at /cas/out, which w.Report writes.
package main

import (
	"os"
	"os/exec"
	"strings"

	"caos/w"
)

// arg reads an argument, or reports it absent.
func arg(name string) (string, bool) {
	path := "/cas/args/" + name
	if _, err := os.Stat(path); err != nil {
		return "", false
	}
	out, err := exec.Command("caos", "get", path).CombinedOutput()
	w.True(err == nil, "caos get %s: %v: %s", path, err, out)
	return string(w.Check(os.ReadFile(path))), true
}

func main() {
	w.Main(func() {
		name := "world"
		if v, ok := arg("name"); ok && strings.TrimSpace(v) != "" {
			name = strings.TrimSpace(v)
		}
		w.Report("Hello, " + name + "!\n")
	})
}
