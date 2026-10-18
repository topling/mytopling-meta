#!/bin/bash
# mytoplingd-conf.sh -- generate a MyTopling sideplugin config from a template.
#
#   mytoplingd-conf.sh > /opt/mytopling-rls/etc/mytopling.json
#   mytoplingd-conf.sh /data/mytopling > mytopling.json
#   mytoplingd-conf.sh /data/mytopling side-plugin-template-community.json
#
# The datadir is the first absolute argument, else datadir from the my.cnf
# ($MYTOPLING_CNF, else my.cnf next to this script, else
# $MYTOPLING_PREFIX/etc/my.cnf), else mysqld's compiled-in default -- the same
# sources mysqld and mytoplingd.sh use. A non-absolute argument names the
# template.
#
# The template's placeholder directories become hidden directories inside
# <datadir> -- the leading dot matters: --initialize only accepts a datadir
# whose entries all start with '.' (sql_initialize.cc), so these may exist
# before the DB is initialized. Nothing else is rewritten; datadir must be
# absolute.
#   /var/lib/mysql/tmp    -> <datadir>/.tmp       (ToplingZipTable localTempDir:
#                                                  per-process scratch, recreated
#                                                  by mytoplingd.sh on start)
#   /var/lib/mysql/infolog-> <datadir>/.infolog   (document_root, db_log_dir)
#   /path/to/cf_datadir/X -> <datadir>/.X         (encrypt / default_sk / ...)
#   /path/to/sample       -> <datadir>/.sample    (sample)
# Every directory the generated config names is created here, so the config can
# be used as it is.
# The template is the named one, else side-plugin-template-enterprise.json next
# to this script, else in $MYTOPLING_PREFIX/etc (default prefix /opt/mytopling-rls).

set -e
mydir=$(cd "$(dirname "$0")" && pwd)
prefix=${MYTOPLING_PREFIX:-/opt/mytopling-rls}
name=side-plugin-template-enterprise.json

datadir=
tmpl=
for arg in "$@"; do
    case $arg in
      /*) datadir=$arg;;
      *) tmpl=$arg;;
    esac
done

cnf=${MYTOPLING_CNF:-}
if [ -z "$cnf" ]; then
    for c in "$mydir/my.cnf" "$prefix/etc/my.cnf"; do
        if [ -r "$c" ]; then cnf=$c; break; fi
    done
fi
if [ -z "$datadir" ]; then
    if [ -n "$cnf" ]; then
        datadir=$(my_print_defaults --defaults-file="$cnf" mysqld 2>/dev/null |
                  sed -n 's/^--datadir=//p' | tail -1)
    else
        datadir=$(my_print_defaults mysqld 2>/dev/null |
                  sed -n 's/^--datadir=//p' | tail -1)
    fi
fi
if [ -z "$datadir" ]; then
    datadir=$(mysqld --no-defaults --verbose --help 2>/dev/null |
              sed -n 's/^datadir  *//p' | head -1)
fi
datadir=${datadir%/}
case $datadir in
  '') echo "$(basename "$0"): no datadir: pass one, or put datadir= in the my.cnf" >&2
      exit 1;;
  /*) ;;
  *) echo "$(basename "$0"): datadir must be an absolute path" >&2; exit 1;;
esac
case $datadir in
  *'"'*) echo "$(basename "$0"): datadir must not contain a double quote" >&2; exit 1;;
esac

if [ -z "$tmpl" ]; then
    for t in "$mydir/$name" "$prefix/etc/$name"; do
        if [ -r "$t" ]; then tmpl=$t; break; fi
    done
fi
[ -n "$tmpl" ] && [ -r "$tmpl" ] || {
    echo "$(basename "$0"): template not found ($name), pass it as an argument" >&2
    exit 1
}

# the directories the rules above produce -- keep in step with the template's
# uncommented path options (the //cf_paths ones are examples, not real)
mkdir -p "$datadir"
mkdir -p "$datadir/.tmp"
mkdir -p "$datadir/.infolog"
mkdir -p "$datadir/.infolog/.rocksdb"
mkdir -p "$datadir/.encrypt"
mkdir -p "$datadir/.sample/cf"
esc=$(printf '%s' "$datadir" | sed 's/[&#\\]/\\&/g')
out=$(sed -e "s#/var/lib/mysql/tmp#$esc/.tmp#g" \
          -e "s#/var/lib/mysql/infolog#$esc/.infolog#g" \
          -e "s#/var/lib/mysql#$esc#g" \
          -e "s#/path/to/cf_datadir/#$esc/.#g" \
          -e "s#/path/to/sample#$esc/.sample#g" "$tmpl")
if command -v python3 >/dev/null 2>&1; then
    printf '%s\n' "$out" | python3 -c 'import json,sys; json.load(sys.stdin)' || {
        echo "$(basename "$0"): generated config is not valid JSON" >&2
        exit 1
    }
fi
printf '%s\n' "$out"
