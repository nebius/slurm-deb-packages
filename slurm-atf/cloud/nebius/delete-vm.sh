#!/usr/bin/env bash
set -euo pipefail

: "${NEBIUS_CLI_PROFILE:?}"
: "${NEBIUS_PROJECT_ID:?}"
: "${NEBIUS_VM_NAME:?}"

vm_id="${NEBIUS_VM_ID:-}"
if [[ -z "${vm_id}" ]]; then
	vm_id="$(
		nebius compute instance get-by-name \
			--profile "${NEBIUS_CLI_PROFILE}" \
			--no-progress \
			--format json \
			--timeout=1m \
			--parent-id "${NEBIUS_PROJECT_ID}" \
			--name "${NEBIUS_VM_NAME}" 2>/dev/null |
			jq -r '.metadata.id // empty'
	)" || true
fi

if [[ -z "${vm_id}" ]]; then
	echo "Nebius VM ${NEBIUS_VM_NAME} does not exist; nothing to delete."
	exit 0
fi

nebius compute instance delete \
	--profile "${NEBIUS_CLI_PROFILE}" \
	--no-progress \
	--timeout=20m \
	--id "${vm_id}"

echo "Deleted Nebius VM ${NEBIUS_VM_NAME} (${vm_id}) and its managed boot disk."
