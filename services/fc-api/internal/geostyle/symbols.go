package geostyle

import (
	"embed"
	"path"
	"strings"
)

//go:embed symbols/*.svg
var symbolFS embed.FS

// SymbolSVG returns the raw SVG for a geo symbol name (e.g. "transformer").
func SymbolSVG(name string) (string, bool) {
	name = strings.TrimSpace(name)
	if name == "" {
		return "", false
	}
	// Strip accidental extensions / paths
	name = strings.TrimSuffix(name, ".svg")
	name = path.Base(name)

	data, err := symbolFS.ReadFile("symbols/" + name + ".svg")
	if err != nil {
		return "", false
	}
	return string(data), true
}

// SymbolNames lists embedded geo symbol names (without .svg).
func SymbolNames() []string {
	entries, err := symbolFS.ReadDir("symbols")
	if err != nil {
		return nil
	}
	out := make([]string, 0, len(entries))
	for _, e := range entries {
		if e.IsDir() {
			continue
		}
		n := e.Name()
		if strings.HasSuffix(n, ".svg") {
			out = append(out, strings.TrimSuffix(n, ".svg"))
		}
	}
	return out
}
