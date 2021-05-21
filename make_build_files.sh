#!/bin/bash
generate_docker() {
  sudo docker run repronim/neurodocker:master generate docker \
    --base=debian:stretch --pkg-manager=apt \
    --install vim python \
    --user=root \
    --afni version=latest install_r=TRUE install_r_pkgs=TRUE method=binaries \
    --fsl version=6.0.4 method=binaries \
    --ants version=2.3.1 method=binaries \
    --dcm2niix version=2bf2e482aec8e9959c6bd8e833cdccba3607c617 method=source \
    --convert3d version=1.0.0 method=binaries \
    --freesurfer version=7.1.1 method=binaries \
    --copy license.txt /license.txt \
    --env FS_LICENSE=/license.txt \
    --matlabmcr version=2018a method=binaries \
    --user=neuro \
    --miniconda \
          conda_install='python=3.8 matplotlib numpy pandas scikit-learn nilearn scipy seaborn traits' \
          pip_install='nibabel nipype pingouin ipython' \
          create_env="neuro" \
          activate=true
}

generate_singularity () {
  sudo docker run repronim/neurodocker:master generate singularity \
    --base=debian:stretch --pkg-manager=apt \
    --install vim python \
    --user=root \
    --afni version=latest install_r=TRUE install_r_pkgs=TRUE method=binaries \
    --fsl version=6.0.4 method=binaries \
    --ants version=2.3.1 method=binaries \
    --dcm2niix version=2bf2e482aec8e9959c6bd8e833cdccba3607c617 method=source \
    --convert3d version=1.0.0 method=binaries \
    --freesurfer version=7.1.1 method=binaries \
    --copy license.txt /license.txt \
    --env FS_LICENSE=/license.txt \
    --matlabmcr version=2018a method=binaries \
    --user=neuro \
    --miniconda \
          conda_install='python=3.8 matplotlib numpy pandas scikit-learn nilearn scipy seaborn traits' \
          pip_install='nibabel nipype pingouin ipython' \
          create_env="neuro" \
          activate=true
}
generate_singularity > Singularity
generate_docker > Dockerfile