#!/bin/bash

set -e

# Configure paths
export MKL=/opt/intel/oneapi/mkl/latest
export COMPILER=/opt/intel/oneapi/compiler/2025.2
export OPENMP=$COMPILER/lib
export OUT=../../../out/MKL/Linux

# Create output directories
mkdir -p $OUT/x64
mkdir -p $OUT/x86

echo "Building x64..."
g++ -std=c++11 -D_M_X64 -DGCC -m64 --shared -fPIC -o $OUT/x64/libMathNetNumericsMKL.so \
  -I$MKL/include \
  -I../Common \
  -I../MKL \
  ../MKL/memory.c \
  ../MKL/capabilities.cpp \
  ../MKL/vector_functions.c \
  ../Common/blas.c \
  ../Common/lapack.cpp \
  ../MKL/fft.cpp \
  -Wl,--start-group \
    $MKL/lib/libmkl_intel_lp64.a \
    $MKL/lib/libmkl_core.a \
    $MKL/lib/libmkl_intel_thread.a \
  -Wl,--end-group \
  -L$OPENMP \
  -liomp5 -lpthread -lm

cp $OPENMP/libiomp5.so $OUT/x64/
echo "x64 build complete."

if [ -d "$MKL/lib/ia32" ]; then
    echo "Building x86 (using ia32 static libraries)..."
    g++ -std=c++11 -D_M_IX86 -DGCC -m32 --shared -fPIC -o $OUT/x86/libMathNetNumericsMKL.so \
      -I$MKL/include \
      -I../Common \
      -I../MKL \
      ../MKL/memory.c \
      ../MKL/capabilities.cpp \
      ../MKL/vector_functions.c \
      ../Common/blas.c \
      ../Common/lapack.cpp \
      ../MKL/fft.cpp \
      -Wl,--start-group \
        $MKL/lib/ia32/libmkl_intel.a \
        $MKL/lib/ia32/libmkl_core.a \
        $MKL/lib/ia32/libmkl_intel_thread.a \
      -Wl,--end-group \
      -L$OPENMP \
      -liomp5 -lpthread -lm

    cp $OPENMP/libiomp5.so $OUT/x86/
    echo "x86 build complete."
elif [ -d "/opt/intel/oneapi/mkl/2024.0/lib32" ]; then
    echo "Building x86 (using 2024.0 shared libraries)..."
    g++ -std=c++11 -D_M_IX86 -DGCC -m32 --shared -fPIC -o $OUT/x86/libMathNetNumericsMKL.so \
      -I$MKL/include \
      -I../Common \
      -I../MKL \
      ../MKL/memory.c \
      ../MKL/capabilities.cpp \
      ../MKL/vector_functions.c \
      ../Common/blas.c \
      ../Common/lapack.cpp \
      ../MKL/fft.cpp \
      -L/opt/intel/oneapi/mkl/2024.0/lib32 \
      -lmkl_intel -lmkl_core -lmkl_intel_thread \
      -L/opt/intel/oneapi/compiler/2024.0/lib32 \
      -liomp5 -lpthread -lm

    cp /opt/intel/oneapi/compiler/2024.0/lib32/libiomp5.so $OUT/x86/
    echo "x86 build complete."
else
    echo "ERROR: 32-bit MKL libraries not found. x86 build is required."
    echo "Please install 32-bit Intel MKL libraries:"
    echo "  sudo apt-get install intel-oneapi-mkl-32bit-2024.0"
    exit 1
fi