help([[
OpenMPI v5.0.9 built for the disposable Slurm ATF environment.
It uses the same external PMIx 5.0.11 instance as Slurm.
]])

whatis("Name: OpenMPI")
whatis("Version: 5.0.9")

local root = "/opt/slurm-atf/openmpi/5.0.9"

prepend_path("PATH", pathJoin(root, "bin"))
prepend_path("LD_LIBRARY_PATH", pathJoin(root, "lib"))
prepend_path("PKG_CONFIG_PATH", pathJoin(root, "lib/pkgconfig"))
prepend_path("MANPATH", pathJoin(root, "share/man"))
setenv("OPAL_PREFIX", root)

-- Every logical ATF node is a slurmd on the same host. UCX shared-memory
-- transports then try to cross step/cgroup boundaries through /proc and fail.
-- TCP is slower but deterministic and still exercises Slurm's PMIx wiring.
setenv("OMPI_MCA_pml", "ob1")
setenv("OMPI_MCA_btl", "self,tcp")
setenv("OMPI_MCA_coll", "^hcoll")
