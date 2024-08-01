# Slurm Debian Package Builder

This repository automates the process of building Debian packages for [Slurm](https://www.schedmd.com/download-slurm/) and [NVIDIA NCCL](https://github.com/NVIDIA/nccl). Additionally, it builds binary files for running [NCCL tests](https://github.com/NVIDIA/nccl-tests). The built packages and binaries are published as releases in this GitHub repository.

Slurm is built using default options, with support for some additional libraries, such as [OpenPMIx (v5)](https://github.com/openpmix/openpmix).

## Overview

Slurm is a highly scalable cluster management and job scheduling system for Linux clusters. To facilitate its installation and integration into Debian-based systems, this repository provides automated scripts to build `.deb` packages for Slurm and some of its key dependencies, including OpenPMIx and NCCL.

Additionally, binary files for running NCCL tests are built to verify and benchmark the performance of the NCCL library in various configurations.

### Dependencies

The build process includes the following components:
- **Slurm**: A workload manager that facilitates resource management and scheduling in HPC environments.
- **OpenPMIx**: The Open Process Management Interface for Exascale, providing a set of interfaces to manage the execution of applications at large scales.
- **NVIDIA NCCL**: NVIDIA's collective communication library optimized for multi-GPU and multi-node systems.
- **NCCL Tests**: A suite of tests provided by NVIDIA to validate and benchmark the performance of the NCCL library across different hardware configurations.
