#!/usr/bin/env bash
#
# Generate the Dockerfile and Singularity/Apptainer recipe for the lab
# neuroimaging container.
#
# This is the single source of truth: edit the spec in `generate_spec` below,
# then re-run this script to regenerate both `Dockerfile` and `Singularity`.
#
# Requirements: neurodocker >= 2.x  (pip install neurodocker)
#   docs: https://www.repronim.org/neurodocker/
#
# Base image: fedora:40 (yum/dnf).
#   Neurodocker's AFNI binaries template is only maintained for the yum path on
#   modern distros -- on Debian/Ubuntu it depends on `multiarch-support` and
#   legacy libxp6/libpng12 .debs that no longer install (see ReproNim/neurodocker
#   #419). Fedora ships R, libXp, and libpng12 as normal packages, so AFNI +
#   install_r_pkgs builds cleanly with no workarounds. This matches the AFNI
#   examples in the Neurodocker docs, which all use `--pkg-manager yum
#   --base-image fedora:40`.
#
# Pinned software versions (latest stable in the neurodocker 2.1.x registry):
#   AFNI        latest (binaries) + R packages + python3/matplotlib
#   FSL         6.0.7.22
#   FreeSurfer  7.4.1
#   ANTs        2.6.2
#   dcm2niix    v1.0.20250506
#   Convert3D   1.0.0
#
# R: installed via AFNI's `install_r_pkgs=true`, which installs R (R-devel on
# yum) and runs AFNI's `rPkgsInstall -pkgs ALL`.

set -euo pipefail

NEURODOCKER="${NEURODOCKER:-neurodocker}"

# Register the vendored AFNI template (templates/afni.yaml). It is identical to
# Neurodocker's stock template except for one added line per method: it exports
# /opt/afni-* onto PATH right before the `rPkgsInstall` call. Neurodocker only
# puts AFNI on PATH via the template's env block, which becomes Singularity's
# %environment -- and %environment is NOT active during %post. Without the
# export, the Singularity build fails with "rPkgsInstall: not found". (This is a
# Singularity-specific gap, independent of the base distro.)
export REPROENV_TEMPLATE_PATH="$(cd "$(dirname "$0")" && pwd)/templates"

# Shared spec used for both Docker and Singularity. The only difference between
# the two outputs is the `generate <docker|singularity>` subcommand.
generate_spec() {
  local target="$1"   # "docker" or "singularity"

  "$NEURODOCKER" generate "$target" \
    --pkg-manager yum \
    --base-image fedora:40 \
    --yes \
    --install \
        gcc gcc-c++ gcc-gfortran make cmake git wget which unzip \
        openblas-devel gsl-devel libxml2-devel \
    --afni method=binaries version=latest install_r_pkgs=true install_python3=true \
    --fsl version=6.0.7.22 \
    --freesurfer version=7.4.1 \
    --ants version=2.6.2 \
    --dcm2niix version=v1.0.20250506 method=binaries \
    --convert3d version=1.0.0 method=binaries \
    --copy license.txt /opt/freesurfer.license \
    --miniconda \
        version=latest \
        env_name=neuro \
        conda_install="python=3.11 matplotlib numpy pandas scikit-learn scipy seaborn nilearn traits jupyterlab" \
        pip_install="nipype pingouin pybids" \
    --env FS_LICENSE=/opt/freesurfer.license
}

generate_spec docker      > Dockerfile
generate_spec singularity > Singularity

echo "Wrote Dockerfile and Singularity."
