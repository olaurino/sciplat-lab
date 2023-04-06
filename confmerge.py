import configparser
import os
import shutil
import sys

def merge_ini(src, dest):
    """Merge two INI files, replacing the sections in dest with their
    equivalents in src.

    Parameters
    ----------
    src : `str`
        Path to source INI file.

    dest : `str`
        Path to destination INI file that will have ``src`` merged into it.
    """
    old_config = configparser.ConfigParser()
    old_config.read(dest)
    new_config = configparser.ConfigParser()
    new_config.read(src)
    for sect in new_config.sections():
        old_config[sect] = new_config[sect]
    with open(dest, "w") as result:
        os.chmod(dest, 0o600)
        old_config.write(result)


def merge_pgpass(src, dest):
    """Merge two pgpass files, replacing the entries in dest with their
    equivalents in src.

    Parameters
    ----------
    src : `str`
        Path to source pgpass file.

    dest : `str`
        Path to destination pgpass file that will have ``src`` merged into it.
    """
    config = {}
    with open(dest, "r") as old:
        for line in old:
            if ":" not in line:
                continue
            pg, pw = line.rsplit(":", maxsplit=1)
            config[pg] = pw.rstrip()
    with open(src, "r") as new:
        for line in new:
            if ":" not in line:
                continue
            pg, pw = line.rsplit(":", maxsplit=1)
            config[pg] = pw.rstrip()
    with open(dest, "w") as result:
        os.chmod(dest, 0o600)
        for pg in config:
            print(f"{pg}:{config[pg]}", file=result)


if __name__ == "__main__":
    kind, src, dest = sys.argv[1:4]
    if not os.path.exists(dest):
        shutil.copy(src, dest)
        os.chmod(dest, 0o600)
    elif kind == "ini":
        merge_ini(src, dest)
    elif kind == "pgpass":
        merge_pgpass(src, dest)
    else:
        print(f"Unrecognized file kind: {kind}", file=sys.stderr)
