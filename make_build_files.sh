#!/bin/bash
generate_docker() {
  sudo docker run repronim/neurodocker:master generate docker \
    --base=neurodebian:buster --pkg-manager=apt \
    --install apt_opts="--quiet" vim libopenmpi-dev libcurl4-openssl-dev libxml2-dev libssl-dev libudunits2-dev libv8-dev \
    --afni version=latest method=binaries \
    --copy rhash.asc /home/docs/rhash.asc \
    --run-bash "apt-key add /home/docs/rhash.asc && echo deb http://cloud.r-project.org/bin/linux/debian buster-cran40/ >> /etc/apt/sources.list && apt update && apt install -y -t buster-cran40 r-base r-base-dev" \
    --run-bash "rPkgsInstall -pkgs ALL -site 'https://cran.microsoft.com/'" \
    --run-bash "apt -y upgrade" \
    --fsl version=6.0.4 method=binaries \
    --run-bash "bash /opt/fsl-6.0.4/etc/fslconf/fslpython_install.sh -f /opt/fsl-6.0.4" \
    --ants version=2.3.1 method=binaries \
    --dcm2niix version=2bf2e482aec8e9959c6bd8e833cdccba3607c617 method=source \
    --convert3d version=1.0.0 method=binaries \
    --freesurfer version=7.1.1 method=binaries \
    --copy license.txt /home/docs/license.txt \
    --env FS_LICENSE=/home/docs/license.txt \
    --run-bash "fs_install_mcr R2014b" \
    --install libncurses5 \
    --install libgsl-dev \
    --miniconda \
          use_env=base \
          conda_install='python=3.8 matplotlib numpy pandas scikit-learn nilearn scipy seaborn traits' \
          pip_install='nipype pingouin brainiak ipython' \
    --user neuro
}
generate_singularity () {
  sudo docker run repronim/neurodocker:master generate singularity \
    --base=ubuntu:20.04 --pkg-manager=apt \
    --install apt_opts="--quiet" vim libopenmpi-dev libcurl4-openssl-dev libxml2-dev libssl-dev libudunits2-dev libv8-dev cmake \
    --afni version=latest method=binaries \
    --copy rhash.asc /home/docs/rhash.asc \
    --run-bash "apt-key add /home/docs/rhash.asc && echo deb http://cloud.r-project.org/bin/linux/debian buster-cran40/ >> /etc/apt/sources.list && apt update && apt install -y -t buster-cran40 r-base r-base-dev" \
    --run-bash "rPkgsInstall -pkgs ALL -site 'https://cran.microsoft.com/'" \
    --run-bash "apt -y upgrade" \
    --fsl version=6.0.4 method=binaries \
    --run-bash "bash /opt/fsl-6.0.4/etc/fslconf/fslpython_install.sh -f /opt/fsl-6.0.4" \
    --ants version=2.3.1 method=binaries \
    --dcm2niix version=2bf2e482aec8e9959c6bd8e833cdccba3607c617 method=source \
    --convert3d version=1.0.0 method=binaries \
    --freesurfer version=7.1.1 method=binaries \
    --copy license.txt /home/docs/license.txt \
    --env FS_LICENSE=/home/docs/license.txt \
    --run-bash "fs_install_mcr R2014b" \
    --install libncurses5 \
    --install libgsl-dev \
    --miniconda \
          use_env=base \
          conda_install='python=3.8 matplotlib numpy pandas scikit-learn nilearn scipy seaborn traits' \
          pip_install='nipype pingouin brainiak ipython' \
    --user neuro
}
generate_docker > Dockerfile
generate_singularity > Singularity