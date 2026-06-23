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
| R          | Ubuntu `r-base` (4.3) + AFNI's R packages (`rPkgsInstall`) |
| Python     | Miniconda env `neuro` (3.11): nipype, nilearn, pybids, pingouin, scipy stack, jupyterlab |

Base image: `ubuntu:24.04` (apt).

### How AFNI is installed (and why not the `--afni` template)

We deliberately do **not** use Neurodocker's `--afni` template. That template
downloads AFNI's *generic* binary (`linux_openmp_64.tgz`), an old build that
links `libXp`/`libpng12` and depends on `multiarch-support` — none of which
install on modern Ubuntu. Forcing them leads to a long chain of failures
(missing `multiarch-support`, dead `.deb` URLs, broken apt state, `usrmerge`
conflicts); this is a known issue,
[ReproNim/neurodocker#419](https://github.com/ReproNim/neurodocker/issues/419).

Instead we follow the maintained approach used by AFNI and by
[NeuroDesk's production recipe](https://github.com/NeuroDesk/neurocontainers/blob/main/recipes/afni/build.yaml):
install AFNI's **Ubuntu-specific** binary, `linux_ubuntu_24_64.tgz`, which is
built against current Ubuntu 24.04 libraries and has **no legacy dependencies**.
The relevant `make_build_files.sh` steps:

1. `apt install` AFNI's runtime/R deps (`r-base`, `tcsh`, `libxm4`, mesa/X libs,
   `libgsl-dev`, …).
2. `curl` the Ubuntu-specific AFNI tarball into `/usr/local/abin`.
3. `curl` AFNI's prebuilt R-package libs (`linux_ubuntu_24_R-4.3_libs.tgz`) into
   `/usr/local/share/R-4.3` and set `R_LIBS` there.
4. `rPkgsInstall -pkgs ALL` (with `/usr/local/abin` exported onto `PATH` —
   Singularity's `%post` does not load the `%environment` block, so the export
   is explicit).

FSL, FreeSurfer, ANTs, dcm2niix, Convert3D, and Miniconda *do* use stock
Neurodocker templates — those work fine on apt.

Ubuntu 24.04 ships `getopt` and a current glibc, so Apptainer's bundled
`fakeroot` helper loads and a plain `apptainer build --fakeroot` works on your
HPC node (unlike a Fedora base, whose image lacks `getopt` —
[apptainer#1863](https://github.com/apptainer/apptainer/issues/1863)).

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
