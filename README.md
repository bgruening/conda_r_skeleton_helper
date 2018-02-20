# Conda r skeleton helpers (for conda-forge)

Please use this script to create recipes for R packages on CRAN that follow the
conventions used by the conda-forge project. It runs `conda skeleton cran` and
then cleans up the result. Please mention in your Pull Request to
[staged-recipes][] that you used the helper script to expedite the review
process. Also, please only submit one recipe per Pull Request.

## Installation

You will need conda and conda-build 2 installed. To install conda-build 2
instead of 3, specify the conda-forge channel.

```
conda install -c conda-forge conda-build
```

## Using the script

1. Put the package name(s) in `packages.txt` in the form of `r-foobar`
1. Add your GitHub username to the list of maintainers in `extra.yaml`
1. Execute the helper script using one of the following methods:

    a. Run the bash script in the Terminal
    ```
    bash run.sh
    ```
    b. Run the R script in the Terminal
    ```
    Rscript run.R
    ```
    c. Source the R script in the R console
    ```
    source("run.R")
    ```

1. Please check the recipe(s) manually. Especially the LICENSE section - this
sections should not contain the word license.
1. Move the recipe directory to `staged-recipes/recipes`

[staged-recipes]: https://github.com/conda-forge/staged-recipes
