# MyTopling Meta Repository

## Prerequisite on CentOS
```bash
sudo yum install yum-utils epel-release -y
sudo yum config-manager --set-enabled powertools # CentOS-8
sudo yum config-manager --set-enabled crb        # CentOS-9
sudo yum install -y liburing-devel git gflags-devel libcurl-devel \
    snappy-devel zlib-devel bzip2-devel lz4-devel libaio-devel \
    cmake nfs-utils openssl-devel ncurses-devel libtirpc-devel \
    rpcgen bison libudev-devel gcc-toolset-12 python3 which rpm-build
```

## Prerequisite on Debian & Ubuntu
* Debian: Must be Debian version 12+
* Ubuntu: Must be Ubuntu version 24+
```bash
sudo apt-get update -y
sudo apt-get install -y gcc-12 libjemalloc-dev libaio-dev libgflags-dev \
    zlib1g-dev libbz2-dev libcurl4-gnutls-dev liburing-dev libsnappy-dev \
    libbz2-dev liblz4-dev libzstd-dev which python3 cmake libncurses5-dev \
    pkg-config bison libudev-dev git libssl-dev
sudo apt-get install -y wget
# mytopling-8.0.32 prerequisites:
sudo apt-get install -y libopenblas-dev libopenblas-openmp-dev libomp-dev gfortran
```

1. Maybe needs to make soft link:
```bash
ln -s libgfortran.so.5 /usr/lib/x86_64-linux-gnu/libgfortran.so
```
2. Maybe needs to add extra args or export env when calling make:
```bash
MYTOPLING_CMAKE_EXTRA_ARGS="-DWITH_OPENMP=/usr/lib/llvm-18"
```

## Before Compile
```bash
git clone https://github.com/topling/mytopling-meta.git
cd mytopling-meta
git submodule update --init --recursive --depth 1
# source /opt/rh/gcc-toolset-12/enable # changing gcc version for CentOS
```

## Compile & Install

Pass `PREFIX` as install prefix, default make do compile.

```bash
make -j`nproc` PREFIX=/absolute/path # also need PREFIX
make -j`nproc` PREFIX=/absolute/path install
```

For build old CPU target on new CPU, use:
```bash
# sandybridge is an old x86_64 CPU
make -j`nproc` PREFIX=/absolute/path FORCE_CPU_ARCH=sandybridge
```

Install dcompact_worker and mytopling dcompact shared lib:
```bash
make -j`nproc` PREFIX=/absolute/path/for/dcompact install-dcompact
```

## Notes
* MyTopling-8.0.32 use ToplingDB-8.10.2
* MyTopling-8.0.28 use ToplingDB-8.04.2

## Known issues
mysqld may can not graceful stopped, it will coredump on stop, but this has no known harm.
