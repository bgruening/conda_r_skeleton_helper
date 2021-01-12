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
# conda, conda-build 3, R, stringr

# Setup checks -----------------------------------------------------------------

if (!require("stringr", quietly = TRUE)) {
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
       "\nRun: conda install -c conda-forge conda-build")
}

conda_build_version <- system2("conda", args = c("build", "--version"),
                               stdout = TRUE)
if (!grepl(pattern = "conda-build 3.+", conda_build_version)) {
  stop("You need to install conda-build 3 from the conda-forge channel",
       "\nRun: conda install -c conda-forge conda-build")
}

conda_build_version_num <- str_extract(conda_build_version,
                                       "\\d+\\.\\d+\\.\\d+")
if (compareVersion(conda_build_version_num, "3.17.2") == -1) {
  stop("You need to install conda-build 3.17.2 or later.",
       "\nCurrently installed version: ", conda_build_version_num,
       "\nRun: conda install -c conda-forge conda-build")
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
  if (fn == "") next

  cat(sprintf("Processing %s\n", fn))

  if (dir.exists(fn)) {
    cat(sprintf("Skipping %s b/c directory already exists\n", fn))
    next
  }

  # Create the recipe using the cran skeleton
  system2("conda", args = c("skeleton", "cran", "--use-noarch-generic", "--add-cross-r-base", fn))

  # Edit meta.yaml -------------------------------------------------------------

  meta_fname <- file.path(fn, "meta.yaml")
  meta_raw <- readLines(meta_fname)
  meta_new <- meta_raw

  # Extract CRAN metadata
  cran_metadata_start <- which(meta_new == "# The original CRAN metadata for this package was:")
  cran_metadata <- meta_new[cran_metadata_start:length(meta_new)]
  cran_metadata <- cran_metadata[str_detect(cran_metadata, "^#\\s[A-Z]\\S+:")]

  # Remove comments
  meta_new <- meta_new[!str_detect(meta_new, "^\\s*#")]

  # Remove "+ file LICENSE" or "+ file LICENCE"
  meta_new <- str_replace(meta_new, " [+|] file LICEN[SC]E", "")

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

  # Space at beginning and end of jinja variable references
  meta_new <- str_replace_all(meta_new, '\\{\\{ *([^} ]+) *\\}\\}', '{{ \\1 }}')

  # Add back CRAN metadata
  meta_new <- c(meta_new, "", cran_metadata)

  writeLines(meta_new, meta_fname)

  # Edit build.sh --------------------------------------------------------------

  build_fname <- file.path(fn, "build.sh")
  build_raw <- readLines(build_fname)
  build_new <- build_raw

  # Remove line that moves DESCRIPTION
  build_new <- build_new[!str_detect(build_new,
                                     "mv DESCRIPTION DESCRIPTION.old")]

  # Remove line that filters DESCRIPTION with grep
  build_new <- build_new[!str_detect(build_new,
                                     "grep -va? '\\^Priority: ' DESCRIPTION.old > DESCRIPTION")]

  # Remove comments (but not shebang line)
  build_new <- build_new[!str_detect(build_new, "^#\\s")]

  # Remove empty lines
  build_new <- build_new[!str_detect(build_new, "^$")]

  writeLines(build_new, build_fname)

  # Manual edit ----------------------------------------------------------------

  # If available, open file for optional manual editing with gedit. Not worth
  # using the more cross-platform file.edit, because by default on Linux that
  # would open the file in vim, which would cause more trouble than help.
  if (Sys.which("gedit") != "") {
    system2("gedit", args = meta_fname)
  }

}
