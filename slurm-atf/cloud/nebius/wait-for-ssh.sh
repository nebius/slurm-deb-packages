#!/usr/bin/env bash
set -euo pipefail

: "${NEBIUS_CLI_PROFILE:?}"
: "${NEBIUS_VM_ID:?}"
: "${SLURM_ATF_SSH_PRIVATE_KEY_FILE:?}"
: "${SLURM_ATF_SSH_KNOWN_HOSTS_FILE:?}"
: "${SLURM_ATF_SSH_USER:?}"

timeout_seconds="${SLURM_ATF_SSH_WAIT_SECONDS:-1200}"
poll_seconds=10
deadline=$((SECONDS + timeout_seconds))
public_ip=""

ssh_options=(
	-i "${SLURM_ATF_SSH_PRIVATE_KEY_FILE}"
	-o BatchMode=yes
	-o ConnectTimeout=10
	-o ServerAliveInterval=30
	-o ServerAliveCountMax=6
	-o StrictHostKeyChecking=accept-new
	-o "UserKnownHostsFile=${SLURM_ATF_SSH_KNOWN_HOSTS_FILE}"
)

while ((SECONDS < deadline)); do
	instance_json="$(
		nebius compute instance get \
			--profile "${NEBIUS_CLI_PROFILE}" \
			--no-progress \
			--format json \
			--timeout=1m \
			--id "${NEBIUS_VM_ID}" 2>/dev/null || true
	)"
	public_ip="$(
		jq -r \
			'.status.network_interfaces[0].public_ip_address.address // "" | split("/")[0]' \
			<<<"${instance_json}" 2>/dev/null || true
	)"
	if [[ -n "${public_ip}" ]] &&
		ssh "${ssh_options[@]}" \
			"${SLURM_ATF_SSH_USER}@${public_ip}" true >/dev/null 2>&1; then
		break
	fi
	sleep "${poll_seconds}"
done

if [[ -z "${public_ip}" ]] || ((SECONDS >= deadline)); then
	echo "Timed out waiting for SSH on Nebius VM ${NEBIUS_VM_ID}" >&2
	exit 1
fi

timeout 10m ssh "${ssh_options[@]}" "${SLURM_ATF_SSH_USER}@${public_ip}" \
	'sudo cloud-init status --wait && sudo test -f /etc/slurm-atf-disposable && sudo -n true' \
	>&2

printf '%s\n' "${public_ip}"
