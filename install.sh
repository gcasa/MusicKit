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
    echo "Builds and installs the legacy MusicKit apps and their frameworks."
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
if [ ! -d "$products_dir/ScorePlayer.app" ]; then
    echo "MusicKit applications have not been built at: $products_dir" >&2
    echo "Run without --skip-build, or set CONFIGURATION and DERIVED_DATA_PATH correctly." >&2
    exit 1
fi

mkdir -p "$install_dir"

app_list=$(find "$products_dir" -type d -name '*.app' -prune | sort)
if [ -z "$app_list" ]; then
    echo "No application bundles were found in: $products_dir" >&2
    exit 1
fi

echo "### Install all MusicKit applications into $install_dir"
installed_app_count=0
while IFS= read -r app_source
do
    app_name=$(basename "$app_source")
    echo "    $app_name"
    /usr/bin/ditto "$app_source" "$install_dir/$app_name"
    installed_app_count=$((installed_app_count + 1))
done <<EOF
$app_list
EOF

for framework in MusicKit SndKit MKDSP MKPerformSndMIDI
do
    framework_source="$products_dir/$framework.framework"
    if [ ! -d "$framework_source" ]; then
        echo "Required framework is missing: $framework_source" >&2
        exit 1
    fi
    /usr/bin/ditto "$framework_source" "$install_dir/$framework.framework"
done

echo "### Verify installed ScorePlayer audio output"
"$install_dir/ScorePlayer.app/Contents/MacOS/ScorePlayer" --audio-self-test

verified_app_count=0
while IFS= read -r app_source
do
    app_name=$(basename "$app_source")
    if [ ! -x "$install_dir/$app_name/Contents/MacOS/$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$install_dir/$app_name/Contents/Info.plist")" ]; then
        echo "Installed application is missing its executable: $app_name" >&2
        exit 1
    fi
    verified_app_count=$((verified_app_count + 1))
done <<EOF
$app_list
EOF

if [ "$verified_app_count" -ne "$installed_app_count" ]; then
    echo "Application installation verification failed." >&2
    exit 1
fi

echo "### Installation complete"
echo "Installed applications: $installed_app_count"
echo "Applications are installed in: $install_dir"
