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

Base image: `ubuntu:22.04`.

### Vendored AFNI template

Neurodocker's stock AFNI template lists `multiarch-support` as an apt
dependency, but that transitional package does not exist on Ubuntu after 20.04,
so the build fails on 22.04. `templates/afni.yaml` is a copy of the stock
template with **only** `multiarch-support` removed — **AFNI itself (download
URL, version, install steps) is unchanged.** `make_build_files.sh` registers it
via `REPROENV_TEMPLATE_PATH`, so it overrides the built-in AFNI template at
generation time.

AFNI needs the legacy `libXp.so.6` library, which is required by AFNI's
`R_io.so` — so `rPkgsInstall` fails without it. It's no longer in the distro
repos, and *installing* the old `libxp6` `.deb` as a package poisons apt: the deb
PreDepends on `multiarch-support` (a transitional metapackage that can't be
installed on 22.04), which leaves apt in a permanently-broken state that blocks
all subsequent `apt-get install`s — including AFNI's own dependencies.

So instead of installing the package, `make_build_files.sh` just **extracts the
shared object** from the `.deb` (`dpkg-deb -x`) and drops `libXp.so.6*` into
`/usr/lib/x86_64-linux-gnu`, then runs `ldconfig`. dpkg/apt never learn about it,
so apt stays clean. This `--run-bash` step runs **before** `--afni` so the
library is present when `rPkgsInstall` runs; `libXp.so.6`'s own runtime deps
(`libX11`, `libXext`, …) are installed moments later by AFNI's `libxm4`
dependency.

> Note: AFNI historically also linked `libpng12`, but that old `.deb` conflicts
> with 22.04's merged-`/usr` (`usrmerge`) and is omitted. If a specific AFNI
> program ever errors with `libpng12.so.0: cannot open shared object file`,
> install a usrmerge-compatible build (e.g. the `ppa:linuxuprising/libpng12`
> PPA) rather than the old Debian `.deb`.

Building on 22.04 (rather than an older base) means Apptainer's bundled
`fakeroot` helper is glibc-compatible with the container, so a plain
`apptainer build --fakeroot` works on HPC login/compute nodes even without a
configured `/etc/subuid` range. The generated `%post` also disables the apt
sandbox and sets `DEBIAN_FRONTEND=noninteractive` so the build runs unattended
(e.g. as a submitted job) without prompting.

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
