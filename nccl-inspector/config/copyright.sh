#!/usr/bin/env bash

set -euo pipefail

SRC_DIR="${1:?usage: $0 <path-to-nccl-root>}"

LICENSE_FILE="${SRC_DIR}/LICENSE.txt"

(
  echo 'Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/'
  echo 'Upstream-Name: NCCL Inspector Plugin'
  echo 'Source: https://github.com/NVIDIA/nccl/tree/master/plugins/profiler/inspector'
  echo
  echo 'Files: *'
  echo 'Copyright: All source code and accompanying documentation is copyright (c) 2015-2020, NVIDIA CORPORATION. All rights reserved.'
  echo 'License: Apache-2.0'
  echo 'Comment: This Debian package redistributes unmodified upstream build artifacts.'
  echo
  echo 'License: Apache-2.0'
  sed 's/^/ /; s/^ $/./' "${LICENSE_FILE}"
)
