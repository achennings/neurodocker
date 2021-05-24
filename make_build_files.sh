#!/bin/bash
generate_docker() {
  sudo docker run repronim/neurodocker:master generate docker \
    --base=neurodebian:stretch-non-free --pkg-manager=apt \
    --install vim libopenmpi-dev \
    --afni version=latest install_r=TRUE install_r_pkgs=TRUE method=binaries \
    --run "rPkgsInstall -pkgs ALL -site 'http://cloud.r-project.org'" \
    --fsl version=6.0.4 method=binaries \
    --ants version=2.3.1 method=binaries \
    --dcm2niix version=2bf2e482aec8e9959c6bd8e833cdccba3607c617 method=source \
    --convert3d version=1.0.0 method=binaries \
    --freesurfer version=7.1.1 method=binaries \
    --copy license.txt /home/neuro/license.txt \
    --env FS_LICENSE=/home/neuro/license.txt \
    --matlabmcr version=2018a method=binaries \
    --user=neuro \
    --miniconda \
          use_env=base \
          conda_install='python=3.8 matplotlib numpy pandas scikit-learn nilearn scipy seaborn traits' \
          pip_install='nipype pingouin brainiak ipython' \
    --add-to-entrypoint "source /opt/freesurfer-7.1.1/SetUpFreeSurfer.sh"
}

generate_singularity () {
 sudo docker run repronim/neurodocker:master generate singularity \
    --base=neurodebian:stretch-non-free --pkg-manager=apt \
    --install vim libopenmpi-dev \
    --afni version=latest install_r=TRUE install_r_pkgs=TRUE method=binaries \
    --run "rPkgsInstall -pkgs ALL -site 'http://cloud.r-project.org'" \
    --fsl version=6.0.4 method=binaries \
    --ants version=2.3.1 method=binaries \
    --dcm2niix version=2bf2e482aec8e9959c6bd8e833cdccba3607c617 method=source \
    --convert3d version=1.0.0 method=binaries \
    --freesurfer version=7.1.1 method=binaries \
    --copy license.txt /home/neuro/license.txt \
    --env FS_LICENSE=/home/neuro/license.txt \
    --matlabmcr version=2018a method=binaries \
    --user=neuro \
    --miniconda \
          use_env=base \
          conda_install='python=3.8 matplotlib numpy pandas scikit-learn nilearn scipy seaborn traits' \
          pip_install='nipype pingouin brainiak ipython' \
    --add-to-entrypoint "source /opt/freesurfer-7.1.1/SetUpFreeSurfer.sh"
}
generate_docker > Dockerfile
generate_singularity > Singularity