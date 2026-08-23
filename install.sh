#!/bin/sh

set -eu

repository_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
configuration=${CONFIGURATION:-Development}
derived_data=${DERIVED_DATA_PATH:-"$repository_dir/.build/DerivedData"}
install_dir=${INSTALL_DIR:-"$HOME/Applications/MusicKit"}

usage()
{
    echo "Usage: $0 [--skip-build] [destination]"
    echo
    echo "Builds and installs ScorePlayer with its MusicKit frameworks."
    echo "The default destination is: $HOME/Applications/MusicKit"
}

build=yes
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    usage
    exit 0
fi
if [ "${1:-}" = "--skip-build" ]; then
    build=no
    shift
fi
if [ "$#" -gt 1 ]; then
    usage >&2
    exit 2
fi
if [ "$#" -eq 1 ]; then
    install_dir=$1
fi

if [ "$(uname -s)" != "Darwin" ]; then
    echo "This installer requires macOS." >&2
    exit 1
fi

if [ "$build" = yes ]; then
    "$repository_dir/MusicKit/build.sh"
fi

products_dir="$derived_data/Build/Products/$configuration"
app_source="$products_dir/ScorePlayer.app"

if [ ! -d "$app_source" ]; then
    echo "ScorePlayer has not been built at: $app_source" >&2
    echo "Run without --skip-build, or set CONFIGURATION and DERIVED_DATA_PATH correctly." >&2
    exit 1
fi

mkdir -p "$install_dir"

echo "### Install ScorePlayer into $install_dir"
/usr/bin/ditto "$app_source" "$install_dir/ScorePlayer.app"

for framework in MusicKit SndKit MKDSP MKPerformSndMIDI
do
    framework_source="$products_dir/$framework.framework"
    if [ ! -d "$framework_source" ]; then
        echo "Required framework is missing: $framework_source" >&2
        exit 1
    fi
    /usr/bin/ditto "$framework_source" "$install_dir/$framework.framework"
done

echo "### Verify installed audio output"
"$install_dir/ScorePlayer.app/Contents/MacOS/ScorePlayer" --audio-self-test

echo "### Installation complete"
echo "Launch with: open \"$install_dir/ScorePlayer.app\""
