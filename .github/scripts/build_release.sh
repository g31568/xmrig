#!/usr/bin/env bash
# Build and package a binary that does not require third-party libraries on the target machine.
set -euo pipefail

target=${1:?Expected windows-x86-64-v3, linux-x86-64-v3, or macos-arm64}
options=(-DCMAKE_BUILD_TYPE=Release -DCMAKE_EXPORT_COMPILE_COMMANDS=ON)
case "$target" in
    windows-x86-64-v3)
        options+=(-G Ninja -DXMRIG_DEPS="$PWD/deps/gcc/x64"
            -DCMAKE_C_FLAGS=-march=x86-64-v3 -DCMAKE_CXX_FLAGS=-march=x86-64-v3)
        ;;
    linux-x86-64-v3)
        (cd scripts && ./build_deps.sh)
        options+=(-DXMRIG_DEPS="$PWD/scripts/deps" -DBUILD_STATIC=ON
            -DCMAKE_C_FLAGS=-march=x86-64-v3 -DCMAKE_CXX_FLAGS=-march=x86-64-v3)
        ;;
    macos-arm64)
        [[ $(uname -m) == arm64 ]] || { echo 'An ARM64 macOS runner is required' >&2; exit 1; }
        (cd scripts && ./build_deps.sh)
        options+=(-DXMRIG_DEPS="$PWD/scripts/deps" -DCMAKE_OSX_ARCHITECTURES=arm64 -DARM_V8=ON)
        ;;
    *) echo "Unknown target: $target" >&2; exit 1 ;;
esac
cmake -S . -B build "${options[@]}"
cmake --build build --parallel "$(getconf _NPROCESSORS_ONLN 2>/dev/null || sysctl -n hw.logicalcpu)"

package="xmrig-$target"
mkdir -p "dist/$package"
cp LICENSE src/config.json "dist/$package/"
if [[ "$target" == windows-* ]]; then
    cp build/xmrig.exe build/WinRing0x64.sys "dist/$package/"
    cp build/*.cmd "dist/$package/"
    # Reject unexpected non-system DLL imports before publishing a standalone Windows binary.
    imports=$(objdump -p build/xmrig.exe | awk '/DLL Name:/ {print tolower($3)}')
    if printf '%s\n' "$imports" | grep -Ev '^(kernel32|advapi32|bcrypt|crypt32|dbghelp|iphlpapi|msvcrt|ole32|psapi|shell32|user32|userenv|ws2_32|ntdll|ucrtbase)\.dll$|^api-ms-win-.*\.dll$'; then
        echo 'Unexpected runtime DLL dependency' >&2
        exit 1
    fi
    "dist/$package/xmrig.exe" --version
    "dist/$package/xmrig.exe" --help | grep -F 'donate level, default 0%'
    (cd dist && zip -r "$package.zip" "$package")
else
    cp build/xmrig "dist/$package/"
    if [[ "$target" == macos-* ]]; then
        file build/xmrig | grep -q 'arm64'
        # Homebrew paths and loader-relative dependencies would make the archive nonportable.
        otool -L build/xmrig
        if otool -L build/xmrig | tail -n +2 | awk '{print $1}' | grep -Ev '^(/usr/lib/|/System/Library/)'; then
            echo 'Unexpected non-system macOS library dependency' >&2
            exit 1
        fi
    else
        file build/xmrig | grep -q 'statically linked'
    fi
    "dist/$package/xmrig" --version
    "dist/$package/xmrig" --help | grep -F 'donate level, default 0%'
    tar -czf "dist/$package.tar.gz" -C dist "$package"
fi
