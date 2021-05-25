#!/bin/bash
generate_docker() {
  sudo docker run repronim/neurodocker:master generate docker \
    --base=neurodebian:buster --pkg-manager=apt \
    --install apt_opts="--quiet" vim libopenmpi-dev \
    --afni version=latest method=binaries install_r=true \
    --run-bash "rPkgsInstall -pkgs 'car,afex,phia,snow,nlme,lmerTest,paran,brms,corrplot,metafor' -update" \
    --fsl version=6.0.4 method=binaries \
    --ants version=2.3.1 method=binaries \
    --dcm2niix version=2bf2e482aec8e9959c6bd8e833cdccba3607c617 method=source \
    --convert3d version=1.0.0 method=binaries \
    --freesurfer version=7.1.1 method=binaries \
    --copy license.txt /home/docs/license.txt \
    --env FS_LICENSE=/home/docs/license.txt \
    --matlabmcr version=2018a method=binaries \
    --spm12 version=r7771 \
    --copy conn20b.zip /home/docs/conn20b.zip \
    --run-bash "tar xf /home/docs/conn20b.zip -C /opt/conn" \
    --miniconda \
          use_env=base \
          conda_install='python=3.8 matplotlib numpy pandas scikit-learn nilearn scipy seaborn traits' \
          pip_install='nipype pingouin brainiak ipython'
    #--add-to-entrypoint "source /opt/freesurfer-7.1.1/SetUpFreeSurfer.sh"
}
generate_docker_r() {
  sudo docker run repronim/neurodocker:master generate docker \
    --base=neurodebian:buster --pkg-manager=apt \
    --install apt_opts="--quiet" vim libopenmpi-dev\
    --afni version=latest install_r=true method=binaries \
    --run-bash "rPkgsInstall -pkgs 'car,afex,phia,snow,nlme,lmerTest,paran,brms,corrplot,metafor' -update"
}
# generate_singularity () {
#  sudo docker run repronim/neurodocker:master generate singularity \
# }
generate_docker > Dockerfile
generate_docker_r > Dockerfile_R
# generate_singularity > Singularity