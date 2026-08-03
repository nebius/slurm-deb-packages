#!/usr/bin/env bash
set -euo pipefail

usage() {
	printf 'Usage: %s SOURCE_DIR SERIES_FILE [RECORD_FILE]\n' "$0" >&2
	exit 2
}

[[ $# -ge 2 && $# -le 3 ]] || usage

source_dir="$(realpath "$1")"
series_file="$(realpath "$2")"
record_file="${3:-${source_dir}/.slurm-patches.sha256}"
series_dir="$(dirname "${series_file}")"

[[ -d "${source_dir}" ]] || {
	echo "Source directory does not exist: ${source_dir}" >&2
	exit 2
}
[[ -f "${series_file}" ]] || {
	echo "Patch series does not exist: ${series_file}" >&2
	exit 2
}

: >"${record_file}"
while IFS= read -r entry || [[ -n "${entry}" ]]; do
	entry="${entry%%#*}"
	entry="${entry#"${entry%%[![:space:]]*}"}"
	entry="${entry%"${entry##*[![:space:]]}"}"
	[[ -n "${entry}" ]] || continue

	if [[ "${entry}" == */* || "${entry}" == .* ]]; then
		echo "Series entries must be patch basenames: ${entry}" >&2
		exit 2
	fi
	patch_file="${series_dir}/${entry}"
	[[ -f "${patch_file}" ]] || {
		echo "Patch listed by series is missing: ${patch_file}" >&2
		exit 2
	}

	git -C "${source_dir}" apply --check "${patch_file}"
	git -C "${source_dir}" apply "${patch_file}"
	patch_sha="$(sha256sum "${patch_file}" | awk '{print $1}')"
	printf '%s  %s\n' "${patch_sha}" "${entry}" >>"${record_file}"
done <"${series_file}"

echo "Applied patch series ${series_file} to ${source_dir}"
