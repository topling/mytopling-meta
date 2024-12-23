# History

For compatibility, MyTopling storage engine is named rocksdb.

## 2024-12-23 version 8.0.28-2
1. Storage engine rocksdb is static linked to mysqld
   * `plugin-load=ha_rocksdb_se.so` is not needed any more
2. Compatibility: Support reverse cf(column family)
   * Only `cfname=rev:order` can be used for reverse cf
   * CFOptions `rev:order` must be defined in side plugin json
   * cf can not be created dynamically, cf spec in `comment`
     must be predefined in sideplugin json
3. Compatibility: Support intrinsic tmp table
