# Conda r skeleton helpers (for conda-forge)

Please use this script to create recipes for R packages on CRAN that follow the
conventions used by the conda-forge project. It runs `conda skeleton cran` and
then cleans up the result. Please mention in your Pull Request to
[staged-recipes][] that you used the helper script to expedite the review
process. Also, please only submit one recipe per Pull Request.

## Installation

You will need conda and conda-build 3 (3.17.2+) installed:

```
conda install -c conda-forge conda-build
```

To use the Python script `run.py`, you will need to install Python 3.

Alternatively, to use the R script `run.R`, you will need to install R and the
stringr package.

Either of these scripts can be run on Linux, macOS, and Windows.

## Using the script

1. Put the package name(s) in `packages.txt` in the form of `r-foobar`
1. Add your GitHub username to the list of maintainers in `extra.yaml`
1. Execute the helper script using one of the following methods:

    a. Run the Python script in the Terminal
    ```
    python run.py
    ```
    b. Run the R script in the Terminal
    ```
    Rscript run.R
    ```
    c. Source the R script in the R console
    ```
    source("run.R")
    ```
    d. Run the bash script in the Terminal
    (for backwards compatibility. This runs the Python script)
    ```
    bash run.sh
    ```

1. Please check the recipe(s) manually. Especially the LICENSE section - this
sections should not contain the word license.
1. Move the recipe directory to `staged-recipes/recipes`

[staged-recipes]: https://github.com/conda-forge/staged-recipes
