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
# conda, conda-build 2, python 3

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

    if fn == '':
        continue

    sys.stdout.write('Processing %s\n'%(fn))

    # Create the recipe using the cran skeleton
    sp.run(['conda', 'skeleton', 'cran', fn])

    # Edit meta.yaml -------------------------------------------------------------

    meta_fname = os.path.join(fn, 'meta.yaml')
    with open(meta_fname, 'r') as f:
        meta_raw = f.readlines()
    meta_new = list(meta_raw)

    re_comment = re.compile('^\s*#')

    for i in range(len(meta_new)):
    
        # Remove comments
        if re_comment.match(meta_new[i]):
            meta_new[i] = ''

        # Remove '+ file LICENSE' or '+ file LICENCE'
        meta_new[i] = re.sub(' [+|] file LICEN[SC]E', '', meta_new[i])

        # Replace '{indent}' with proper indentation. This bug has been fixed in
        # conda-build 3, but is still present in conda-build 2.
        meta_new[i] = re.sub('\\{indent\\}', '\n    - ', meta_new[i])

        # Skip build on win32
        meta_new[i] = re.sub('  number: 0',
                             '  number: 0\n  skip: true  # [win32]', meta_new[i])

        # Add path to copy GPL-3 license shipped with r-base
        gpl3 = ['  license_family: GPL3',
                '  license_file: \'{{ environ["PREFIX"] }}/lib/R/share/licenses/GPL-3\'  # [unix]',
                '  license_file: \'{{ environ["PREFIX"] }}\\\\R\\\\share\\\\licenses\\\\GPL-3\'  # [win]']
        meta_new[i] = re.sub('  license_family: GPL3', '\n'.join(gpl3), meta_new[i])

        # Add path to copy GPL-2 license shipped with r-base
        gpl2 = ['  license_family: GPL2',
                '  license_file: \'{{ environ["PREFIX"] }}/lib/R/share/licenses/GPL-2\'  # [unix]',
                '  license_file: \'{{ environ["PREFIX"] }}\\\\R\\\\share\\\\licenses\\\\GPL-2\'  # [win]']
        meta_new[i] = re.sub('  license_family: GPL2', '\n'.join(gpl2), meta_new[i])

        # Remove blank lines
        meta_new[i] = re.sub('^\n$', '', meta_new[i])

        # Add a blank line before a new section
        meta_new[i] = re.sub('^[a-z]', '\n\g<0>', meta_new[i])

    # Add maintainers listed in extra.yaml
    with open('extra.yaml', 'r') as f:
        maintainers = f.readlines()
    meta_new = meta_new + maintainers

    with open(meta_fname, 'w') as f:
        f.writelines(meta_new)

    # Edit build.sh --------------------------------------------------------------

    build_fname = os.path.join(fn, 'build.sh')
    with open(build_fname, 'r') as f:
        build_raw = f.readlines()
    build_new = list(build_raw)

    for i in range(len(build_new)):

        # Remove line that moves DESCRIPTION (starts with 'mv ')
        if re.match('^mv\\s.*', build_new[i]):
            build_new[i] = ''

        # Remove line that filters DESCRIPTION with grep (starts with 'grep ')
        if re.match('^grep\\s.*', build_new[i]):
            build_new[i] = ''

        # Remove comments (but not shebang line)
        if re.match('^#\\s', build_new[i]):
            build_new[i] = ''

        # Remove empty lines
        if re.match('^$', build_new[i]):
            build_new[i] = ''

    with open(build_fname, 'w') as f:
        f.writelines(build_new)

    # Edit bld.bat ---------------------------------------------------------------

    bld_fname = os.path.join(fn, 'bld.bat')
    with open(bld_fname, 'r') as f:
        bld_raw = f.readlines()
    bld_new = list(bld_raw)

    for i in range(len(bld_new)):

        # Remove comments (start with '@')
        if re.match('^@', bld_new[i]):
            bld_new[i] = ''

        # Remove empty lines
        if re.match('^$', bld_new[i]):
            bld_new[i] = ''

    with open(bld_fname, 'w') as f:
        f.writelines(bld_new)

    # Manual edit ----------------------------------------------------------------

    # If available, open file for optional manual editing with gedit. Not worth
    # using the more cross-platform file.edit, because by default on Linux that
    # would open the file in vim, which would cause more trouble than help.
    if shutil.which('gedit'):
        sp.run(['gedit', meta_fname])
