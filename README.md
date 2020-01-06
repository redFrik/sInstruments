a [Quark](http://supercollider-quarks.github.io/quarks/) for [SuperCollider](http://supercollider.github.io)

# sInstruments

some instruments written in SuperCollider in collaboration with Tamas Ungvary.

homepage: https://redfrik.github.io/sInstruments

## Requirements

[SuperCollider](http://supercollider.github.io) version 3.10 or newer running under macOS, Linux or Windows.

## Dependancies

sStream needs the [VST plugin](https://git.iem.at/pd/vstplugin/-/releases) and the [Pianoteq 6 STAGE](https://www.modartt.com/pianoteq) vst plug.

## Installation

```supercollider
//install
Quarks.fetchDirectory
Quarks.install("sInstruments")
//recompile
SInstruments.openHelpFile
```

[optional] put soundfiles and folders of soundfiles in the directory `soundfiles`.
