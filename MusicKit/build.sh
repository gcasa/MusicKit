#!/bin/sh

# Build DSP Native
cd Frameworks
cd MKDSP_Native
make debug=yes

# Build portaudio MIDI
cd ..
cd PlatformDependent
cd MKPerformSndMIDI_portaudio
make debug=yes

# Build SndKit
cd ../..
cd SndKit
make debug=yes

# Build MusicKit
cd ../
cd MusicKit
make debug=yes
