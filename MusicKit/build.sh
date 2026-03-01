#!/bin/sh

#
# Build the entire musickit set of frameworks for the locallly
# installed version of GNUstep.  This script should simplify
# that process. GC
#

echo "### Build MusicKit..."
echo ""

. ${GNUSTEP_MAKEFILES}/GNUstep.sh

# Build DSP Native
cd Frameworks
cd MKDSP_Native
make debug=yes
sudo ./install.sh

# Build portaudio MIDI
cd ../
cd PlatformDependent
cd MKPerformSndMIDI_portaudio
make debug=yes
sudo ./install.sh

# Build SndKit
cd ../../
cd SndKit
make debug=yes
sudo ./install.sh

# Build MusicKit
cd ../
cd MusicKit
make debug=yes
sudo ./install.sh

# Build all Applications
cd ../../
cd Applications
make debug=yes
sudo ./install.sh

echo ""
echo "### Done"

exit 0
