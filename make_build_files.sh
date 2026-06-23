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
# Pinned software versions (latest stable available in the neurodocker 2.1.x
# registry as of this writing):
#   AFNI        latest (binaries) + R packages + python3/matplotlib
#   FSL         6.0.7.22
#   FreeSurfer  7.4.1
#   ANTs        2.6.2
#   dcm2niix    v1.0.20250506
#   Convert3D   1.0.0
#
# R is installed via AFNI's `install_r_pkgs=true`, which pulls r-base/r-base-dev
# from the Ubuntu repos and then runs AFNI's `rPkgsInstall -pkgs ALL`. This
# replaces the old (now-defunct) MRAN + apt-key approach.

set -euo pipefail

NEURODOCKER="${NEURODOCKER:-neurodocker}"

# Shared spec used for both Docker and Singularity. The only difference between
# the two outputs is the `generate <docker|singularity>` subcommand.
generate_spec() {
  local target="$1"   # "docker" or "singularity"

  "$NEURODOCKER" generate "$target" \
    --pkg-manager apt \
    --base-image ubuntu:22.04 \
    --yes \
    --install \
        build-essential ca-certificates cmake git curl wget unzip \
        libopenblas-dev libgsl-dev libnlopt-dev \
        libcurl4-openssl-dev libssl-dev libxml2-dev libudunits2-dev \
        libgdal-dev libnode-dev \
        libfontconfig1-dev libfreetype6-dev libpng-dev libtiff5-dev \
        libjpeg-dev libharfbuzz-dev libfribidi-dev \
    --afni method=binaries version=latest install_r_pkgs=true install_python3=true \
    --fsl version=6.0.7.22 \
    --freesurfer version=7.4.1 \
    --ants version=2.6.2 \
    --dcm2niix version=v1.0.20250506 method=binaries \
    --convert3d version=1.0.0 method=binaries \
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
