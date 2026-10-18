#!/bin/bash
# mytoplingd.sh -- run MyTopling the way mysqld runs, with the sideplugin config
# and the MyTopling defaults filled in.
#
#   mytoplingd.sh --initialize-insecure   # bootstrap an empty data directory
#   mytoplingd.sh                         # run in the foreground
#   mytoplingd.sh --daemonize --log-error=/var/log/mytopling.err
#
# Everything mysqld reads (datadir, port, socket, ...) comes from a my.cnf: the
# caller's own --defaults-file/--no-defaults wins, else my.cnf next to this
# script, else $MYTOPLING_PREFIX/etc/my.cnf (so the machine's /etc/my.cnf, which
# may belong to another MySQL, does not leak in), else mysqld's search order.
# The sideplugin config, which mysqld has no option for, is $MYTOPLING_CONF,
# else mytopling.json next to this script, else $MYTOPLING_PREFIX/etc, else
# /etc. Arguments are passed to mysqld as is; as root, add --user=mysql.

set -e
mydir=$(cd "$(dirname "$0")" && pwd)
prefix=${MYTOPLING_PREFIX:-/opt/mytopling-rls}

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

caller_picked=
for arg in "$@"; do
    case $arg in --defaults-file=*|--no-defaults) caller_picked=1;; esac
done
cnf=
if [ -z "$caller_picked" ]; then
    for c in "$mydir/my.cnf" "$prefix/etc/my.cnf"; do
        if [ -r "$c" ]; then cnf="--defaults-file=$c"; break; fi
    done
fi

export TOPLING_SIDEPLUGIN_CONF=$conf
export PATH=$prefix/bin:$PATH

# our defaults go after the caller's, so they can override them; our my.cnf (if
# any) goes in front, where mysqld wants a defaults file
set -- "$@" --rocksdb --default-storage-engine=rocksdb \
       --default-authentication-plugin=mysql_native_password
[ -n "$cnf" ] && set -- "$cnf" "$@"
exec mysqld "$@"
