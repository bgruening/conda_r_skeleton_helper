#!/bin/bash

mkdir -p tmp
for fn in `cat packages.txt`; do
    conda skeleton cran $fn
    cp $fn/meta.yaml tmp/$fn.meta.yaml
    sed -i.bak '/^[[:space:]]*#.*$/ d' $fn/meta.yaml
    sed -i.bak '/^mv[[:space:]].*$/ d' $fn/build.sh
    sed -i.bak '/^grep[[:space:]].*$/ d' $fn/build.sh
    sed -i.bak '/^#[[:space:]].*$/ d' $fn/build.sh
    sed -i.bak '/^@.*$/ d' $fn/bld.bat
    sed -i.bak '/^$/{N;/^\n$/d;}' $fn/meta.yaml
    sed -i.bak '/^$/{N;/^\n$/d;}' $fn/build.sh
    sed -i.bak 's/ [+|] file LICEN[SC]E//' $fn/meta.yaml
    sed  -i.bak 's/{indent}/\
    - /' $fn/meta.yaml # Ridiculous POPSIX-stable way to get newline:(
    # skip win builds
    sed -i.bak 's/number: 0/number: 0\
  skip: true  # [win32]/g' $fn/meta.yaml

    # Add GPL-3
    sed -i.bak "s/  license_family: GPL3/  license_family: GPL3\n  license_file: '{{ environ[\"PREFIX\"] }}\/lib\/R\/share\/licenses\/GPL-3'  \# [unix]\n  license_file: '{{ environ[\"PREFIX\"] }}\\\R\\[[:space:]]hare\\\licenses\\\GPL-3' \# [win]/" $fn/meta.yaml
    # Add GPL-2
    sed -i.bak 's/  license_family: GPL2/  license_family: GPL2\
  license_file: '"'"'{{ environ[\"PREFIX\"] }}\/lib\/R\/share\/licenses\/GPL-2'"'"'  \# [unix]\
  license_file: '"'"'{{ environ[\"PREFIX\"] }}\\\R\\[[:space:]]hare\\\licenses\\\GPL-2'"'"'  \# [win]/' $fn/meta.yaml

    sed -i.bak -e ':a' -e '/^\n*$/{$d;N;};/\n$/ba' $fn/bld.bat
    sed -i.bak -e ':a' -e '/^\n*$/{$d;N;};/\n$/ba' $fn/meta.yaml
    sed -i.bak -e ':a' -e '/^\n*$/{$d;N;};/\n$/ba' $fn/build.sh
    cat extra.yaml >> $fn/meta.yaml
    if [[ $(uname -s) == "Linux" ]]; then
	gedit $fn/meta.yaml
    fi
    diff -u $fn/meta.yaml tmp/$fn.meta.yaml > tmp/$fn.meta.diff

    rm -f $fn/*.bak
done


grep license tmp/*.meta.diff
