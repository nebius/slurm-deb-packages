# Slurm Debian Package Builder

This repository automates the process of building Debian packages for [Slurm](https://www.schedmd.com/slurm/why-slurm/) and [NVIDIA NCCL](https://github.com/NVIDIA/nccl). It also builds binary files for running [NCCL tests](https://github.com/NVIDIA/nccl-tests).

Slurm is built using default options, with support for some additional libraries, such as [OpenPMIx (v5)](https://github.com/openpmix/openpmix).

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
