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
if not re.match('^3.+', conda_build_version):
  sys.stderr.write('You need to install conda-build 3 from the conda-forge channel\n')
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

with open('packages.txt', 'r') as f:
   packages = f.readlines()
   packages = [x.strip() for x in packages]

for fn in packages:

    if not fn:
        continue

    sys.stdout.write('Processing %s\n'%(fn))

    if os.path.exists(fn):
        sys.stderr.write('Skipping %s b/c directory already exists\n'%(fn))
        continue

    # Create the recipe using the cran skeleton
    sp.run(['conda', 'skeleton', 'cran', fn])

    # Edit meta.yaml -------------------------------------------------------------

    # license_file text for GPL'd packages
    gpl2 = ['  license_family: GPL2',
            '  license_file: \'{{ environ["PREFIX"] }}/lib/R/share/licenses/GPL-2\'  # [unix]',
            '  license_file: \'{{ environ["PREFIX"] }}\\\\R\\\\share\\\\licenses\\\\GPL-2\'  # [win]']
    gpl3 = ['  license_family: GPL3',
            '  license_file: \'{{ environ["PREFIX"] }}/lib/R/share/licenses/GPL-3\'  # [unix]',
            '  license_file: \'{{ environ["PREFIX"] }}\\\\R\\\\share\\\\licenses\\\\GPL-3\'  # [win]']

    meta_fname = os.path.join(fn, 'meta.yaml')
    with open(meta_fname, 'r') as f:
        meta_new = []

        for line in f:

            # Remove comments and blank lines
            if re.match('^\s*#', line) or re.match('^\n$', line):
                continue

            # Skip build on win32
            if line == '  number: 0\n':
                line = '  number: 0\n  skip: true  # [win32]\n'

            # Add sed and coreutils when make is present
            if line == '    - {{posix}}make\n':
                line = '    - {{posix}}make\n    - {{posix}}sed\n    - {{posix}}coreutils\n'

            # Remove '+ file LICENSE' or '+ file LICENCE'
            line = re.sub(' [+|] file LICEN[SC]E', '', line)

            # Add path to copy GPL-2 license shipped with r-base
            line = re.sub('  license_family: GPL2', '\n'.join(gpl2), line)

            # Add path to copy GPL-3 license shipped with r-base
            line = re.sub('  license_family: GPL3', '\n'.join(gpl3), line)

            # Add a blank line before a new section
            line = re.sub('^[a-z]', '\n\g<0>', line)

            meta_new += line

    # Add maintainers listed in extra.yaml
    with open('extra.yaml', 'r') as f:
        maintainers = f.readlines()
    meta_new += maintainers

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
            if re.match('.*grep -v \'\\^Priority: \' DESCRIPTION.old > DESCRIPTION', line):
                continue

            # Remove comments (but not shebang line)
            if re.match('^#\\s', line):
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
