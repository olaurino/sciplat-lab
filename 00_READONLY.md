# Automatic repository checkouts are initially read-only

This repository has been initially checked out read-only.  It will be
refreshed each time you launch a new lab instance, with whatever is
current at launch time.  If you need a copy of the notebooks that were
current when the container was built (rather than when you last started
the container), you can always copy those from
`/opt/lsst/software/notebooks-at-build-time/`.

You will be able to run notebooks in this repository.  However, if you
want to save your changes, you will need to create a directory to which
you do have write access, and save the notebook to that directory.
