# Slurm Debian Package Builder

This repository automates the process of building Debian packages for [Slurm](https://www.schedmd.com/slurm/why-slurm/) and [NVIDIA NCCL](https://github.com/NVIDIA/nccl). It also builds binary files for running [NCCL tests](https://github.com/NVIDIA/nccl-tests).

Slurm is built using default options, with support for some additional libraries, such as [OpenPMIx (v5)](https://github.com/openpmix/openpmix).

## Overview

Slurm is a highly scalable cluster management and job scheduling system for Linux clusters. To facilitate its installation and integration into Debian-based systems, this repository provides automated scripts to build `.deb` packages for Slurm and some of its key dependencies, including OpenPMIx and NCCL.

Additionally, binary files for running NCCL tests are built to verify and benchmark the performance of the NCCL library in various configurations.

### Slurm package build tracks

Slurm `25.05.6` and `25.11.5` keep the original native build path. The
[`slurm_packages.yml`](.github/workflows/slurm_packages.yml) workflow downloads
the official tarball directly, builds it with
[`slurm-packages/Dockerfile`](slurm-packages/Dockerfile), and publishes packages
under the original artifact and release names. It does not use manifests,
product patches or ATF.

Slurm `26.05.2` and later use the separate
[`slurm_packages_26.yml`](.github/workflows/slurm_packages_26.yml) workflow and
[`slurm-packages/Dockerfile.patched`](slurm-packages/Dockerfile.patched).
Sources are pinned by JSON manifests in
[`slurm-packages/releases`](slurm-packages/releases); package builds verify the
official tarball checksum and apply an explicit product patch series. The
`baseline` series is always empty and therefore builds vanilla Slurm.

The Nebius-CLI-provisioned disposable-VM Python/Expect validation workflow and
the future vanilla-versus-patched comparison model are documented in
[`slurm-atf/README.md`](slurm-atf/README.md). Slurm release sources are the
system under test, while one separately pinned master snapshot supplies tests
only. Canonical vanilla results are stored separately from package releases as
content-addressed `slurm-atf-baseline-*` GitHub Releases and are never
overwritten. This validation path starts with Slurm `26.05.2`; it is not used
for the legacy 25.x builds.

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
