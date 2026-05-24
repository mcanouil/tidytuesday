#!/usr/bin/env bash
# Install the development build of Gribouille into Typst's `local` package
# namespace under a constant version, so the import never has to change.
#
# Typst requires a semver version in `@local` imports and rejects non-numeric
# strings such as "dev", so the build is pinned to 0.0.0: its typst.toml version
# is rewritten on install and the import stays `@local/gribouille:0.0.0`.
#
# Wired into Quarto's `pre-render` hook (see _quarto.yml), so it runs before
# every `quarto preview` and `quarto render` (locally and in CI). The social
# card (assets/typst/social-card.typ) intentionally stays on the @preview
# release, so it is not touched here.
#
# Skips the download when 0.0.0 is already installed; set GRIBOUILLE_FORCE_UPDATE=1
# to fetch the latest build. CI runners start clean, so they always fetch it.
set -euo pipefail

cd "$(dirname "$0")/.."

url="https://m.canouil.dev/gribouille/dev/gribouille.tar.gz"
preamble="assets/typst/_preamble.typ"
version="0.0.0"

case "$(uname -s)" in
Darwin) base="${HOME}/Library/Application Support/typst/packages/local" ;;
*) base="${XDG_DATA_HOME:-${HOME}/.local/share}/typst/packages/local" ;;
esac

dest="${base}/gribouille/${version}"

if [[ "${GRIBOUILLE_FORCE_UPDATE:-0}" != "1" && -d "${dest}" ]]; then
	echo "Gribouille ${version} already installed; skipping (set GRIBOUILLE_FORCE_UPDATE=1 to refresh)."
	exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT

echo "Downloading Gribouille development build ..."
curl -fLsS "${url}" -o "${tmp}/gribouille.tar.gz"
mkdir -p "${tmp}/extract"
tar -xzf "${tmp}/gribouille.tar.gz" --strip-components=1 -C "${tmp}/extract"

build="$(sed -n 's|^# dev build: \(.*\)|\1|p' "${tmp}/extract/typst.toml" | head -1)"

sed -i.bak -E "s|^version *= *\"[^\"]*\"|version = \"${version}\"|" "${tmp}/extract/typst.toml"
rm -f "${tmp}/extract/typst.toml.bak"

rm -rf "${dest}"
mkdir -p "${dest}"
cp -R "${tmp}/extract/." "${dest}/"

sed -i.bak -E "s#@(preview|local)/gribouille:[0-9.]+#@local/gribouille:${version}#" "${preamble}"
rm -f "${preamble}.bak"

echo "Gribouille ${version} installed at ${dest} (build ${build:-unknown})."
