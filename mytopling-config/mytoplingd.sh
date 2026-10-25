#!/bin/bash
# mytoplingd.sh -- run MyTopling the way mysqld runs, with the sideplugin config
# and the MyTopling defaults filled in.
#
#   mytoplingd.sh --initialize-insecure   # bootstrap an empty data directory
#   mytoplingd.sh                         # run in the foreground
#   mytoplingd.sh --daemonize --log-error=/var/log/mytopling.err
#
# Everything mysqld reads (datadir, port, socket, ...) comes from a my.cnf. We
# pass exactly one, $MYTOPLING_CNF, else my.cnf next to this script, else
# <prefix>/etc/my.cnf -- so the machine's /etc/my.cnf, which may belong to
# another MySQL, does not leak in. A caller's --defaults-file or --no-defaults
# replaces that choice; --defaults-extra-file too, and then the machine's files
# are read as well: mysqld reads an extra file only when it has no
# --defaults-file, so we must pass none.
# The sideplugin config, which mysqld has no option for, is $MYTOPLING_CONF,
# else mytopling.json next to this script, else <prefix>/etc, else /etc.
# <prefix> is the parent of this script's directory, i.e. the install prefix.
# Arguments are passed to mysqld as is; as root, add --user=mysql.

set -e
mydir=$(cd "$(dirname "$0")" && pwd)
prefix=$(cd "$mydir/.." && pwd)

conf=${MYTOPLING_CONF:-}
if [ -z "$conf" ]; then
    for c in "$mydir/mytopling.json" "$prefix/etc/mytopling.json" \
             /etc/mytopling.json; do
        if [ -r "$c" ]; then conf=$c; break; fi
    done
fi
[ -n "$conf" ] || {
    echo "mytoplingd: no sideplugin config, set MYTOPLING_CONF or generate one:" >&2
    echo "    mytoplingd-conf.sh > $prefix/etc/mytopling.json" >&2
    exit 1
}

# mysqld only looks for the defaults options before the first other option, so
# the caller's defaults options go first, then our defaults, then the rest.
# --defaults-extra-file counts as the caller's own choice: mysqld reads it only
# when no --defaults-file is given, so our my.cnf would make it dead.
defaults_args=()
rest_args=()
for arg in "$@"; do
    case $arg in
      --defaults-file=*|--defaults-extra-file=*|--defaults-group-suffix=*|\
      --login-path=*|--no-defaults)
        defaults_args+=("$arg");;
      *) rest_args+=("$arg");;
    esac
done
caller_picked=
for arg in "${defaults_args[@]}"; do
    case $arg in
      --defaults-file=*|--defaults-extra-file=*|--no-defaults)
        caller_picked=1;;
    esac
done
cnf=
if [ -z "$caller_picked" ] && [ -n "${MYTOPLING_CNF:-}" ]; then
    cnf="--defaults-file=$MYTOPLING_CNF"
fi
if [ -z "$cnf" ] && [ -z "$caller_picked" ]; then
    for c in "$mydir/my.cnf" "$prefix/etc/my.cnf"; do
        if [ -r "$c" ]; then cnf="--defaults-file=$c"; break; fi
    done
fi
[ -n "$cnf" ] && defaults_args=("$cnf" "${defaults_args[@]}")

export TOPLING_SIDEPLUGIN_CONF=$conf
export PATH=$prefix/bin:$PATH

set -- "${defaults_args[@]}" --rocksdb --default-storage-engine=rocksdb \
       --default-authentication-plugin=mysql_native_password "${rest_args[@]}"
exec mysqld "$@"
