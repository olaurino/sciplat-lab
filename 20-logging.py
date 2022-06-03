"""Set up custom logging for RSP.

At startup, if ${HOME}/.ipython/profile_default/startup/20-logging.py does
not exist, this file will be copied to it from /opt/lsst/software/jupyterlab.

If you don't like what it does, create an empty file at
 ${HOME}/.ipython/profile_default/startup/20-logging.py and it will not
be recopied.
"""

import logging
import os
import sys


customlogger = False

try:
    from lsst.rsp import IPythonHandler, forward_lsst_log

    customlogger = True
except ImportError:
    pass  # Probably a container that doesn't have our new code

# If the whole container is in debug mode, enable debug logging by default.
#  Otherwise, set info as the default level.
t_level = "INFO"
level = logging.INFO
debug = os.getenv("DEBUG")
if debug:
    t_level = "DEBUG"
    level = logging.DEBUG
# Set up WARNING and above as stderr, below that to stdout.
handlers = [
    logging.StreamHandler(level=logging.WARNING),
    logging.StreamHandler(level=level, stream=sys.stdout),
]
if customlogger:
    forward_lsst_log(t_level)
    handlers = [IPythonHandler()]
logging.basicConfig(force=True, handlers=handlers)
