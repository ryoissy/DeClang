set -e

POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -a|--arch)
    build_arch="$2"
    shift # past argument
    shift # past value
    ;;
    -h|--help)
    echo "Usage: $0 -a {\"arm64;x86_64\"} " >&2
    exit
    shift # past argument
    ;;
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

if [[ $build_arch == "" ]]; then
  build_arch="x86_64"
fi

pushd $(dirname $0) > /dev/null

cd ../

rm -f clang/lib/Driver/DeClangExtraProcess.cpp
rm -rf llvm/lib/Transforms/AntiHack
rm -rf llvm/include/llvm/Transforms/AntiHack
rm -rf tools

if [[ -e AntiHackDeNA ]]; then
  ln -s ../../../AntiHackDeNA/clang/DeClangExtraProcess.cpp clang/lib/Driver/DeClangExtraProcess.cpp
  ln -s ../../../AntiHackDeNA/src llvm/lib/Transforms/AntiHack
  ln -s ../../../../AntiHackDeNA/include llvm/include/llvm/Transforms/AntiHack
  ln -s AntiHackDeNA/tools tools
else
  ln -s ../../../AntiHackOSS/clang/DeClangExtraProcess.cpp clang/lib/Driver/DeClangExtraProcess.cpp
  ln -s ../../../AntiHackOSS/src llvm/lib/Transforms/AntiHack
  ln -s ../../../../AntiHackOSS/include llvm/include/llvm/Transforms/AntiHack
  ln -s AntiHackOSS/tools tools
fi

if [[ $# -eq 1 && $1 == "toolchain" ]]; then
  echo "build toolchain"
  cd ../
  SKIP_XCODE_VERSION_CHECK=1 ./swift/utils/build-toolchain jp.dena --use-os-runtime
  # popd > /dev/null
  # pushd $(dirname $0) > /dev/null
  # cd ../
  # ln -s build ../build/buildbot_osx/llvm-macosx-x86_64/
  # popd > /dev/null
else
  mkdir -p build/
  cd build/
  if [[ ! -e Makefile ]]; then
    use_ccache="false"
    if [ $(which ccache) ]; then
      use_ccache="true"
    fi

    if [[ "_$OS" = "_Windows_NT" ]]; then
      cmake \
        -DCMAKE_BUILD_TYPE=Release \
        -DLLVM_ENABLE_DUMP=ON \
        -DLLVM_INCLUDE_BENCHMARKS=OFF \
        -DLLVM_INCLUDE_EXAMPLES=OFF \
        -DLLVM_INCLUDE_TESTS=OFF \
        -DLLVM_ENABLE_PROJECTS=clang \
        -DLLVM_CCACHE_BUILD=${use_ccache}\
        -DLLVM_USE_CRT_RELEASE=MT \
        -DLLVM_USE_CRT_RELWITHDEBINFO=MT \
        -A x64\
        -Thost=x64\
          -G "Visual Studio 15 2017" ../llvm

    else
      echo "Build for $build_arch"
      cmake \
        -DLLVM_ENABLE_DUMP=ON \
        -DLLVM_INCLUDE_BENCHMARKS=OFF \
        -DLLVM_INCLUDE_EXAMPLES=OFF \
        -DLLVM_INCLUDE_TESTS=OFF \
        -DCMAKE_BUILD_TYPE=Release \
        -DLLVM_ENABLE_PROJECTS=clang \
        -DCMAKE_OSX_ARCHITECTURES="$build_arch" \
        -DLLVM_CCACHE_BUILD=${use_ccache}\
          -G "Unix Makefiles" ../llvm
    fi

  fi

# -DLLVM_EXPERIMENTAL_TARGETS_TO_BUILD="AARCH64;X64" \

  if [[ "_$OS" = "_Windows_NT" ]]; then
    # TODO Community版以外でも動くようにする
    echo "Build Release x64 in Visual Studio"
    cmd /c '"C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\VC\Auxiliary\Build\vcvars64.bat" && msbuild /p:Configuration=Release;Platform=x64 tools\clang\tools\driver\clang.vcxproj'
  else
   make llvm-headers
   make -j 16
  fi
fi
 
popd > /dev/null
