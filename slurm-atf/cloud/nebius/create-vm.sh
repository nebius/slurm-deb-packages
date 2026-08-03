#!/usr/bin/env bash
set -euo pipefail

required_variables=(
	NEBIUS_CLI_PROFILE
	NEBIUS_PROJECT_ID
	NEBIUS_SUBNET_ID
	NEBIUS_VM_NAME
	NEBIUS_VM_PLATFORM
	NEBIUS_VM_PRESET
	NEBIUS_VM_IMAGE_ID
	NEBIUS_VM_BOOT_DISK_GIB
	NEBIUS_VM_BOOT_DISK_TYPE
	SLURM_ATF_SSH_USER
	SLURM_ATF_SSH_PUBLIC_KEY_FILE
)

for variable in "${required_variables[@]}"; do
	if [[ -z "${!variable:-}" ]]; then
		echo "Required environment variable is empty: ${variable}" >&2
		exit 2
	fi
done

command -v jq >/dev/null
command -v nebius >/dev/null

[[ "${NEBIUS_VM_NAME}" =~ ^[a-z][a-z0-9-]{0,62}$ ]] || {
	echo "Invalid Nebius VM name: ${NEBIUS_VM_NAME}" >&2
	exit 2
}
[[ "${SLURM_ATF_SSH_USER}" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || {
	echo "Invalid SSH user: ${SLURM_ATF_SSH_USER}" >&2
	exit 2
}
[[ "${NEBIUS_VM_BOOT_DISK_GIB}" =~ ^[1-9][0-9]*$ ]] || {
	echo "Boot disk size must be a positive integer" >&2
	exit 2
}
[[ -s "${SLURM_ATF_SSH_PUBLIC_KEY_FILE}" ]] || {
	echo "SSH public key file is empty" >&2
	exit 2
}

ssh_public_key="$(<"${SLURM_ATF_SSH_PUBLIC_KEY_FILE}")"
[[ "${ssh_public_key}" != *$'\n'* ]]
[[ "${ssh_public_key}" =~ ^ssh-(ed25519|rsa|ecdsa-[^[:space:]]+)[[:space:]]+[^[:space:]]+([[:space:]].*)?$ ]] || {
	echo "Unsupported SSH public key format" >&2
	exit 2
}

cloud_init="$(
	jq -rn \
		--arg user "${SLURM_ATF_SSH_USER}" \
		--arg key "${ssh_public_key}" \
		'"#cloud-config\n" +
		 "package_update: false\n" +
		 "ssh_pwauth: false\n" +
		 "users:\n" +
		 "  - name: " + ($user | tojson) + "\n" +
		 "    shell: /bin/bash\n" +
		 "    sudo: ALL=(ALL) NOPASSWD:ALL\n" +
		 "    lock_passwd: true\n" +
		 "    ssh_authorized_keys:\n" +
		 "      - " + ($key | tojson) + "\n" +
		 "write_files:\n" +
		 "  - path: /etc/slurm-atf-disposable\n" +
		 "    owner: root:root\n" +
		 "    permissions: \"0644\"\n" +
		 "    content: \"created-by-github-actions\\n\"\n"'
)"

network_interfaces="$(
	jq -cn \
		--arg subnet_id "${NEBIUS_SUBNET_ID}" \
		--arg security_group_id "${NEBIUS_SECURITY_GROUP_ID:-}" \
		'[
		  {
		    name: "eth0",
		    subnet_id: $subnet_id,
		    ip_address: {},
		    public_ip_address: {}
		  }
		  | if $security_group_id == "" then .
		    else .security_groups = [{id: $security_group_id}]
		    end
		]'
)"

exec nebius compute instance create \
	--profile "${NEBIUS_CLI_PROFILE}" \
	--no-progress \
	--format json \
	--timeout=20m \
	--parent-id "${NEBIUS_PROJECT_ID}" \
	--name "${NEBIUS_VM_NAME}" \
	--hostname "${NEBIUS_VM_NAME}" \
	--stopped=false \
	--resources-platform "${NEBIUS_VM_PLATFORM}" \
	--resources-preset "${NEBIUS_VM_PRESET}" \
	--boot-disk-attach-mode read_write \
	--boot-disk-device-id boot \
	--boot-disk-managed-disk-name "${NEBIUS_VM_NAME}-boot" \
	--boot-disk-managed-disk-size-gibibytes "${NEBIUS_VM_BOOT_DISK_GIB}" \
	--boot-disk-managed-disk-source-image-id "${NEBIUS_VM_IMAGE_ID}" \
	--boot-disk-managed-disk-type "${NEBIUS_VM_BOOT_DISK_TYPE}" \
	--boot-disk-managed-disk-forbid-deletion=false \
	--cloud-init-user-data "${cloud_init}" \
	--network-interfaces "${network_interfaces}"
