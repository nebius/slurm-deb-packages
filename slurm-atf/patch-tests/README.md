# Patch-specific ATF tests

Product regression tests are stored under `<release>/<patchset>/`. `series`
patches a separate copy of the pinned tests snapshot and `nodeids.txt` lists
every newly introduced pytest nodeid. These tests are run and counted after,
not as part of, the common vanilla/candidate comparison.

Do not edit the common test tree and do not include an upstream test merely
because it is related to a patch; only tests introduced by the product patch
belong here.
