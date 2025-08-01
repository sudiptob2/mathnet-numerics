FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV VERSION=2024.0
ENV INTEL=/opt/intel
ENV MKL=$INTEL/mkl/$VERSION
ENV OPENMP=$INTEL/compiler/$VERSION

# Install system dependencies
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    g++ \
    g++-multilib \
    libc6-dev-i386 \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install Intel MKL using offline installer as it is not available in the apt repository
RUN mkdir -p /tmp/mkl \
    && cd /tmp/mkl \
    && wget https://registrationcenter-download.intel.com/akdlm/IRC_NAS/86d6a4c1-c998-4c6b-9fff-ca004e9f7455/l_onemkl_p_2024.0.0.49673.sh \
    && chmod +x l_onemkl_p_2024.0.0.49673.sh \
    && mkdir -p /opt/intel \
    && ./l_onemkl_p_2024.0.0.49673.sh -a -s --eula accept --install-dir /opt/intel \
    && rm -rf /tmp/mkl

# Set up environment variables for MKL
ENV LD_LIBRARY_PATH=""
ENV CPATH=""
ENV LIBRARY_PATH=""
ENV LD_LIBRARY_PATH=$MKL/lib/intel64:$OPENMP/lib:$LD_LIBRARY_PATH
ENV CPATH=$MKL/include:$CPATH
ENV LIBRARY_PATH=$MKL/lib/intel64:$OPENMP/lib:$LIBRARY_PATH

WORKDIR /workspace

# Clone MathNet.Numerics repository
RUN git clone https://github.com/mathnet/mathnet-numerics.git .

# Override the MKL build script because it needs some modifications, some of the paths are not correct.
RUN cat > src/NativeProviders/Linux/mkl_build.sh << 'EOF'
export VERSION=2024.0
export INTEL=/opt/intel
export MKL=$INTEL/mkl/$VERSION
export OPENMP=$INTEL/compiler/$VERSION
export OUT=../../../out/MKL/Linux

mkdir -p $OUT/x64
mkdir -p $OUT/x86

g++ -std=c++11 -D_M_X64 -DGCC -m64 --shared -fPIC -o $OUT/x64/libMathNetNumericsMKL.so -I$MKL/include -I../Common -I../MKL ../MKL/memory.c ../MKL/capabilities.cpp ../MKL/vector_functions.c ../Common/blas.c ../Common/lapack.cpp ../MKL/fft.cpp -Wl,--start-group  $MKL/lib/intel64/libmkl_intel_lp64.a $MKL/lib/intel64/libmkl_intel_thread.a $MKL/lib/intel64/libmkl_core.a -Wl,--end-group -L$OPENMP/lib -liomp5 -lpthread -lm

cp $OPENMP/lib/libiomp5.so  $OUT/x64/

g++ -std=c++11 -D_M_IX86 -DGCC -m32 --shared -fPIC -o $OUT/x86/libMathNetNumericsMKL.so -I$MKL/include -I../Common -I../MKL ../MKL/memory.c ../MKL/capabilities.cpp ../MKL/vector_functions.c ../Common/blas.c ../Common/lapack.cpp ../MKL/fft.cpp  -Wl,--start-group $MKL/lib/ia32/libmkl_intel.a $MKL/lib/ia32/libmkl_intel_thread.a $MKL/lib/ia32/libmkl_core.a -Wl,--end-group -L$OPENMP/lib32 -liomp5 -lpthread -lm

cp $OPENMP/lib32/libiomp5.so  $OUT/x86/
EOF

# Make the build script executable
RUN chmod +x src/NativeProviders/Linux/mkl_build.sh

# Set the default command to run the build
CMD ["bash", "-c", "cd src/NativeProviders/Linux && ./mkl_build.sh"] 