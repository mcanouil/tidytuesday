#!/usr/bin/env bash
# Fail the render when a figure names a font family that is not available on a
# clean machine.
#
# Typst rasterises text to paths, so a family missing at compile time falls back
# silently: the figure still renders, just in the wrong face. Locally the gap is
# invisible because macOS system fonts satisfy the lookup; on the CI runner
# (which installs no fonts) the same figure ships a fallback. The typst-render
# extension passes --font-path but not --ignore-system-fonts, so nothing else
# catches this.
#
# The check compares every family the figures name against the set a clean
# machine can see: the vendored files in assets/fonts plus the faces embedded in
# the Typst binary. Wired into Quarto's `pre-render` hook (see _quarto.yml), so
# it runs before every `quarto preview` and `quarto render`.
#
# See assets/fonts/README.md for how to vendor a new family.
set -euo pipefail

cd "$(dirname "$0")/.."

sources=(assets/typst/_preamble.typ tidytuesday/20*/*/*/_plot.typ)

# Matches both `#let body-font = "PT Serif"` and `font: "DejaVu Sans Mono"`.
declared="$(
	grep -hoE '(font[a-z-]*)[[:space:]]*[:=][[:space:]]*"[^"]+"' "${sources[@]}" |
		sed -E 's/.*"([^"]+)"/\1/' |
		sort -u
)"

# `quarto typst fonts` writes the family list to stderr, hence the redirection.
available="$(quarto typst fonts --font-path assets/fonts --ignore-system-fonts 2>&1)"

missing=()
while IFS= read -r family; do
	if [[ -n "${family}" ]] && ! printf '%s\n' "${available}" | grep -qixF "${family}"; then
		missing+=("${family}")
	fi
done <<<"${declared}"

if [[ ${#missing[@]} -gt 0 ]]; then
	echo "Missing font families (not vendored in assets/fonts, not embedded in Typst):" >&2
	printf '  - %s\n' "${missing[@]}" >&2
	echo "Vendor them following assets/fonts/README.md, or change the figure to a family that is available." >&2
	exit 1
fi

echo "All $(printf '%s\n' "${declared}" | wc -l | tr -d ' ') font families named by the figures are available."
