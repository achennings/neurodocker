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
| R          | Fedora `R` + AFNI's R packages (`rPkgsInstall`) |
| Python     | Miniconda env `neuro` (3.11): nipype, nilearn, pybids, pingouin, scipy stack, jupyterlab |

Base image: `fedora:40` (yum/dnf).

### Why Fedora, not Ubuntu/Debian

Neurodocker's AFNI binaries template is only maintained for the **yum** path on
modern distros. On Debian/Ubuntu it depends on `multiarch-support` plus legacy
`libxp6`/`libpng12` `.deb`s that no longer install on current releases — see
[ReproNim/neurodocker#419](https://github.com/ReproNim/neurodocker/issues/419).
Trying to force them through leads to a chain of failures (missing
`multiarch-support`, dead deb URLs, broken apt state, `usrmerge` conflicts).

Fedora ships `R`, `libXp`, and `libpng12` as ordinary packages, so AFNI with
`install_r_pkgs=true` builds with **no workarounds**. This is the approach the
[Neurodocker docs](https://repronim.org/neurodocker/user_guide/examples.html)
use for every AFNI example (`--pkg-manager yum --base-image fedora:40`). The
neuroimaging tools themselves are identical regardless of base distro, and the
final `.sif` runs the same on HPC.

Fedora 40's glibc is also newer than the HPC host's, so Apptainer's bundled
`fakeroot` helper loads, and a plain `apptainer build --fakeroot` works even on
nodes without a configured `/etc/subuid` range. `dnf` builds non-interactively,
so the recipe runs unattended (e.g. as a submitted job).

### Vendored AFNI template

`templates/afni.yaml` is identical to Neurodocker's stock template except for
**one added line per install method**: it puts `/opt/afni-*` on `PATH` right
before the `rPkgsInstall` call. Neurodocker only adds AFNI to `PATH` via the
template's env block, which becomes Singularity's `%environment` — and that is
not active during `%post`, so the bare `rPkgsInstall` would fail with
"not found". This is a Singularity-specific gap, independent of the base distro.
`make_build_files.sh` registers the template via `REPROENV_TEMPLATE_PATH`.

## Regenerating the recipes

Requires `neurodocker >= 2.x`:

```bash
pip install neurodocker
./make_build_files.sh        # writes Dockerfile and Singularity
```

## Building the Apptainer image on the HPC

Most clusters now run [Apptainer](https://apptainer.org) (the renamed
open-source Singularity). The generated `Singularity` recipe bootstraps from the
Fedora Docker base and installs everything in `%post`.

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
