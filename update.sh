#!/usr/bin/env bash

# Semi automatic scripted workflow to update existing R feedstocks
#
# Sometimes the suggested updates from the bot are not enough, instead a diff
# against a new skeleton run supports fully updating a recipe.
#
# 0. Make the editor of your choice available inside 'git gui', e.g.
#   * git config --global guitool.atom.cmd atom\ \$FILENAME
#   * git config --global guitool.gedit.cmd gedit\ \$FILENAME
# 1. Put the name of the package(s) to update in packages.txt
# 2. Ensure you forked all package feedstocks already
# 3. Run this script via: ./update.sh $your_github_username
# 4. Do the update commit (git gui will be started):
#   * Carefully select all lines required for the update commit
#   * Open a file via the specified editor in git gui for manual changes,
#     e.g build number
#   * Do the update commit and close git gui
# 5. Rerender commit is done automatically, push is done after confirmation
# 6. Browser is opened to create PR on GitHub from your fork to the conda-forge
#    feedstock
# ... Next package ... repetition of step 4.-6.

set -o errtrace -o nounset -o pipefail -o errexit

if (( $# != 1 ))
then
  echo "Usage: Please provide your GitHub username as argument"
  exit 1
fi

read -n1 -r -p "Install/Update conda-build and conda-smithy? [yn]" updatetools </dev/tty
if [[ $updatetools = y ]] ; then
  conda install -c conda-forge conda-build conda-smithy
fi

python run.py

while read -r p; do
  echo "########### Package: $p"

  echo "### Cloning the forked feedstock"
  git clone "https://github.com/$1/$p-feedstock.git"

  echo "### Adding conda-forge remote"
  (cd "$p-feedstock" && git remote add cf "https://github.com/conda-forge/$p-feedstock.git")

  echo "### Checkout conda-forge master as starting point, the fork could be outdated"
  (cd "$p-feedstock" && git remote update && git checkout cf/master -b update)

  echo "### Copy files from skeleton run into cloned feedstock"
  cp "$p/"* "$p-feedstock/recipe/"

  echo "### Open 'git gui' for creation of the update commit"
  (cd "$p-feedstock" && git gui)

  echo "### Do the conda-smithy rerender"
  (cd "$p-feedstock" && conda-smithy rerender -c auto)

  echo "### Show last 2 commits and possible remotes"
  (cd "$p-feedstock" && git log -n 2 && git remote -v)

  echo "### Push?"
  read -n1 -r -p "Push to origin/update? [yn]" answer </dev/tty
  if [[ $answer = y ]] ; then
    # Add '--force', to always overwrite existing update branches
    (cd "$p-feedstock" && git push origin update)
  fi

  echo "### Create a PR from $1/$p-feedstock/update to conda-forge/$p-feedstock/master"
  python -mwebbrowser "https://github.com/conda-forge/$p-feedstock/compare/master...$1:update"

  read -n1 -r -p "Press any key to continue..." </dev/tty

done <packages.txt
