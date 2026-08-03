help([[
MPICH 5.0.1 CH3/sock linked to this stand's Slurm PMI2 client library.

CH3/sock is intentional: MPICH CH4/UCX can generate a 4096-byte dynamic
port name, but Slurm PMI2 accepts values up to 1024 bytes.  Slurm's
MPI_Comm_spawn regression therefore needs this PMI2-compatible profile.
]])

whatis("Name: MPICH")
whatis("Version: 5.0.1")

local root = "/opt/slurm-atf/mpich/5.0.1-ch3-sock"

prepend_path("PATH", pathJoin(root, "bin"))
unsetenv("OPAL_PREFIX")
setenv("MPICH_ROOT", root)
