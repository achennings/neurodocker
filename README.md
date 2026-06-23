# neurodocker

Recipe for the lab neuroimaging container, generated with
[Neurodocker](https://github.com/ReproNim/neurodocker) (2.x).

`make_build_files.sh` is the single source of truth. It generates both
`Dockerfile` and `Singularity` (an Apptainer/Singularity recipe) from one spec.
Edit the script, re-run it, and commit the regenerated recipes.

## What's in the image

| Software   | Version                  |
| ---------- | ------------------------ |
| AFNI       | latest binaries (+ R pkgs, python3/matplotlib) |
| FSL        | 6.0.7.22                 |
| FreeSurfer | 7.4.1                    |
| ANTs       | 2.6.2                    |
| dcm2niix   | v1.0.20250506            |
| Convert3D  | 1.0.0                    |
| R          | system `r-base` + AFNI's R packages |
| Python     | Miniconda env `neuro` (3.11): nipype, nilearn, pybids, pingouin, scipy stack, jupyterlab |

Base image: `ubuntu:20.04` (Neurodocker's AFNI template depends on
`multiarch-support`, which Ubuntu dropped after 20.04; the neuroimaging tool
binaries all run fine on this base).

## Regenerating the recipes

Requires `neurodocker >= 2.x`:

```bash
pip install neurodocker
./make_build_files.sh        # writes Dockerfile and Singularity
```

## Building the Apptainer image on the HPC

Most clusters now run [Apptainer](https://apptainer.org) (the renamed
open-source Singularity). The generated `Singularity` recipe bootstraps from the
Ubuntu Docker base and installs everything in `%post`.

```bash
# On the cluster, in this repo directory:
apptainer build --fakeroot neuro.sif Singularity
```

Notes:
- `--fakeroot` lets you build without root. If your site disables it, ask your
  HPC admins to build the `.sif` for you, or build with `--remote` against a
  build service. The build is large (FreeSurfer + FSL ≈ several GB) and needs
  outbound network access during `%post`.
- If you'd rather build locally with Docker first (you have Docker on your Mac),
  you can convert the resulting image:
  ```bash
  docker build -t neuro:latest .
  docker save neuro:latest -o neuro.tar
  # copy neuro.tar to the cluster, then:
  apptainer build neuro.sif docker-archive://neuro.tar
  ```

## FreeSurfer license

`license.txt` is baked into the image at `/opt/freesurfer.license`, and
`FS_LICENSE` points to it — FreeSurfer works out of the box, no runtime mount
needed. To rotate it, replace `license.txt` and regenerate the recipes.

## Running tools

```bash
# Drop into a shell with everything on PATH:
apptainer shell neuro.sif

# Or run a single tool:
apptainer exec neuro.sif afni -ver
apptainer exec neuro.sif flirt -version
apptainer exec -B $PWD neuro.sif dcm2niix -o out/ dicom_dir/

# The conda `neuro` env (nipype, nilearn, ...) is on PATH as the default python.
apptainer exec neuro.sif python -c "import nipype, nilearn; print('ok')"
```

On HPC, bind your data directories with `-B /scratch:/scratch` (or wherever your
data lives). Apptainer runs as your own user, so files are written with your
permissions.
