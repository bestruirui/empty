#!/bin/bash

# Exit on error
set -e

# App information
APP_NAME="bestsub"
BUILT_DATA="$(TZ='Asia/Shanghai' date +'%F %T %z')"
GIT_AUTHOR="bestrui"
GIT_VERSION=$(git describe --tags --abbrev=0)

# Build flags
LDFLAGS="-X 'main.Version=${GIT_VERSION}' \
         -X 'main.BuildTime=${BUILT_DATA}' \
         -X 'main.Author=${GIT_AUTHOR}'"
MUSL_FLAGS="--extldflags '-static -fpic' ${LDFLAGS}"

# Build tools
MUSL_BASE="https://musl.cc/"
ANDROID_NDK_BASE="https://dl.google.com/android/repository/"
ANDROID_NDK_VERSION="r27c"
TOOLCHAIN_DIR="$HOME/.bestsub/toolchains"

# Build arch
ARCHS=(
    x86_64    # 64-bit Intel/AMD architecture
    x86       # 32-bit Intel/AMD architecture
    arm64     # 64-bit ARM architecture (AArch64)
    arm     # 32-bit ARM architecture (ARMv7)
)
# Build target
TARGETS=(
    linux 
    windows 
    darwin 
    android
)

# Prepare build environment
prepare_build() {
    echo "Preparing build environment..."
    mkdir -p "dist"
}


# Get MUSL architecture name
setup_musl_toolchain() {
    local arch=$1
    local musl_arch
    local download_url

    case $arch in
        "x86_64")
            musl_arch="x86_64"
            download_url="${MUSL_BASE}${musl_arch}-linux-musl-cross.tgz"
            ;;
        "arm64")
            musl_arch="aarch64"
            download_url="${MUSL_BASE}${musl_arch}-linux-musl-cross.tgz"
            ;;
        "x86")  
            musl_arch="i686"
            download_url="${MUSL_BASE}${musl_arch}-linux-musl-cross.tgz"
            ;;
        "arm")
            musl_arch="arm"
            download_url="${MUSL_BASE}${musl_arch}-linux-musleabihf-cross.tgz"
            ;;
        *)
            echo "Unsupported architecture: $arch"
            return 1
            ;;
    esac
    
    echo "Setting up MUSL toolchain for $arch..."
    if [ ! -d "$TOOLCHAIN_DIR/musl/${musl_arch}/bin" ]; then
        mkdir -p "$TOOLCHAIN_DIR/musl/${musl_arch}"
        echo "Downloading ${download_url}..."
        curl -s -L -o /tmp/${musl_arch}-linux-musl.tgz "${download_url}" > /dev/null 2>&1
        echo "Extracting ${musl_arch}-linux-musl.tgz..."
        sudo tar xf /tmp/${musl_arch}-linux-musl.tgz --strip-components 1 -C "$TOOLCHAIN_DIR/musl/${musl_arch}"
        rm /tmp/${musl_arch}-linux-musl.tgz
        echo "MUSL toolchain for $arch setup completed"
    else
        echo "MUSL toolchain for $arch already exists"
    fi
}

setup_android_toolchain() {
    if [ ! -d "$TOOLCHAIN_DIR/android-ndk" ]; then
        echo "Downloading Android NDK ${ANDROID_NDK_VERSION}..."
        curl -L -o /tmp/android-ndk-${ANDROID_NDK_VERSION}.zip "${ANDROID_NDK_BASE}android-ndk-${ANDROID_NDK_VERSION}-linux.zip" > /dev/null 2>&1
        mkdir -p "$TOOLCHAIN_DIR/android-ndk"
        echo "Extracting android-ndk-${ANDROID_NDK_VERSION}.zip..."
        sudo unzip -q /tmp/android-ndk-${ANDROID_NDK_VERSION}.zip -d "$TOOLCHAIN_DIR/android-ndk"
        rm /tmp/android-ndk-${ANDROID_NDK_VERSION}.zip
        echo "Android NDK ${ANDROID_NDK_VERSION} setup completed"
    else
        echo "Android NDK ${ANDROID_NDK_VERSION} already exists"
    fi
}

setup_linux_toolchain() {
    local arch=$1
    sudo apt update
    case $arch in
        "x86_64")
            sudo apt install -y gcc
            ;;
        "arm64")
            sudo apt install -y gcc-aarch64-linux-gnu
            ;;
        "x86")
            sudo apt install -y gcc-i686-linux-gnu
            ;;
        "arm")
            sudo apt install -y gcc-arm-linux-gnueabihf
            ;;
        *)
            echo "Unsupported architecture: $arch"
            return 1
            ;;
    esac
}


# Build for standard Linux
build_linux() {
    local arch=$1
    local cgo_cc
    local cgo_arch

    case $arch in
        "x86_64")
            cgo_arch=amd64
            cgo_cc="gcc"
            ;;
        "arm64")
            cgo_arch=arm64
            cgo_cc="aarch64-linux-gnu-gcc"
            ;;
        "x86")
            cgo_arch=386
            cgo_cc="i686-linux-gnu-gcc"
            ;;
        "arm")
            cgo_arch=arm
            cgo_cc="arm-linux-gnueabihf-gcc"
            ;;
        *)
            echo "Unsupported architecture: $arch"
            return 1
            ;;
    esac

    echo "Building Linux ${arch}..."
    GOOS=linux GOARCH=${cgo_arch} CGO_ENABLED=1 CC=${cgo_cc} \
        go build -o "./dist/${APP_NAME}-linux-${arch}" -ldflags="${LDFLAGS}" -tags=jsoniter ./cmd/server
    echo "Linux ${arch} build completed"
}

# Build for Linux MUSL
build_linux_musl() {
    local arch=$1
    local cgo_cc
    local cgo_arch

    case $arch in
        "x86_64")
            cgo_arch=amd64
            cgo_cc="${TOOLCHAIN_DIR}/musl/x86_64/bin/x86_64-linux-musl-gcc"
            ;;
        "arm64")
            cgo_arch=arm64
            cgo_cc="${TOOLCHAIN_DIR}/musl/aarch64/bin/aarch64-linux-musl-gcc"
            ;;
        "x86")
            cgo_arch=386
            cgo_cc="${TOOLCHAIN_DIR}/musl/i686/bin/i686-linux-musl-gcc"
            ;;
        "arm")
            cgo_arch=arm
            cgo_cc="${TOOLCHAIN_DIR}/musl/arm/bin/arm-linux-musleabihf-gcc"
            ;;
        *)
            echo "Unsupported architecture: $arch"
            return 1
            ;;
    esac

    echo "Building Linux MUSL ${arch}..."
    GOOS=linux GOARCH=${cgo_arch} CGO_ENABLED=1 CC=${cgo_cc} \
        go build -o "./dist/${APP_NAME}-linux-musl-${arch}" -ldflags="${MUSL_FLAGS}" -tags=jsoniter ./cmd/server
    echo "Linux MUSL ${arch} build completed"
}

# Build for Windows
build_windows() {
    echo "Building for Windows..."
    if ! xgo -targets=windows/amd64 -out "${APP_NAME}" -ldflags="${LDFLAGS}" -tags=jsoniter -pkg ./cmd/server .; then
        echo "Failed to build for Windows"
        return 1
    fi
    
    # Compress Windows executable with UPX
    if [ -f "${APP_NAME}-windows-amd64.exe" ]; then
        echo "Compressing Windows executable with UPX..."
        mv "${APP_NAME}-windows-amd64.exe" "dist/${APP_NAME}-windows-amd64.exe"
        cp "./dist/${APP_NAME}-windows-amd64.exe" "./dist/${APP_NAME}-windows-amd64-upx.exe"
        upx -9 "./dist/${APP_NAME}-windows-amd64-upx.exe"
    fi
}

# Build for Darwin (macOS)
build_darwin() {
    echo "Building for Darwin (macOS)..."
    if ! xgo -targets=darwin/amd64,darwin/arm64 -out "${APP_NAME}" -ldflags="${LDFLAGS}" -tags=jsoniter -pkg ./cmd/server .; then
        echo "Failed to build for Darwin"
        return 1
    fi
    mv ${APP_NAME}-darwin-* dist/
}

build_android() {
    bin_path="${TOOLCHAIN_DIR}/android-ndk/android-ndk-${ANDROID_NDK_VERSION}/toolchains/llvm/prebuilt/linux-x86_64/bin"
    local arch=$1
    local cgo_cc
    local cgo_arch
    
    case $arch in
        "x86_64")
            cgo_cc="x86_64-linux-android24-clang"
            cgo_arch="amd64"
            ;;
        "arm64")
            cgo_cc="aarch64-linux-android24-clang"
            cgo_arch="arm64"
            ;;
        "arm")
            cgo_cc="armv7a-linux-androideabi24-clang"
            cgo_arch="arm"
            ;;
        "x86")
            cgo_cc="i686-linux-android24-clang"
            cgo_arch="386"
            ;;
        *)
            echo "Unsupported architecture: $1"
            return 1
            ;;
    esac
    echo "Building android ${arch}..."
    GOOS=android GOARCH=${cgo_arch} CC=${bin_path}/${cgo_cc} CGO_ENABLED=1 \
        go build -o "./dist/${APP_NAME}-android-${arch}" -ldflags="${LDFLAGS}" -tags=jsoniter ./cmd/server
    ${bin_path}/llvm-strip "./dist/${APP_NAME}-android-${arch}"
    echo "Android ${arch} build completed"
}

# Compress built files
compress_files() {
    echo "Compressing built files..."
    cd dist
    
    # Copy README.md and LICENSE to dist directory
    cp ../README.md ../LICENSE ./
    
    # Compress Linux and Darwin builds to tar.gz
    echo "Compressing Linux and Darwin builds..."
    for file in ${APP_NAME}-linux-* ${APP_NAME}-darwin-* ${APP_NAME}-android-*; do
        if [ -f "$file" ]; then
            tar -czf "${file}.tar.gz" "$file" README.md LICENSE
            rm "$file"
        fi
    done
    
    # Compress Windows builds to zip
    echo "Compressing Windows builds..."
    for file in ${APP_NAME}-windows-*; do
        if [ -f "$file" ]; then
            zip "${file%.*}.zip" "$file" README.md LICENSE
            rm "$file"
        fi
    done
    
    # Clean up copied files
    rm README.md LICENSE
    
    cd ..
}

# Generate checksums
generate_checksums() {
    echo "Generating MD5 checksums..."
    cd dist
    find . -type f -print0 | xargs -0 md5sum > md5.txt
    cat md5.txt
    cd ..
}

# Build menu function
show_menu() {
    echo "请选择编译架构:"
    select arch in "${ARCHS[@]}" "全部"; do
        if [[ -n $arch ]]; then
            if [[ $arch == "全部" ]]; then
                selected_archs=("${ARCHS[@]}")
            else
                selected_archs=("$arch")
            fi
            break
        fi
    done

    echo "请选择目标平台:"
    select target in "${TARGETS[@]}" "全部"; do
        if [[ -n $target ]]; then
            if [[ $target == "全部" ]]; then
                selected_targets=("${TARGETS[@]}")
            else
                selected_targets=("$target")
            fi
            break
        fi
    done
}

# Modified main process
main() {
    prepare_build
    
    if [[ $1 == "release" ]]; then
        echo "Release 模式: 编译所有架构和平台组合"
        selected_archs=("${ARCHS[@]}")
        selected_targets=("${TARGETS[@]}")
    else
        show_menu
    fi

    for target in "${selected_targets[@]}"; do
        case $target in
            "linux")
                for arch in "${selected_archs[@]}"; do
                    build_linux_musl "$arch"
                done
                build_linux
                ;;
            "windows")
                build_windows
                ;;
            "darwin")
                build_darwin
                ;;
            "android")
                build_android
                ;;
        esac
    done

    compress_files
    generate_checksums
    echo "Build completed successfully!"
}

# Run the main process with command line argument
# main "$1"

setup_musl_toolchain arm
build_linux_musl arm
setup_musl_toolchain arm64
build_linux_musl arm64
setup_musl_toolchain x86_64
build_linux_musl x86_64
setup_musl_toolchain x86
build_linux_musl x86

setup_android_toolchain
build_android x86_64
build_android x86
build_android arm
build_android arm64

setup_linux_toolchain x86_64
build_linux x86_64