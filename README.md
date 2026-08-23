# MusicKit
The MusicKit &amp; SndKit is an object-oriented software system for building music, sound, signal processing &amp; MIDI applications.

See the README under MusicKit for full details.

## Building on macOS

Install the current Xcode command-line tools, then run:

```sh
./MusicKit/build.sh
```

The script configures optional features and builds the native frameworks,
command-line utilities, examples, and applications without requiring a
system-wide framework installation or code-signing identity. Products are
written to `.build/DerivedData/Build/Products/Development`.

For example:

```sh
.build/DerivedData/Build/Products/Development/sndinfo sound.snd
open .build/DerivedData/Build/Products/Development/ScorePlayer.app
```

Set `CONFIGURATION` or `MACOSX_DEPLOYMENT_TARGET` in the environment to
override the defaults. Optional MP3, Ogg/Vorbis, libsndfile, and streaming
support is disabled when those third-party libraries are unavailable; native
macOS audio and MIDI support remains enabled.
