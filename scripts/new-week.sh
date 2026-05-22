#!/usr/bin/env bash
# Scaffold a TidyTuesday entry: create year/month/day, fetch the week's CSVs,
# and seed _plot.typ and index.qmd from the templates.
#
# Usage: scripts/new-week.sh <YYYY-MM-DD>
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ $# -ne 1 ]]; then
	echo "Usage: $0 <YYYY-MM-DD>" >&2
	exit 2
fi

date_arg="$1"
if [[ ! "${date_arg}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
	echo "Error: date must be YYYY-MM-DD, got '${date_arg}'." >&2
	exit 2
fi

year="${date_arg:0:4}"
month="${date_arg:5:2}"
day="${date_arg:8:2}"
dir="tidytuesday/${year}/${month}/${day}"

if [[ -e "${dir}" ]]; then
	echo "Error: ${dir} already exists; refusing to overwrite." >&2
	exit 1
fi

repo="rfordatascience/tidytuesday"
api_path="repos/${repo}/contents/data/${year}/${date_arg}"

echo "Listing data files for ${date_arg} ..."
files_json="$(gh api "${api_path}" 2>/dev/null || true)"
if [[ -z "${files_json}" ]] || ! echo "${files_json}" | jq -e 'type == "array"' >/dev/null 2>&1; then
	echo "Error: no TidyTuesday folder found at data/${year}/${date_arg}." >&2
	echo "Hint: 2026 weeks start on 2026-01-13; check the date matches a Monday with data." >&2
	exit 1
fi

mapfile -t csv_names < <(echo "${files_json}" | jq -r '.[] | select(.name | endswith(".csv")) | .name')
if [[ "${#csv_names[@]}" -eq 0 ]]; then
	echo "Error: no CSV files listed for ${date_arg}." >&2
	exit 1
fi

mkdir -p "${dir}/data"

for name in "${csv_names[@]}"; do
	url="$(echo "${files_json}" | jq -r --arg n "${name}" '.[] | select(.name == $n) | .download_url')"
	echo "Downloading ${name} ..."
	curl -fsSL "${url}" -o "${dir}/data/${name}"
done

csv_path="${dir}/data/${csv_names[0]}"
title="TidyTuesday ${date_arg}"
slug="${date_arg}"

sed \
	-e "s|__CSVPATH__|${csv_path}|g" \
	-e "s|__TITLE__|${title}|g" \
	_templates/_plot.typ >"${dir}/_plot.typ"

sed \
	-e "s|__DATE__|${date_arg}|g" \
	-e "s|__YEAR__|${year}|g" \
	-e "s|__TITLE__|${title}|g" \
	-e "s|__SLUG__|${slug}|g" \
	_templates/index.qmd >"${dir}/index.qmd"

echo "Created ${dir} with ${#csv_names[@]} CSV file(s)."
echo "Next: edit ${dir}/_plot.typ column mappings and ${dir}/index.qmd, then run 'quarto preview'."
