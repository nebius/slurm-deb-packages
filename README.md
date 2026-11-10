# Slurm Debian Package Builder

This repository automates the process of building Debian packages for [Slurm](https://www.schedmd.com/slurm/why-slurm/) and [NVIDIA NCCL](https://github.com/NVIDIA/nccl). It also builds binary files for running [NCCL tests](https://github.com/NVIDIA/nccl-tests).

Slurm is built using default options, with support for some additional libraries, such as [OpenPMIx (v5)](https://github.com/openpmix/openpmix).

The `Build slurm packages` workflow builds the maintained upstream `25.11.*`
release and Nebius Slurm `26.05.4-nebius-3` from one build matrix. The Nebius
source comes from the [Nebius Slurm fork](https://github.com/nebius/slurm) and
uses the immutable `slurm-26-05-4-nebius-3` release.

Every source uses distinct artifact names and GitHub release tags. Debian package
versions come from the source archive's `debian/changelog`; the packaging workflow
does not rewrite source metadata.

For the Nebius release, run `Build slurm packages` from the branch containing the
updated matrices. The expected GitHub release is
`slurm-packages-ubuntu24.04-26.05.4-nebius-3`. Check every downloaded DEB with:

```bash
dpkg-deb -f package.deb Package Version Architecture
```

All packages must report version `26.05.4-nebius-3`, with packages for `amd64`,
`arm64`, and architecture-independent packages marked `all`.

Publish this release through the [TeamCity SlurmPackages build](https://teamcity.nebius.dev/buildConfiguration/IdpSched_Soperator_PackageSync_SlurmPackages)
with `env.SLURM_VERSION=26.05.4-nebius-3` and `env.UBUNTU_VERSION=24.04`.
Wait for the exact version to appear in the public APT `noble/main` indexes for
both architectures, including the architecture-independent packages. Published
`nebius-1` packages must remain unchanged; do not overwrite them.

The Pyxis workflow builds the SPANK plugin against every supported Slurm
development package. Add each Nebius Slurm release to the Pyxis matrix as well,
using its exact Debian version (`26.05.4-nebius-3` for this release). Other ancillary
packages built in this repository do not compile or link against Slurm.
Run the Slurm package workflow and wait for those packages to reach the public
APT repository before starting Pyxis, which installs the exact listed version.

## Overview

Slurm is a highly scalable cluster management and job scheduling system for Linux clusters. To facilitate its installation and integration into Debian-based systems, this repository provides automated scripts to build `.deb` packages for Slurm and some of its key dependencies, including OpenPMIx and NCCL.

Additionally, binary files for running NCCL tests are built to verify and benchmark the performance of the NCCL library in various configurations.

### Installing packages from the Nebius public repository

1. **Add the public key and repository**

   ```bash
   sudo curl -fsSL https://dr.nebius.cloud/public.gpg -o /usr/share/keyrings/nebius.gpg.pub

   echo "deb [signed-by=/usr/share/keyrings/nebius.gpg.pub] https://dr.nebius.cloud/ stable main" | \
     sudo tee /etc/apt/sources.list.d/nebius.list > /dev/null
2. **Install the package**
  
    ```bash
    sudo apt update
    sudo apt install slurm-smd
    ```


### Dependencies

The build process includes the following components:
- **Slurm**: A workload manager that facilitates resource management and scheduling in HPC environments.
- **OpenPMIx**: The Open Process Management Interface for Exascale, which provides a set of interfaces for managing the execution of applications at large scales.
- **NVIDIA NCCL**: NVIDIA's collective communication library optimized for multi-GPU and multi-node systems.
- **NCCL tests**: A suite of tests provided by NVIDIA to validate and benchmark the performance of the NCCL library across different hardware configurations.


## Download packages

To explore and download available packages, go to the [Releases page](https://github.com/nebius/slurm-deb-packages/releases) in this GitHub repository.
