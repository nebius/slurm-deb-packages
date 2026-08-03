from __future__ import annotations

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
CREATE_SCRIPT = REPO_ROOT / "slurm-atf/cloud/nebius/create-vm.sh"
DELETE_SCRIPT = REPO_ROOT / "slurm-atf/cloud/nebius/delete-vm.sh"
WAIT_SCRIPT = REPO_ROOT / "slurm-atf/cloud/nebius/wait-for-ssh.sh"


class NebiusVmScriptTests(unittest.TestCase):
    def fake_nebius(self, directory: Path) -> tuple[Path, Path]:
        binary = directory / "nebius"
        arguments = directory / "arguments"
        binary.write_text(
            "#!/usr/bin/env bash\n"
            "printf '%s\\0' \"$@\" >\"${NEBIUS_ARGS_FILE}\"\n"
            "printf '%s\\n' '{\"metadata\":{\"id\":\"computeinstance-test\"}}'\n",
            encoding="utf-8",
        )
        binary.chmod(0o755)
        return binary, arguments

    @staticmethod
    def option(arguments: list[str], name: str) -> str:
        index = arguments.index(name)
        return arguments[index + 1]

    def test_create_uses_selected_profile_managed_disk_and_cloud_init_key(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            _, arguments_path = self.fake_nebius(directory)
            public_key_path = directory / "id_ed25519.pub"
            public_key_path.write_text(
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITest ci@example\n",
                encoding="utf-8",
            )
            env = {
                **os.environ,
                "PATH": f"{directory}:{os.environ['PATH']}",
                "NEBIUS_ARGS_FILE": str(arguments_path),
                "NEBIUS_CLI_PROFILE": "atf-project",
                "NEBIUS_PROJECT_ID": "project-test",
                "NEBIUS_SUBNET_ID": "subnet-test",
                "NEBIUS_SECURITY_GROUP_ID": "security-group-test",
                "NEBIUS_VM_NAME": "slurm-atf-123-1",
                "NEBIUS_VM_PLATFORM": "cpu-d3",
                "NEBIUS_VM_PRESET": "32vcpu-128gb",
                "NEBIUS_VM_IMAGE_ID": "image-test",
                "NEBIUS_VM_BOOT_DISK_GIB": "512",
                "NEBIUS_VM_BOOT_DISK_TYPE": "network_ssd",
                "SLURM_ATF_SSH_USER": "slurm-atf-ci",
                "SLURM_ATF_SSH_PUBLIC_KEY_FILE": str(public_key_path),
            }
            result = subprocess.run(
                ["bash", str(CREATE_SCRIPT)],
                env=env,
                text=True,
                capture_output=True,
                check=True,
            )
            self.assertEqual(
                json.loads(result.stdout)["metadata"]["id"],
                "computeinstance-test",
            )
            arguments = arguments_path.read_bytes().decode().rstrip("\0").split("\0")
            self.assertEqual(arguments[:3], ["compute", "instance", "create"])
            self.assertEqual(self.option(arguments, "--profile"), "atf-project")
            self.assertEqual(
                self.option(arguments, "--boot-disk-managed-disk-source-image-id"),
                "image-test",
            )
            self.assertIn("--boot-disk-managed-disk-forbid-deletion=false", arguments)

            cloud_init = self.option(arguments, "--cloud-init-user-data")
            self.assertIn("/etc/slurm-atf-disposable", cloud_init)
            self.assertIn("ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITest", cloud_init)
            network = json.loads(self.option(arguments, "--network-interfaces"))
            self.assertEqual(network[0]["subnet_id"], "subnet-test")
            self.assertEqual(
                network[0]["security_groups"], [{"id": "security-group-test"}]
            )
            self.assertEqual(network[0]["public_ip_address"], {})

    def test_delete_uses_explicit_vm_id_and_selected_profile(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            _, arguments_path = self.fake_nebius(directory)
            env = {
                **os.environ,
                "PATH": f"{directory}:{os.environ['PATH']}",
                "NEBIUS_ARGS_FILE": str(arguments_path),
                "NEBIUS_CLI_PROFILE": "atf-project",
                "NEBIUS_PROJECT_ID": "project-test",
                "NEBIUS_VM_NAME": "slurm-atf-123-1",
                "NEBIUS_VM_ID": "computeinstance-test",
            }
            subprocess.run(
                ["bash", str(DELETE_SCRIPT)],
                env=env,
                text=True,
                capture_output=True,
                check=True,
            )
            arguments = arguments_path.read_bytes().decode().rstrip("\0").split("\0")
            self.assertEqual(arguments[:3], ["compute", "instance", "delete"])
            self.assertEqual(self.option(arguments, "--profile"), "atf-project")
            self.assertEqual(self.option(arguments, "--id"), "computeinstance-test")

    def test_wait_resolves_public_ip_and_checks_cloud_init_over_ssh(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            nebius = directory / "nebius"
            nebius.write_text(
                "#!/usr/bin/env bash\n"
                "printf '%s\\0' \"$@\" >\"${NEBIUS_ARGS_FILE}\"\n"
                "printf '%s\\n' "
                "'{\"status\":{\"network_interfaces\":[{\"public_ip_address\":{\"address\":\"203.0.113.10/32\"}}]}}'\n",
                encoding="utf-8",
            )
            nebius.chmod(0o755)
            ssh = directory / "ssh"
            ssh.write_text(
                "#!/usr/bin/env bash\n"
                "printf '%s\\0' \"$@\" >>\"${SSH_ARGS_FILE}\"\n",
                encoding="utf-8",
            )
            ssh.chmod(0o755)
            arguments_path = directory / "nebius-arguments"
            ssh_arguments_path = directory / "ssh-arguments"
            private_key_path = directory / "id_ed25519"
            known_hosts_path = directory / "known_hosts"
            private_key_path.touch()
            known_hosts_path.touch()
            env = {
                **os.environ,
                "PATH": f"{directory}:{os.environ['PATH']}",
                "NEBIUS_ARGS_FILE": str(arguments_path),
                "SSH_ARGS_FILE": str(ssh_arguments_path),
                "NEBIUS_CLI_PROFILE": "atf-project",
                "NEBIUS_VM_ID": "computeinstance-test",
                "SLURM_ATF_SSH_PRIVATE_KEY_FILE": str(private_key_path),
                "SLURM_ATF_SSH_KNOWN_HOSTS_FILE": str(known_hosts_path),
                "SLURM_ATF_SSH_USER": "slurm-atf-ci",
                "SLURM_ATF_SSH_WAIT_SECONDS": "10",
            }
            result = subprocess.run(
                ["bash", str(WAIT_SCRIPT)],
                env=env,
                text=True,
                capture_output=True,
                check=True,
            )
            self.assertEqual(result.stdout.strip(), "203.0.113.10")
            arguments = arguments_path.read_bytes().decode().rstrip("\0").split("\0")
            self.assertEqual(self.option(arguments, "--profile"), "atf-project")
            self.assertEqual(self.option(arguments, "--id"), "computeinstance-test")
            ssh_arguments = ssh_arguments_path.read_bytes().decode()
            self.assertIn("slurm-atf-ci@203.0.113.10", ssh_arguments)
            self.assertIn("cloud-init status --wait", ssh_arguments)


if __name__ == "__main__":
    unittest.main()
