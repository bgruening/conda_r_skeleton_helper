#!/usr/bin/env python

# Helper script to create recipes for CRAN R packages to submit to conda-forge.
#
# Setup checklist:
#
# 1. Put the name of the package(s) in packages.txt
# 2. Add your GitHub username to the list of maintainers in extra.yaml
# 3. Run `python run.py` in this directory
# 4. Move the recipe directory to staged-recipes/recipes
#
# Installation requirements:
#
# conda, conda-build 3, python 3

from distutils.version import StrictVersion
import os
import re
import shutil
import subprocess as sp
import sys

# Setup checks -----------------------------------------------------------------

if sys.version_info.major == 2:
    sys.stderr.write('You need to have python 3 installed to use the helper script\n')
    sys.exit(1)

if not shutil.which('conda'):
    sys.stderr.write('You need to have conda installed to use the helper script\n')
    sys.exit(1)

if not shutil.which('conda-build'):
    sys.stderr.write('You need to have conda-build installed to use the helper script\n')
    sys.stderr.write('Run: conda install -c conda-forge conda-build\n')
    sys.exit(1)

import conda_build

conda_build_version = conda_build.__version__
v_min = StrictVersion('3.21.6')
if StrictVersion(conda_build_version) < v_min:
    sys.stderr.write('You need to install conda-build 3.21.6 or later.\n')
    sys.stderr.write(f'Currently installed version: {conda_build_version}\n')
    sys.stderr.write('Run: conda install -c conda-forge conda-build\n')
    sys.exit(1)

if not os.path.isfile('packages.txt'):
    sys.stderr.write('Unable to find the file packages.txt.\n')
    sys.stderr.write('Please check that it exists and that you are executing the script\n')
    sys.stderr.write('in the same working directory as packages.txt.\n')
    sys.exit(1)

if not os.path.isfile('extra.yaml'):
    sys.stderr.write('Unable to find the file extra.yaml.\n')
    sys.stderr.write('Please check that it exists and that you are executing the script\n')
    sys.stderr.write('in the same working directory as extra.yaml.\n')
    sys.exit(1)

# Process packages -------------------------------------------------------------

SPDX_url = 'https://conda-forge.org/docs/maintainer/adding_pkgs.html#spdx-identifiers-and-expressions'
with open('spdx-licenses.txt') as f:
    SPDX_licenses = [line.strip() for line in f]
SPDX_regex = re.compile(r'^\s+license: +(.+)\s*')

with open('packages.txt', 'r') as f:
   packages = f.readlines()
   packages = [x.strip() for x in packages]

for fn in packages:

    if not fn:
        continue

    sys.stdout.write(f'Processing {fn}\n')

    if os.path.exists(fn):
        sys.stderr.write(f'Skipping {fn} b/c directory already exists\n')
        continue

    # Create the recipe using the cran skeleton
    sp.run(['conda', 'skeleton', 'cran', '--use-noarch-generic',
            '--add-cross-r-base', '--no-comments', '--allow-archived', fn])

    # Edit meta.yaml -------------------------------------------------------------

    meta_fname = os.path.join(fn, 'meta.yaml')
    with open(meta_fname, 'r') as f:
        meta_new = []
        is_cran_metadata = False
        cran_metadata = ['\n']
        is_rpaths = False

        for line in f:
            # UCRT changes
            line = line.replace("{{ native }}", "")
            line = line.replace("{{native}}", "")
            line = line.replace("{{posix}}pkg-config", "pkg-config")
            line = line.replace("{{ posix }}pkg-config", "pkg-config")
            line = line.replace("- m2w64-pkg-config", "- pkg-config")
            line = line.replace("- m2w64-toolchain", "- {{ compiler('m2w64_c') }}")
            line = line.replace("- posix", "- m2-base")
            if "merge_build_host: " in line:
                continue
            if "- gcc-libs" in line:
                continue
            if "set native =" in line:
                continue
            
            # Extract CRAN metadata
            if line[:11] == '# Package: ':
                is_cran_metadata = True
            if is_cran_metadata and re.match('^#\s[A-Z]\S+:', line):
                cran_metadata.append(line)
                continue
            
            # Inject missing_dso_whitelist
            # NB: this can be removed if merge of https://github.com/conda/conda-build/pull/4786
            if re.match('^  rpaths:$', line):
                is_rpaths = True
                meta_new.append(line)
                continue
            elif is_rpaths:
                if re.match('^\s+-.*', line):
                    meta_new.append(line)
                    continue
                else:
                    is_rpaths = False
                    meta_new.append("  missing_dso_whitelist:\n")
                    meta_new.append("    - '*/R.dll'        # [win]\n")
                    meta_new.append("    - '*/Rblas.dll'    # [win]\n")
                    meta_new.append("    - '*/Rlapack.dll'  # [win]\n")
                    continue

            # Remove blank lines
            if re.match('^\n$', line):
                continue

            # Changing GPL-2 to GPL-2.0-only
            line = re.sub('license: GPL-2$', 'license: GPL-2.0-only', line)
	    # Changing GPL-3 to GPL-3.0-only
            line = re.sub('license: GPL-3$', 'license: GPL-3.0-only', line)


            # Checking for valid SPDX license
            if SPDX_regex.match(line):
                license = SPDX_regex.match(line).group(1)
                if not license in SPDX_licenses:
                    msg = f'Warning: "{license}" license not valid. See {SPDX_url}\n'
                    sys.stderr.write(msg)

            # Add a blank line before a new section
            line = re.sub('^[a-z]', '\n\g<0>', line)

            # Space at beginning and end of jinja variable references
            line = re.sub('\{\{ *([^} ]+) *\}\}', '{{ \g<1> }}', line)

            meta_new.append(line)

    # Ensure stdlib requirement is present when compilers are used
    compilers = set()
    stdlibs = set()
    build_section_start = None
    build_section_end = None
    in_requirements = False
    in_build_requirements = False
    for idx, line in enumerate(meta_new):
        stripped = line.lstrip()
        if stripped.startswith('requirements:'):
            in_requirements = True
            in_build_requirements = False
            continue
        if not in_requirements:
            continue
        if stripped.startswith('build:'):
            in_build_requirements = True
            build_section_start = idx
            continue
        if in_build_requirements and re.match(r'^(host:|run:)', stripped):
            build_section_end = idx
            break
        if in_build_requirements:
            compiler_match = re.search(r"compiler\(['\"]([^'\"]+)['\"]\)", line)
            if compiler_match:
                compilers.add(compiler_match.group(1))
            stdlib_match = re.search(r"stdlib\(['\"]([^'\"]+)['\"]\)", line)
            if stdlib_match:
                stdlibs.add(stdlib_match.group(1))

    compiler_to_stdlib = {
        'c': 'c',
        'cxx': 'cxx',
        'fortran': 'fortran',
        'gfortran': 'fortran',
        'm2w64_c': 'c',
        'm2w64_cxx': 'cxx',
        'm2w64_fortran': 'fortran',
    }
    needed_stdlibs = []
    for lang in ['c', 'cxx', 'fortran']:
        if any(compiler_to_stdlib.get(c) == lang for c in compilers) and lang not in stdlibs:
            needed_stdlibs.append(lang)

    if needed_stdlibs and build_section_start is not None:
        insert_at = build_section_end if build_section_end is not None else build_section_start + 1
        new_lines = ["    - {{ stdlib(\"%s\") }}\n" % lang for lang in needed_stdlibs]
        meta_new[insert_at:insert_at] = new_lines

    # Add maintainers listed in extra.yaml
    with open('extra.yaml', 'r') as f:
        maintainers = f.readlines()
    meta_new += maintainers

    # Add back CRAN metadata
    meta_new += cran_metadata

    with open(meta_fname, 'w') as f:
        f.writelines(meta_new)

    # Edit build.sh --------------------------------------------------------------

    build_fname = os.path.join(fn, 'build.sh')
    with open(build_fname, 'r') as f:
        build_new = []

        for line in f:

            # Remove line that moves DESCRIPTION
            if re.match('.*mv DESCRIPTION DESCRIPTION.old', line):
                continue

            # Remove line that filters DESCRIPTION with grep
            if re.match('.*grep -va* \'\\^Priority: \' DESCRIPTION.old > DESCRIPTION', line):
                continue

            # Remove empty lines
            if re.match('^$', line):
                continue

            build_new += line

    with open(build_fname, 'w') as f:
        f.writelines(build_new)

    # Manual edit ----------------------------------------------------------------

    # If available, open file for optional manual editing with gedit. Not worth
    # using the more cross-platform file.edit, because by default on Linux that
    # would open the file in vim, which would cause more trouble than help.
    if shutil.which('gedit'):
        sp.run(['gedit', meta_fname])
