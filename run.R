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
conda_build_version_num <- str_extract(conda_build_version,
                                       "\\d+\\.\\d+\\.\\d+")
if (compareVersion(conda_build_version_num, "3.21.6") == -1) {
  stop("You need to install conda-build 3.21.6 or later.",
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

SPDX_url = 'https://conda-forge.org/docs/maintainer/adding_pkgs.html#spdx-identifiers-and-expressions'
SPDX_licenses = scan("spdx-licenses.txt", what = "character", quiet = TRUE)
SPDX_regex = "^\\s+license: +(.+)\\s*"

packages <- readLines("packages.txt")

for (fn in packages) {
  if (fn == "") next

  cat(sprintf("Processing %s\n", fn))

  if (dir.exists(fn)) {
    cat(sprintf("Skipping %s b/c directory already exists\n", fn))
    next
  }

  # Create the recipe using the cran skeleton
  system2("conda", args = c("skeleton", "cran", "--use-noarch-generic",
                            "--add-cross-r-base", "--no-comments", "--allow-archived", fn))

  # Edit meta.yaml -------------------------------------------------------------

  meta_fname <- file.path(fn, "meta.yaml")
  meta_raw <- readLines(meta_fname)
  meta_new <- meta_raw

  # UCRT changes
  meta_new <- str_replace(meta_new, fixed("{{ native }}"), "")
  meta_new <- str_replace(meta_new, fixed("{{native}}"), "")
  meta_new <- str_replace(meta_new, fixed("{{ posix }}pkg-config"), "pkg-config")
  meta_new <- str_replace(meta_new, fixed("{{posix}}pkg-config"), "pkg-config")
  meta_new <- str_replace(meta_new, fixed("- m2w64-pkg-config"), "- pkg-config")
  meta_new <- str_replace(meta_new, fixed("- m2w64-toolchain"), "- {{ compiler('m2w64_c') }}")
  meta_new <- str_replace(meta_new, fixed("- posix"), "- m2-base")
  meta_new <- meta_new[!str_detect(meta_new, fixed("merge_build_host: "))]
  meta_new <- meta_new[!str_detect(meta_new, fixed("- gcc-libs"))]
  meta_new <- meta_new[!str_detect(meta_new, fixed("set native ="))]
  
  # Extract CRAN metadata
  cran_metadata_start <- str_which(meta_new, "^# Package: ")
  cran_metadata_lines <- cran_metadata_start:length(meta_new)
  cran_metadata <- meta_new[cran_metadata_lines]
  cran_metadata <- cran_metadata[str_detect(cran_metadata, "^#\\s[A-Z]\\S+:")]
  meta_new <- meta_new[-cran_metadata_lines]

  # Inject missing_dso_whitelist
  # NB: this can be removed if merge of https://github.com/conda/conda-build/pull/4786
  idx_rpaths_start <- which(str_detect(meta_new, "  rpaths:"))
  idx_rpaths_end <- which(meta_new == "")
  idx_rpaths_end <- idx_rpaths_end[idx_rpaths_end > idx_rpaths_start][1]
  meta_new <- c(meta_new[seq(idx_rpaths_end - 1)],
                "  missing_dso_whitelist:",
                "    - '*/R.dll'        # [win]",
                "    - '*/Rblas.dll'    # [win]",
                "    - '*/Rlapack.dll'  # [win]",
                meta_new[seq(idx_rpaths_end, length(meta_new))])
  
  # Changing GPL-2 to GPL-2.0-only
  meta_new <- str_replace(meta_new, "license: GPL-2$", "license: GPL-2.0-only")

  # Checking for valid license
  for(line in meta_new){
    if(grepl(SPDX_regex, line)){
      license <- str_replace(line, SPDX_regex, '\\1')
      if(! license %in% SPDX_licenses){
        warning(license, " license not valid. See ", SPDX_url,
                call. = FALSE, immediate. = TRUE)
      }
    }
  }

  # Add maintainers listed in extra.yaml
  maintainers <- readLines("extra.yaml")
  meta_new <- c(meta_new, maintainers)

  # Remove blank lines
  blank_lines <- meta_new == ""
  meta_new <- meta_new[!blank_lines]

  # Add a blank line before a new section
  sections <- str_which(meta_new, "^[a-z]")
  for (s in rev(sections)) {
    meta_new <- c(meta_new[1:(s - 1)], "", meta_new[s:length(meta_new)])
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
