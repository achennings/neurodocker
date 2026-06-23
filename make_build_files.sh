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

# Register the vendored templates (see templates/afni.yaml). Our AFNI template
# is a copy of Neurodocker's stock one with `multiarch-support` and two legacy
# .deb URLs removed -- those exist only on pre-22.04 distros and break the build
# on ubuntu:22.04. AFNI itself (download URL, version, install steps) is
# unchanged. Building on 22.04 lets Apptainer's fakeroot helper load (its glibc
# requirement is satisfied), so `apptainer build --fakeroot` works on HPC nodes
# without a subuid/subgid range.
export REPROENV_TEMPLATE_PATH="$(cd "$(dirname "$0")" && pwd)/templates"

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

# --- Post-process the Singularity recipe for non-interactive, rootless builds ---
#
# Two things a Singularity %post does NOT inherit from the Docker build, both of
# which break unattended/batch (job-submitted) builds:
#
# 1. apt sandbox. With `apptainer build --fakeroot` on an HPC node that has no
#    /etc/subuid + /etc/subgid range, only a single UID is mapped into the build
#    namespace, so apt cannot drop privileges to its sandbox user `_apt`:
#        E: setegid/seteuid ... Invalid argument / Method http has died
#    `APT::Sandbox::User "root"` makes apt run as the namespace root user.
#
# 2. DEBIAN_FRONTEND. Neurodocker sets this as an ARG in the Dockerfile, but
#    %post does not get it, so packages like tzdata launch interactive debconf
#    prompts (geographic area, etc.) that hang a non-interactive job forever.
#    Exporting DEBIAN_FRONTEND=noninteractive (+ a default TZ) suppresses them.
#
# Both must be set before Neurodocker's first `apt-get update`, i.e. at the very
# top of %post.
python3 - "$PWD/Singularity" <<'PY'
import sys
path = sys.argv[1]
inject = (
    'export DEBIAN_FRONTEND=noninteractive\n'
    'export TZ=Etc/UTC\n'
    'echo \'APT::Sandbox::User "root";\' > /etc/apt/apt.conf.d/99-disable-sandbox\n'
)
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
