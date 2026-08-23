#!/bin/sh

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$script_dir"

if [ "$(uname -s)" = "Darwin" ]; then
    configuration=${CONFIGURATION:-Development}
    deployment_target=${MACOSX_DEPLOYMENT_TARGET:-13.0}
    derived_data=${DERIVED_DATA_PATH:-"$script_dir/../.build/DerivedData"}

    echo "### Configure MusicKit"
    ./configure

    for scheme in \
        "Frameworks Only (Aggregate)" \
        "Utilities Only (Aggregate)" \
        "Examples Only (Aggregate)" \
        "Applications Only (Aggregate)"
    do
        echo "### Build $scheme"
        xcodebuild \
            -project MusicKit.xcodeproj \
            -scheme "$scheme" \
            -configuration "$configuration" \
            -derivedDataPath "$derived_data" \
            CODE_SIGNING_ALLOWED=NO \
            CONFIGURED_LIBS= \
            DYLIB_INSTALL_NAME_BASE=@rpath \
            'LD_RUNPATH_SEARCH_PATHS=@executable_path @executable_path/../../..' \
            MACOSX_DEPLOYMENT_TARGET="$deployment_target" \
            build
    done

    echo "### Products: $derived_data/Build/Products/$configuration"
    exit 0
fi

if [ -z "${GNUSTEP_MAKEFILES:-}" ]; then
    echo "GNUSTEP_MAKEFILES must be set for a GNUstep build" >&2
    exit 1
fi

echo "### Build MusicKit with GNUstep"
. "$GNUSTEP_MAKEFILES/GNUstep.sh"
make debug=yes
