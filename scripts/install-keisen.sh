#!/usr/bin/env bash
# Install the development build of keisen into Typst's `local` package
# namespace under a constant version, so the import never has to change.
#
# Typst requires a semver version in `@local` imports, so the build is pinned
# to 0.0.0: its typst.toml version is rewritten on install and the import is
# `@local/keisen:0.0.0`.
#
# Wired into Quarto's `pre-render` hook (see _quarto.yml), so it runs before
# every `quarto preview` and `quarto render` (locally and in CI).
#
# Skips the download when 0.0.0 is already installed; set KEISEN_FORCE_UPDATE=1
# to fetch the latest build. CI runners start clean, so they always fetch it.
set -euo pipefail

cd "$(dirname "$0")/.."

url="https://codeload.github.com/mcanouil/keisen/tar.gz/refs/heads/main"
api="https://api.github.com/repos/mcanouil/keisen/commits/main"
version="0.0.0"

case "$(uname -s)" in
Darwin) base="${HOME}/Library/Application Support/typst/packages/local" ;;
*) base="${XDG_DATA_HOME:-${HOME}/.local/share}/typst/packages/local" ;;
esac

dest="${base}/keisen/${version}"

if [[ "${KEISEN_FORCE_UPDATE:-0}" != "1" && -d "${dest}" ]] && grep -qs '^keisen-version: ' "_variables.yml"; then
	echo "keisen ${version} already installed; skipping (set KEISEN_FORCE_UPDATE=1 to refresh)."
	exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT

echo "Downloading keisen development build ..."
curl -fLsS "${url}" -o "${tmp}/keisen.tar.gz"
mkdir -p "${tmp}/extract"
tar -xzf "${tmp}/keisen.tar.gz" --strip-components=1 -C "${tmp}/extract"

sha="$(curl -fLsS -H "Accept: application/vnd.github.sha" "${api}")"
build="${sha:0:7}"
keisen_version="main (build \`${build:-unknown}\`)"
{
	grep -vs '^keisen-version: ' "_variables.yml" || true
	printf 'keisen-version: "%s"\n' "${keisen_version}"
} >"${tmp}/_variables.yml"
mv "${tmp}/_variables.yml" "_variables.yml"

sed -i.bak -E "s|^version *= *\"[^\"]*\"|version = \"${version}\"|" "${tmp}/extract/typst.toml"
rm -f "${tmp}/extract/typst.toml.bak"

rm -rf "${dest}"
mkdir -p "${dest}"
cp -R "${tmp}/extract/." "${dest}/"

echo "keisen ${version} installed at ${dest} (build ${build:-unknown})."
