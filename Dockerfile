FROM lsstsqre/centos:7-stack-lsst_distrib-w_2021_32
USER root
SHELL ["/bin/bash", "-lc"]
# If we don't have locales set correctly, the pip install pieces can fail.
#  Maybe they should be ARGs, but this seems like a reasonable thing to
#  put in the environment by default.
ENV  LANG=en_US.UTF-8
ENV  LC_ALL=en_US.UTF-8
# Runtime scripts use ${LOADRSPSTACK} but we need the distinction
#  in case you want to create a separate environment for the JupyterLab-
#  specific pieces.
ENV  LOADSTACK=/opt/lsst/software/stack/loadLSST.bash
ENV  LOADRSPSTACK=/opt/lsst/software/rspstack/loadrspstack.bash
RUN  mkdir -p /opt/lsst/software/rspstack
# If you want the JupyterLab pieces in their own environment, do the
#  COPY and add the environment clone to the python build stage.  This
#  increases container size by about 60%.  If you want it in the same
#  environment (the default), link the RSP loadstack instead.
#COPY loadrspstack.bash ${LOADRSPSTACK}
RUN  ln -s ${LOADSTACK} ${LOADRSPSTACK}
ARG  srcdir=/opt/lsst/src
ARG  BLD=${srcdir}/build
RUN  mkdir -p ${BLD}
COPY stage1-rpm.sh ${BLD}
RUN  ${BLD}/stage1-rpm.sh
RUN  mkdir -p /tmp/tex
COPY texlive.profile /tmp/tex
COPY stage2-os.sh ${BLD}
RUN  ${BLD}/stage2-os.sh
COPY stage3-py.sh ${BLD}
RUN  ${BLD}/stage3-py.sh
# This should be exposed at runtime for JupyterLab, hence ENV
ENV  NODE_OPTIONS="--max-old-space-size=7168 --max-http-header-size=16384"
RUN  mkdir -p /usr/local/etc/jupyter
COPY jupyter_notebook_config.json /usr/local/etc/jupyter
# Server, notebook, and lab extensions
ARG SVXT="jupyterlab jupyter_firefly_extensions \
          nbdime jupyterlab_iframe \
          rubin_jupyter_utils.lab.serverextensions.hub_comm \
          rubin_jupyter_utils.lab.serverextensions.settings \
          rubin_jupyter_utils.lab.serverextensions.query \
          rubin_jupyter_utils.lab.serverextensions.display_version"
ARG NBXT="widgetsnbextension ipyevents nbdime"
ARG LBXT="@jupyterlab/toc \
          bqplot@0.5.23 \
          ipyevents \
          ipyvolume \
          jupyter-threejs \
          nbdime-jupyterlab \
          dask-labextension \
          @jupyter-widgets/jupyterlab-manager \
          jupyter-matplotlib@^0.9.0 \
          @pyviz/jupyterlab_pyviz \
          jupyterlab_iframe \
          @jupyter-widgets/jupyterlab-sidecar \
          @bokeh/jupyter_bokeh \
          pywwt \
          jupyter_firefly_extensions \
          @jupyterlab/hdf5 \
          @lsst-sqre/rubin-labextension-query \
          @lsst-sqre/rubin-labextension-savequit \
          @lsst-sqre/rubin-labextension-displayversion"
# Broken:
#          js9ext
ARG  jl=/opt/lsst/software/jupyterlab
ARG  verdir="${jl}/versions.installed"
COPY stage4-jup.sh ${BLD}
RUN  ${BLD}/stage4-jup.sh
COPY local01-nbstripjq.sh local02-hub.sh local03-showrspnotice.sh  \
     local04-pythonrc.sh local05-path.sh local06-term.sh \
     local07-namespaceenv.sh \
     /etc/profile.d/
COPY lsst_kernel.json \
       /usr/local/share/jupyter/kernels/lsst/kernel.json
COPY rsp_notice /usr/local/etc
COPY pythonrc /etc/skel/.pythonrc
COPY gitconfig /etc/skel/.gitconfig
COPY git-credentials /etc/skel/.git-credentials
COPY user_setups /etc/skel/notebooks/.user_setups
COPY lsst_kernel.json selfculler.py \
      lsstlaunch.bash runlab.sh refreshnb.sh \
      prepuller.sh lsstwrapdask.bash lsst_dask.yml \
      ${jl}/
COPY noninteractive /opt/lsst/software/jupyterlab/noninteractive/     
COPY stage5-ro.sh ${BLD}
RUN  ${BLD}/stage5-ro.sh
# Need to change this in charts when we're ready, and then we can lose the
#  link
RUN  cd ${jl} && \
      ln -s runlab.sh provisionator.bash
# Overwrite Stack Container definitions with more-accurate-for-us ones
ENV  DESCRIPTION="Rubin Science Platform Notebook Aspect"
ENV  SUMMARY="Rubin Science Platform Notebook Aspect"
# Mount configmap at ^^ command/command.json
WORKDIR /tmp
# This needs to be numeric for k8s non-root contexts.  We will
#  replace it with the actual UID in the JupyterHub spawner, but 1000:1000
#  is the container underlying lsst user, here lsst_local (as explained in
#  stage5-ro.sh).  So just in case it's spawned by someone outside a JL
#  context, and they manage to get all the setup env right, still not root.
USER 1000:1000
CMD [ "/opt/lsst/software/jupyterlab/runlab.sh" ]
LABEL description="Rubin Science Platform Notebook Aspect: lsstsqre/sciplat-lab" \
       name="lsstsqre/sciplat-lab" \
       version="exp_w_2021_32_jl3"
