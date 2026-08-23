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

ScorePlayer uses the built-in macOS DLS software synthesizer for legacy DSP
score parts. Its audio path and score playback can be checked without the UI:

```sh
.build/DerivedData/Build/Products/Development/ScorePlayer.app/Contents/MacOS/ScorePlayer --audio-self-test
.build/DerivedData/Build/Products/Development/ScorePlayer.app/Contents/MacOS/ScorePlayer --play-score MusicKit/Music/Scorefiles/Examp1.score
```

Set `CONFIGURATION` or `MACOSX_DEPLOYMENT_TARGET` in the environment to
override the defaults. Optional MP3, Ogg/Vorbis, libsndfile, and streaming
support is disabled when those third-party libraries are unavailable; native
macOS audio and MIDI support remains enabled.

## Installing ScorePlayer

Install ScorePlayer and its required frameworks with:

```sh
./install.sh
```

The default destination is `~/Applications/MusicKit`. Pass a different
destination as the first argument, or use `--skip-build` to install existing
build products.
