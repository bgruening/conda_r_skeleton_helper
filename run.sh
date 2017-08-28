#!/bin/bash

mkdir -p tmp
for fn in `cat packages.txt`; do
    conda skeleton cran $fn
    cp $fn/meta.yaml tmp/$fn.meta.yaml
    sed -i '/^\s*#.*$/ d' $fn/meta.yaml
    sed -i '/^mv\s.*$/ d' $fn/build.sh
    sed -i '/^grep\s.*$/ d' $fn/build.sh
    sed -i '/^#\s.*$/ d' $fn/build.sh
    sed -i '/^@.*$/ d' $fn/bld.bat
    sed -i '/^$/{N;/^\n$/d;}' $fn/meta.yaml
    sed -i '/^$/{N;/^\n$/d;}' $fn/build.sh
    sed -i 's/ [+|] file LICEN[SC]E//' $fn/meta.yaml
    sed  -i 's/{indent}/\n    - /' $fn/meta.yaml
    # skip win builds
    sed -i 's/number: 0/number: 0\n  skip: true  # [win32]/g' $fn/meta.yaml

    sed -i -e :a -e '/^\n*$/{$d;N;};/\n$/ba' $fn/bld.bat
    sed -i -e :a -e '/^\n*$/{$d;N;};/\n$/ba' $fn/meta.yaml
    sed -i -e :a -e '/^\n*$/{$d;N;};/\n$/ba' $fn/build.sh
    cat extra.yaml >> $fn/meta.yaml
    gedit $fn/meta.yaml
    diff -u $fn/meta.yaml tmp/$fn.meta.yaml > tmp/$fn.meta.diff
done


grep license tmp/*.meta.diff
