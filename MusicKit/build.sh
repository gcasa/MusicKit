#!/bin/sh

echo "### Build MusicKit..."

. ${GNUSTEP_MAKEFILES}/GNUstep.sh

# Build DSP Native
cd Frameworks
cd MKDSP_Native
make debug=yes
sudo ./install.sh

# Build portaudio MIDI
cd ..
cd PlatformDependent
cd MKPerformSndMIDI_portaudio
make debug=yes
sudo ./install.sh

# Build SndKit
cd ../..
cd SndKit
make debug=yes
sudo ./install.sh

# Build MusicKit
cd ../
cd MusicKit
make debug=yes
sudo ./install.sh

echo "### Done"

exit 0
