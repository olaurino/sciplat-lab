#!/bin/sh
set -e
source ${LOADRSPSTACK}

# This is to work around a problem in JL 3.4.0 and can eventually be removed
crypto_workaround() {
    owd=$(pwd)
    current_scipipe=$(ls /opt/lsst/software/stack/conda/current/envs | \
			  grep '^lsst-scipipe-' | tail -1)
    cd /opt/lsst/software/stack/conda/current/envs/${current_scipipe}
    current_python=$(ls lib | grep ^python | tail -1)
    cd lib/${current_python}/site-packages/jupyterlab/staging

    # Forgive me for what I am about to do
    sed -i.bak -e 's/^    plugins$/    plugins,\n    resolve: {\n      fallback: {\n        crypto: false,\n      },\n    }/' webpack.config.js
    cd ${owd}
}

# Server, notebook, and lab extensions
svxt="jupyter_firefly_extensions \
      jupyterlab_iframe"
nbxt="widgetsnbextension"
lbxt="ipyvolume \
      jupyterlab_iframe \
      ipyevents \
      jupyter_firefly_extensions"

# Don't understand why
#  jupyter serverextension enable panel.io.jupyter_server_extension
# fails here, but we'll just put it into the jupyter_notebook_config.json
for s in $svxt; do
    jupyter serverextension enable ${s} --py --sys-prefix
done
for n in $nbxt; do
    jupyter nbextension install ${n} --py --sys-prefix
    jupyter nbextension enable ${n} --py  --sys-prefix
done
for l in ${lbxt}; do
    jupyter labextension install ${l} --no-build
done

for l in ${lbxt} ; do
    jupyter labextension enable ${l}
done
# File sharing doesn't work in the RSP environment, so remove the extension.
jupyter labextension disable \
	"@jupyterlab/filebrowser-extension:share-file"

# Rebuild the world.
npm cache clean --force
jupyter lab clean
crypto_workaround
jupyter lab build --dev-build=False

# List installed labextensions and put them into a format we could consume
#  for installation
jupyter labextension list 2>&1 | \
      grep '^      ' | grep -v ':' | grep -v 'OK\*' | \
      awk '{print $1,$2}' | tr ' ' '@' > ${verdir}/labext.txt
