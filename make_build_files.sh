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
# AFNI install strategy (important):
#   We do NOT use neurodocker's `--afni` template. That template downloads AFNI's
#   *generic* binary (linux_openmp_64.tgz), which links libXp/libpng12 and needs
#   `multiarch-support` -- none of which install on modern Ubuntu (see
#   ReproNim/neurodocker#419). Instead we mirror the maintained NeuroDesk / AFNI
#   approach: install AFNI's *Ubuntu-specific* binary (linux_ubuntu_24_64.tgz),
#   which is built against current Ubuntu libraries and has no legacy deps.
#   ref: https://github.com/NeuroDesk/neurocontainers/blob/main/recipes/afni/build.yaml
#
#   R: Ubuntu's r-base + AFNI's prebuilt R-package libs tarball + rPkgsInstall.
#
# Other tools use stock neurodocker templates (they work fine on apt):
#   FSL 6.0.7.22, FreeSurfer 7.4.1, ANTs 2.6.2, dcm2niix v1.0.20250506,
#   Convert3D 1.0.0, plus a Miniconda `neuro` env.

set -euo pipefail

NEURODOCKER="${NEURODOCKER:-neurodocker}"

AFNI_BIN_URL="https://afni.nimh.nih.gov/pub/dist/tgz/linux_ubuntu_24_64.tgz"
AFNI_RLIBS_URL="https://afni.nimh.nih.gov/pub/dist/tgz/package_libs/linux_ubuntu_24_R-4.3_libs.tgz"

# Shared spec used for both Docker and Singularity. The only difference between
# the two outputs is the `generate <docker|singularity>` subcommand.
generate_spec() {
  local target="$1"   # "docker" or "singularity"

  "$NEURODOCKER" generate "$target" \
    --pkg-manager apt \
    --base-image ubuntu:24.04 \
    --yes \
    --install software-properties-common \
    --run-bash "add-apt-repository universe -y" \
    --install \
        r-base r-base-dev tcsh \
        build-essential cmake git curl bc \
        python-is-python3 python3-matplotlib python3-numpy \
        gsl-bin netpbm libjpeg62 xvfb xfonts-base \
        libgdal-dev libopenblas-dev libnode-dev libudunits2-dev \
        libssl-dev libcurl4-openssl-dev libxml2-dev libgsl-dev \
        libglu1-mesa-dev libglw1-mesa-dev libxm4 libgfortran-14-dev libgomp1 \
        libxext-dev libxmu-dev libxpm-dev libglut-dev libxi-dev libglib2.0-dev \
    --workdir /opt \
    --run-bash "curl -fsSL -O $AFNI_BIN_URL && tar -xf linux_ubuntu_24_64.tgz && mv linux_ubuntu_24_64 /usr/local/abin && rm -f linux_ubuntu_24_64.tgz" \
    --run-bash "curl -fsSL -O $AFNI_RLIBS_URL && tar -xf linux_ubuntu_24_R-4.3_libs.tgz && mv linux_ubuntu_24_R-4.3_libs /usr/local/share/R-4.3 && rm -f linux_ubuntu_24_R-4.3_libs.tgz" \
    --env PATH='/usr/local/abin:$PATH' R_LIBS=/usr/local/share/R-4.3 \
    --run-bash "export PATH=/usr/local/abin:\$PATH && export R_LIBS=/usr/local/share/R-4.3 && rPkgsInstall -pkgs ALL" \
    --fsl version=6.0.7.22 \
    --freesurfer version=7.4.1 \
    --ants version=2.6.2 \
    --dcm2niix version=v1.0.20250506 method=binaries \
    --convert3d version=1.0.0 method=binaries \
    --copy license.txt /opt/freesurfer.license \
    --miniconda \
        version=latest \
        env_name=neuro \
        env_exists=false \
        conda_install="python=3.11 matplotlib numpy pandas scikit-learn scipy seaborn nilearn traits jupyterlab" \
        pip_install="nipype pingouin pybids" \
    --env FS_LICENSE=/opt/freesurfer.license
}

generate_spec docker      > Dockerfile
generate_spec singularity > Singularity

# --- Make the Singularity build non-interactive (batch/job-safe) ---
# Neurodocker sets DEBIAN_FRONTEND as a Dockerfile ARG, but a Singularity %post
# does not inherit it, so apt packages like tzdata launch interactive debconf
# prompts that hang an unattended build. Inject the export (+ a default TZ) at
# the very top of %post, before Neurodocker's first apt-get.
python3 - "$PWD/Singularity" <<'PY'
import sys
path = sys.argv[1]
inject = "export DEBIAN_FRONTEND=noninteractive\nexport TZ=Etc/UTC\n"
lines = open(path).readlines()
out, done = [], False
for line in lines:
    out.append(line)
    if line.strip() == "%post" and not done:
        out.append(inject)
        done = True
open(path, "w").writelines(out)
print("Set DEBIAN_FRONTEND=noninteractive in Singularity %post" if done else "WARNING: %post not found")
PY

echo "Wrote Dockerfile and Singularity."
