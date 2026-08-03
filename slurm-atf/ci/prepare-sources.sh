#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../.." && pwd)"
manifest="${1:?usage: prepare-sources.sh RELEASE_MANIFEST [PATCHSET]}"
patchset="${2:-baseline}"
atf_root="${SLURM_ATF_ROOT:-/opt/slurm-atf}"

manifest="$(realpath "${manifest}")"
python3 "${script_dir}/manifest.py" --repo-root "${repo_root}" \
	validate "${manifest}" >/dev/null

version="$(jq -r '.release.version' "${manifest}")"
release_url="$(jq -r '.release.tarball_url' "${manifest}")"
release_sha="$(jq -r '.release.tarball_sha256' "${manifest}")"
tests_url="$(jq -r '.tests.snapshot_url' "${manifest}")"
tests_sha="$(jq -r '.tests.snapshot_sha256' "${manifest}")"
harness_series="$(jq -r '.tests.harness_series' "${manifest}")"

if [[ "${patchset}" == baseline ]]; then
	product_series="$(jq -r '.product.baseline_series' "${manifest}")"
else
	product_series="slurm-packages/patches/${version}/${patchset}/series"
fi
[[ -f "${repo_root}/${product_series}" ]] || {
	echo "Unknown product patchset ${patchset}: ${product_series}" >&2
	exit 2
}

work_dir="$(mktemp -d)"
trap 'rm -rf "${work_dir}"' EXIT
release_archive="${work_dir}/slurm-release.tar.bz2"
tests_archive="${work_dir}/slurm-tests.tar.gz"

download_and_verify() {
	local url="$1"
	local expected="$2"
	local destination="$3"
	curl --fail --location --retry 5 --retry-all-errors \
		--output "${destination}" "${url}"
	echo "${expected}  ${destination}" | sha256sum -c -
}

download_and_verify "${release_url}" "${release_sha}" "${release_archive}"
download_and_verify "${tests_url}" "${tests_sha}" "${tests_archive}"
chmod 0755 "${work_dir}"
chmod 0644 "${release_archive}" "${tests_archive}"

sut_source="${atf_root}/sut/src"
tests_master="${atf_root}/tests/master"
tests_common="${atf_root}/tests/common"
for directory in "${sut_source}" "${tests_master}" "${tests_common}"; do
	sudo install -d -o atf -g atf -m 0755 "${directory}"
	sudo find "${directory}" -mindepth 1 -delete
done

sudo -u atf tar -xjf "${release_archive}" --strip-components=1 \
	-C "${sut_source}"
sudo -u atf tar -xzf "${tests_archive}" --strip-components=1 \
	-C "${tests_master}"
sudo -u atf rsync -a --delete "${tests_master}/" "${tests_common}/"

meta_version="$(awk '$1 == "Version:" {print $2; exit}' "${sut_source}/META")"
if [[ "${meta_version}" != "${version}" ]]; then
	echo "Release META says ${meta_version}; manifest says ${version}" >&2
	exit 1
fi
[[ -x "${tests_common}/testsuite/python/run-tests-python" ]] || {
	echo "Pinned tests snapshot has no Python testsuite" >&2
	exit 1
}

sudo -u atf "${repo_root}/slurm-packages/apply-patch-series.sh" \
	"${sut_source}" "${repo_root}/${product_series}" \
	"${sut_source}/.product-patches.sha256"
sudo -u atf "${repo_root}/slurm-packages/apply-patch-series.sh" \
	"${tests_common}" "${repo_root}/${harness_series}" \
	"${tests_common}/.harness-patches.sha256"

sudo install -d -o atf -g atf -m 0755 "${atf_root}/metadata"
jq -n \
	--arg manifest "${manifest}" \
	--arg version "${version}" \
	--arg patchset "${patchset}" \
	--arg release_sha256 "${release_sha}" \
	--arg tests_sha256 "${tests_sha}" \
	'{manifest: $manifest, version: $version, patchset: $patchset,
      release_sha256: $release_sha256, tests_sha256: $tests_sha256}' |
	sudo -u atf tee "${atf_root}/metadata/sources.json" >/dev/null

echo "Prepared Slurm ${version} (${patchset}) and pinned master tests."
