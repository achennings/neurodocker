#!/bin/bash
generate () {
  neurodocker generate docker \
    --base=ubuntu:20.04 --pkg-manager=apt \
    --run-bash "add-apt-repository universe" \
    --run-bash "add-apt-repository -y ppa:marutter/rrutter4.0" \
    --run-bash "add-apt-repository -y ppa:c2d4u.team/c2d4u4.0+" \
    --run-bash "apt-get update" \
    --install apt_opts="--quiet" vim libopenmpi-dev libcurl4-openssl-dev libxml2-dev libssl-dev libudunits2-dev libv8-dev cmake libncurses5 libgsl-dev \
    --install apt_opts="--quiet" tcsh xfonts-base libssl-dev python-is-python3 python3-matplotlib python3-numpy gsl-bin netpbm gnome-tweak-tool libjpeg62 xvfb xterm vim curl gedit evince eog libglu1-mesa-dev libglw1-mesa libxm4 build-essential libcurl4-openssl-dev libxml2-dev libgfortran-8-dev libgomp1 gnome-terminal nautilus gnome-icon-theme-symbolic firefox xfonts-100dpi r-base-dev libgdal-dev libopenblas-dev libnode-dev libudunits2-dev libgfortran4 \
    --afni version=latest method=binaries \
    --run-bash "apt -y upgrade" \
    --user neuro
}
generate > Dockerfile