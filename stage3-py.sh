#!/bin/sh
set -e

install_custom_jupyterlab () {
    #
    # This will no longer be necessary when xtermjs 4.19 is available in
    # upstream builds.
    #
    conda remove -y --force-remove jupyterlab
    cd ${BLD}
    git clone -b force_xterm https://github.com/lsst-sqre/jupyterlab
    cd jupyterlab
    npm cache clean --force  # Make sure we start clean
    pip install --no-deps --force-reinstall -e .
    jupyter lab clean --all
    jlpm install
    cd jupyterlab/staging
    rm yarn.lock
    # Reinstall all the core modules -- package.json forces xterm version
    jlpm
    jlpm run build:prod  # Rebuild with new dependency
    # Back up top
    cd ../..
    jupyter lab clean --all
    jupyter lab build --dev-build=False --minimize=False
    # I don't think this next stage helps any, but...
    pip install --no-deps --force-reinstall .
}

#This commented-out bit, plus changing the definition of LOADRSPSTACK in
# Dockerfile.template, will clone the environment rather than installing
# into the stack environment itself.  This adds 60% or so to the container
# size.
#
# source ${LOADSTACK}
# rspname="rsp-${LSST_CONDA_ENV_NAME}"
# mamba create --name ${rspname} --clone ${LSST_CONDA_ENV_NAME}
#
source ${LOADRSPSTACK}
if [ -z "$(which mamba)" ]; then
    conda install -y mamba
fi
# Never allow the installation to upgrade rubin_env.  Generally enforcing
# the pin is only needed for releases, where the current version may have
# moved ahead.
rubin_env_ver=$(mamba list rubin-env$ --no-banner --json \
                    | jq -r '.[0].version')
# Do the rest of the installation
# Skip for now to get custom JL installed first
mamba install --no-banner -y \
      "rubin-env-rsp==${rubin_env_ver}"
# Until upstream contains at least xtermjs 4.19, we need to install a
# custom JL that does contain it.
echo "Installing custom JupyterLab"
install_custom_jupyterlab
echo "Custom JupyterLab installed"
# These are the things that are not available on conda-forge.
# Note that we are not installing with `--upgrade`.  That is so that if
# lower-level layers have already installed the package (e.g. T&S may have
# already installed lsst-efd-client), pinned to a version they need, we won't
# upgrade it.  But if it isn't already installed, we'll just take the latest
# available.
pip install \
      socketio-client \
      nclib \
      jupyterlab_hdf \
      lsst-efd-client \
      jupyter_firefly_extensions \
      lsst-rsp \
      rsp-jupyter-extensions

# Add stack kernel
python3 -m ipykernel install --name 'LSST'

# Remove "system" kernel
stacktop="/opt/lsst/software/stack/conda/current"
rm -rf ${stacktop}/envs/${LSST_CONDA_ENV_NAME}/share/jupyter/kernels/python3

# Clear mamba and pip caches
mamba clean -a -y --no-banner
rm -rf /root/.cache/pip

# Create package version docs.
pip3 freeze > ${verdir}/requirements-stack.txt
mamba env export > ${verdir}/conda-stack.yml
