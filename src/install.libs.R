# Copy supervisor or supervisor.exe binary to correct location
execs <- "supervisor"
if (WINDOWS)
  execs <- paste0(execs, ".exe")

if (file.exists(execs)) {
  dest <- file.path(R_PACKAGE_DIR,  paste0("bin", R_ARCH))
  dir.create(dest, recursive = TRUE, showWarnings = FALSE)
  file.copy(execs, dest, overwrite = TRUE)
}
