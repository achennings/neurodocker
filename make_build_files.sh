#!/bin/bash
generate_docker() {
  sudo docker run repronim/neurodocker:master generate docker \
    --base=neurodebian:buster --pkg-manager=apt \
    --install apt_opts="--quiet" vim libopenmpi-dev libcurl4-openssl-dev libxml2-dev libssl-dev libudunits2-dev libv8-dev \
    --afni version=latest method=binaries \
    --run-bash "apt-key adv --keyserver keys.gnupg.net --recv-key 'E19F5F87128899B192B1A2C2AD5F960A256A04AF' && echo deb http://cloud.r-project.org/bin/linux/debian buster-cran40/ >> /etc/apt/sources.list && apt update && apt install -y -t buster-cran40 r-base r-base-dev" \
    --run-bash "rPkgsInstall -pkgs ALL -site 'https://cran.microsoft.com/'" \
    --run-bash "apt -y upgrade" \
    --fsl version=6.0.4 method=binaries \
    --ants version=2.3.1 method=binaries \
    --dcm2niix version=2bf2e482aec8e9959c6bd8e833cdccba3607c617 method=source \
    --convert3d version=1.0.0 method=binaries \
    --freesurfer version=7.1.1 method=binaries \
    --copy license.txt /home/docs/license.txt \
    --env FS_LICENSE=/home/docs/license.txt \
    --matlabmcr version=2018a method=binaries \
    --miniconda \
          use_env=base \
          conda_install='python=3.8 matplotlib numpy pandas scikit-learn nilearn scipy seaborn traits' \
          pip_install='nipype pingouin brainiak ipython'
}
# generate_singularity () {
#  sudo docker run repronim/neurodocker:master generate singularity \
# }
generate_docker > Dockerfile
# generate_singularity > Singularity
generate_docker_fslpy() {
  sudo docker run repronim/neurodocker:master generate docker \
    --base=neurodebian:buster --pkg-manager=apt \
    --fsl version=6.0.4 method=binaries \
    --run-bash "bash /opt/fsl-6.0.4/etc/fslconf/fslpython_install.sh -f /opt/fsl-6.0.4"
}

generate_docker_fslpy > Dockerfile_fslpy