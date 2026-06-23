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
    --base-image ubuntu:20.04 \
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

# --- Post-process the Singularity recipe for unprivileged (rootless) builds ---
#
# When building with `apptainer build --fakeroot` on an HPC node that does NOT
# have a /etc/subuid + /etc/subgid range configured for the user, only a single
# UID is mapped into the build namespace. apt then fails when it tries to drop
# privileges to its sandbox user `_apt` (uid 100):
#     E: setegid/seteuid ... Invalid argument
#     E: Method http has died unexpectedly!
# Disabling the apt sandbox makes apt run as the (namespace) root user instead.
# This must be set before Neurodocker's first `apt-get update`, i.e. at the very
# top of %post.
python3 - "$PWD/Singularity" <<'PY'
import sys
path = sys.argv[1]
inject = 'echo \'APT::Sandbox::User "root";\' > /etc/apt/apt.conf.d/99-disable-sandbox\n'
with open(path) as f:
    lines = f.readlines()
out, done = [], False
for line in lines:
    out.append(line)
    if line.strip() == "%post" and not done:
        out.append(inject)
        done = True
with open(path, "w") as f:
    f.writelines(out)
print("Disabled apt sandbox in Singularity %post" if done else "WARNING: %post not found")
PY

echo "Wrote Dockerfile and Singularity."
