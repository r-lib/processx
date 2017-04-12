# Copy supervisor or supervisor.exe binary to correct location
execs <- file.path("supervisor", "supervisor")
if (WINDOWS)
  execs <- paste0(execs, ".exe")

dest <- file.path(R_PACKAGE_DIR, paste0("bin", R_ARCH))
dir.create(dest, recursive = TRUE, showWarnings = FALSE)
file.copy(execs, dest, overwrite = TRUE)


dlls <- paste0("processx", .Platform$dynlib.ext)
dest <- file.path(R_PACKAGE_DIR, paste0("libs", R_ARCH))
dir.create(dest, recursive = TRUE, showWarnings = FALSE)
file.copy(dlls, dest, overwrite = TRUE)
