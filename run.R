#!/usr/bin/env Rscript

# Helper script to create recipes for CRAN R packages to submit to conda-forge.
#
# Setup checklist:
#
# 1. Put the name of the package(s) in packages.txt
# 2. Add your GitHub username to the list of maintainers in extra.yaml
# 3. Run `Rscript run.R` in this directory
# 4. Move the recipe directory to staged-recipes/recipes
#
# Installation requirements:
#
# conda, conda-build 2, R, stringr

# Setup checks -----------------------------------------------------------------

if (!require(stringr, quietly = TRUE)) {
  stop("Please install the R package stringr to use the helper script",
       "\nRun: install.packages(\"stringr\")")
}

conda <- Sys.which("conda")
if (conda == "") {
  stop("You need to have conda installed to use the helper script")
}

conda_build <- Sys.which("conda-build")
if (conda_build == "") {
  stop("You need to have conda-build installed to use the helper script",
       "\nRun: conda install -c conda-forge conda-build=2")
}

conda_build_version <- system2("conda", args = c("build", "--version"),
                               stdout = TRUE)
if (!grepl(pattern = "conda-build 2.+", conda_build_version)) {
  stop("You need to install conda-build from the conda-forge channel",
       "\nRun: conda install -c conda-forge conda-build=2")
}

if (!file.exists("packages.txt")) {
  stop("Unable to find the file packages.txt.",
       " Please check that it exists and that you are executing the script",
       " in the same working directory as packages.txt.")
}

if (!file.exists("extra.yaml")) {
  stop("Unable to find the file extra.yaml.",
       " Please check that it exists and that you are executing the script",
       " in the same working directory as extra.yaml.")
}

# Process packages -------------------------------------------------------------

packages <- readLines("packages.txt")

for (fn in packages) {
  cat(sprintf("Processing %s\n", fn))

  # Create the recipe using the cran skeleton
  system2("conda", args = c("skeleton", "cran", fn))

  # Edit meta.yaml -------------------------------------------------------------

  meta_fname <- file.path(fn, "meta.yaml")
  meta_raw <- readLines(meta_fname)
  meta_new <- meta_raw

  # Fix the home URL. A bug in conda-build 2 truncates the home URL (and
  # sometimes the description too if it contains a semicolon). This has been
  # fixed in conda-build 3. For now, grab the URL from the CRAN metadata to fix
  # it.
  cran_url <- str_subset(meta_new, "^# URL:\\s")
  cran_url <- str_replace(cran_url, "^# URL:\\s", "")
  conda_url_line <- str_which(meta_new, "^  home:")
  meta_new[conda_url_line] <- paste0("  home: ", cran_url)

  # Remove comments
  meta_new <- meta_new[!str_detect(meta_new, "^\\s*#")]

  # Remove "+ file LICENSE" or "+ file LICENCE"
  meta_new <- str_replace(meta_new, " [+|] file LICEN[SC]E", "")

  # Replace "{indent}" with proper indentation. This bug has been fixed in
  # conda-build 3, but is still present in conda-build 2.
  meta_new <- str_replace(meta_new, "\\{indent\\}", "\n    - ")

  # Skip build on win32
  meta_new <- str_replace(meta_new, "  number: 0",
                          "  number: 0\n  skip: true  # [win32]")

  # Add path to copy GPL-3 license shipped with r-base
  gpl3 <- c(
    "  license_family: GPL3",
    "  license_file: '{{ environ[\"PREFIX\"] }}/lib/R/share/licenses/GPL-3'  # [unix]",
    "  license_file: '{{ environ[\"PREFIX\"] }}\\\\R\\\\share\\\\licenses\\\\GPL-3'  # [win]")
  meta_new <- str_replace(meta_new, "  license_family: GPL3",
                          paste(gpl3, collapse = "\n"))

  # Add path to copy GPL-2 license shipped with r-base
  gpl2 <- c(
    "  license_family: GPL2",
    "  license_file: '{{ environ[\"PREFIX\"] }}/lib/R/share/licenses/GPL-2'  # [unix]",
    "  license_file: '{{ environ[\"PREFIX\"] }}\\\\R\\\\share\\\\licenses\\\\GPL-2'  # [win]")
  meta_new <- str_replace(meta_new, "  license_family: GPL2",
                          paste(gpl2, collapse = "\n"))

  # Add maintainers listed in extra.yaml
  maintainers <- readLines("extra.yaml")
  meta_new <- c(meta_new, maintainers)

  # Remove any consecutive empty lines
  meta_new <- rle(meta_new)$values

  # Remove the annoying blank line in the jinja templating section
  jinja_version_line <- str_which(meta_new, "set version")
  if (meta_new[jinja_version_line + 1] == "") {
    meta_new <- meta_new[-(jinja_version_line + 1)]
  }

  # Remove the annoying blank line between url and sha256
  sha256_line <- str_which(meta_new, "^  sha256")
  if (meta_new[sha256_line - 1] == "") {
    meta_new <- meta_new[-(sha256_line - 1)]
  }

  writeLines(meta_new, meta_fname)

  # Edit build.sh --------------------------------------------------------------

  build_fname <- file.path(fn, "build.sh")
  build_raw <- readLines(build_fname)
  build_new <- build_raw

  # Remove line that moves DESCRIPTION (starts with "mv ")
  build_new <- str_subset(build_new, "^[^mv\\s.*]")

  # Remove line that filters DESCRIPTION with grep (starts with "grep ")
  build_new <- str_subset(build_new, "^[^grep\\s.*]")

  # Remove comments (but not shebang line)
  build_new <- build_new[!str_detect(build_new, "^#\\s")]

  # Remove empty lines
  build_new <- build_new[!str_detect(build_new, "^$")]

  writeLines(build_new, build_fname)

  # Edit bld.bat ---------------------------------------------------------------

  bld_fname <- file.path(fn, "bld.bat")
  bld_raw <- readLines(bld_fname)
  bld_new <- bld_raw

  # Remove comments (start with "@")
  bld_new <- bld_new[!str_detect(bld_new, "^@")]

  # Remove empty lines
  bld_new <- bld_new[!str_detect(bld_new, "^$")]

  writeLines(bld_new, bld_fname)

  # Manual edit ----------------------------------------------------------------

  # If available, open file for optional manual editing with gedit. Not worth
  # using the more cross-platform file.edit, because by default on Linux that
  # would open the file in vim, which would cause more trouble than help.
  if (Sys.which("gedit") != "") {
    system2("gedit", args = meta_fname)
  }

}
