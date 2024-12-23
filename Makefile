
export SHELL=bash

dummy:=$(shell cd toplingdb-sideplugin; \
               for sub in *; do \
                 if [ ! -e ../toplingdb/sideplugin/$$sub ]; then \
                     pushd ../toplingdb/sideplugin; \
                 ln -sf ../../toplingdb-sideplugin/$$sub $$sub; \
                     popd; \
                 fi; \
               done \
       )

ifeq ($(filter clean%,${MAKECMDGOALS}),)
ifndef PREFIX
  $(error var PREFIX must be defined for toplingdb install)
endif
endif

DEBUG_LEVEL ?= 0
TOPLING_LIB_DIR ?= ${PREFIX}/lib

CMAKE_BUILD_TYPE_0 := Release
CMAKE_BUILD_TYPE_1 := RelWithDebInfo
CMAKE_BUILD_TYPE_2 := Debug
MyToplingBuild := $(shell realpath mytopling/build-${CMAKE_BUILD_TYPE_${DEBUG_LEVEL}})

ifdef CPU
  define errmsg
var CPU=-march=[haswell,...] is for toplingdb, DO NOT use CPU!
                 Use FORCE_CPU_ARCH=[haswell,...], if FORCE_CPU_ARCH is defined,
                 this Makefile will auto set CPU for toplingdb by FORCE_CPU_ARCH
  endef
  $(error ${errmsg})
endif

ifdef FORCE_CPU_ARCH
  # for build toplingdb
  export CPU := -march=${FORCE_CPU_ARCH}
  DFORCE_CPU_ARCH := -DFORCE_CPU_ARCH=${FORCE_CPU_ARCH}
  unexport FORCE_CPU_ARCH
endif
export ROCKSDB_HOME := $(shell realpath toplingdb)
export TERARK_HOME  := $(shell realpath toplingdb-sideplugin/topling-zip)

BOOST_OK_FILE := boost_1_77_0/boost/version.hpp

all: build-toplingdb build-mytopling

build-toplingdb:
	+$(MAKE) -C toplingdb UPDATE_REPO=0 DEBUG_LEVEL=${DEBUG_LEVEL} shared_lib

install-toplingdb: build-toplingdb
	+$(MAKE) -C toplingdb UPDATE_REPO=0 DEBUG_LEVEL=${DEBUG_LEVEL} LIBDIR=${TOPLING_LIB_DIR} install

.PHONY: ${MyToplingBuild}/Makefile
${MyToplingBuild}/Makefile: ${BOOST_OK_FILE}
	cd mytopling; \
	env BUILD_DIR=${MyToplingBuild} \
	    bash -x build.sh \
		-DWITH_UNIT_TESTS=OFF \
		-DTOPLING_LIB_DIR=${TOPLING_LIB_DIR} \
		-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE_${DEBUG_LEVEL}} \
		-DWITH_UNIT_TESTS=OFF \
		${MYTOPLING_CMAKE_EXTRA_ARGS} \
	   ${DFORCE_CPU_ARCH}

# build-mytopling-pre build most componets which not dep on librocksdb.so
build-mytopling-pre: ${MyToplingBuild}/Makefile
	+$(MAKE) -C ${MyToplingBuild} innobase binlog mysqlclient

build-mytopling: install-toplingdb build-mytopling-pre
	+$(MAKE) -C ${MyToplingBuild}

install-mytopling: install-toplingdb build-mytopling
	cmake --install ${MyToplingBuild} --prefix ${PREFIX}
	mv ${PREFIX}/lib/{librocksdb*,libterark*} ${PREFIX}/lib/private/
	rm -f  ${PREFIX}/lib/plugin/libmytopling_dc.so
	rm -fr ${PREFIX}/mysql-test
	rm -fr ${PREFIX}/include

install-dcompact: install-toplingdb build-mytopling
	+$(MAKE) -C toplingdb UPDATE_REPO=0 DEBUG_LEVEL=${DEBUG_LEVEL} LIBDIR=${TOPLING_LIB_DIR} $@
	install  -C -m 755 ${MyToplingBuild}/plugin_output_directory/libmytopling_dc.so ${TOPLING_LIB_DIR}

install: install-mytopling

clean:
	+$(MAKE) -C toplingdb UPDATE_REPO=0 DEBUG_LEVEL=${DEBUG_LEVEL} clean
	rm -rf ${MyToplingBuild}

clean-topling-zip_table_reader:
	+$(MAKE) -C toplingdb UPDATE_REPO=0 DEBUG_LEVEL=${DEBUG_LEVEL} $@

${BOOST_OK_FILE}: boost_1_77_0.tar.bz2
	tar xjf boost_1_77_0.tar.bz2
boost_1_77_0.tar.bz2:
	wget https://boostorg.jfrog.io/artifactory/main/release/1.77.0/source/boost_1_77_0.tar.bz2
