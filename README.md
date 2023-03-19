a [Quark](https://supercollider-quarks.github.io/quarks/) for [SuperCollider](https://supercollider.github.io)

# sInstruments

some instruments written in SuperCollider in collaboration with Tamas Ungvary.

homepage: <https://redfrik.github.io/sInstruments>

## Requirements

[SuperCollider](https://supercollider.github.io) version 3.11 or newer running under macOS, Linux or Windows.

## Dependencies

sStream needs the latest [VST plugin](https://git.iem.at/pd/vstplugin/-/releases) and works best with the [Pianoteq 6 STAGE](https://www.modartt.com/pianoteq) vst plug.

## Installation

```supercollider
//install
Quarks.fetchDirectory
Quarks.install("sInstruments")
//recompile
SInstruments.openHelpFile
```

[optional] put soundfiles and folders of soundfiles in the directory `soundfiles`.
