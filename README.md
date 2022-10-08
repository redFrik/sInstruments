
a [Quark](http://supercollider-quarks.github.io/quarks/) for [SuperCollider](http://supercollider.github.io)

# sInstruments

Some instruments written in SuperCollider in collaboration with Tamas Ungvary.

The code is available here: [https://github.com/redFrik/sInstruments](https://github.com/redFrik/sInstruments)

## Requirements

[SuperCollider](http://supercollider.github.io) running under macOS, Linux or Windows.

## Dependancies

One of the instruments, sStream, needs the latest [VST plugin](https://git.iem.at/pd/vstplugin/-/releases) and (for now) the [Pianoteq 6 STAGE](https://www.modartt.com/pianoteq) vst plug. All the other instruments can be run without any external libraries or plugins.

## Installation

```supercollider
//install
Quarks.fetchDirectory
Quarks.install("sInstruments")
//recompile
SInstruments.openHelpFile
```

[optional] put soundfiles and folders of soundfiles in the directory `soundfiles`.

## Notes

These instruments are made to be played with custom hardware (3D sensors, sliders and buttons), but can also be used with keyboard+mouse or livecoded.

[optional] put soundfiles and folders of soundfiles in the directory `soundfiles`.

[The Sentograph: Input devices and the communication of bodily expression](http://www.speech.kth.se/prod/publications/files/qpsr/1996/1996_37_1_017-022.pdf) - Vertegaal, R. and Ungvary, T.

## sCluster

<img src="images/sCluster.png" alt="sCluster" width="1145px"/>

## sDrone

<img src="images/sDrone.png" alt="sDrone" width="1149px"/>

## sFormant

<img src="images/sFormant.png" alt="sFormant" width="814px"/>

## sGliss

<img src="images/sGliss.png" alt="sGliss" width="1162px"/>

## sStream

<img src="images/sStream.png" alt="sStream" width="1288px"/>

## sInputs

<img src="images/sGreybox.png" alt="sGreybox" width="454px"/> [<img src="images/sGreybox-photo.jpg" alt="sGreybox-photo" width="200px"/>](images/sGreybox-photo.jpg) [<img src="images/icon_schematics.svg" alt="sGreybox-schematics" width="50px"/>](schematics/sGreybox-schematics.pdf) [<img src="images/icon_firmware.svg" alt="sGreybox-firmware" width="50px"/>](firmware/sGreybox-firmware.ino)

<img src="images/sGreybox2.png" alt="sGreybox2" width="454px"/> [<img src="images/sGreybox2-photo.jpg" alt="sGreybox2-photo" width="200px"/>](images/sGreybox2-photo.jpg) [<img src="images/icon_schematics.svg" alt="sGreybox2-schematics" width="50px"/>](schematics/sGreybox2-schematics.pdf) [<img src="images/icon_firmware.svg" alt="sGreybox2-firmware" width="50px"/>](firmware/sGreybox2-firmware.ino)

<img src="images/sKeyboard.png" alt="sKeyboard" width="912px"/>

<img src="images/sKeyBpad.png" alt="sKeyBpad" width="512px"/> [<img src="images/sKeyBpad-photo.jpg" alt="sKeyBpad-photo" width="200px"/>](images/sKeyBpad-photo.jpg) [<img src="images/icon_firmware.svg" alt="sKeyBpad-firmware" width="50px"/>](firmware/sKeyBpad-firmware.ino)

<img src="images/sKeyCpad.png" alt="sKeyCpad" width="512px"/> [<img src="images/sKeyCpad-photo.jpg" alt="sKeyCpad-photo" width="200px"/>](images/sKeyCpad-photo.jpg) [<img src="images/icon_schematics.svg" alt="sKeyCpad-schematics" width="50px"/>](schematics/sKeyCpad-schematics.pdf) [<img src="images/icon_firmware.svg" alt="sKeyCpad-firmware" width="50px"/>](firmware/sKeyCpad-firmware.ino)

<img src="images/sKeyDpad.png" alt="sKeyDpad" width="262px"/> [<img src="images/sKeyDpad-photo.jpg" alt="sKeyDpad-photo" width="200px"/>](images/sKeyDpad-photo.jpg) [<img src="images/icon_schematics.svg" alt="sKeyDpad-schematics" width="50px"/>](schematics/sKeyDpad-schematics.pdf) [<img src="images/icon_firmware.svg" alt="sKeyDpad-firmware" width="50px"/>](firmware/sKeyDpad-firmware.ino) [<img src="images/icon_mappings.svg" alt="sKeyDpad-mappings" width="25px"/>](mappings/sKeyDpad-mappings.png)

<img src="images/sNanoKontrol.png" alt="sNanoKontrol" width="895px"/> [<img src="images/icon_mappings.svg" alt="sNanoKontrol-mappings-sGliss" width="25px"/>](mappings/sNanoKontrol-mappings-sGliss.png)

<img src="images/sQWERTYKeyboard.png" alt="sQWERTYKeyboard" width="592px"/>

<img src="images/sSentograph.png" alt="sSentograph" width="432px"/>

<img src="images/sText.png" alt="sText" width="512px"/>

## other classes

<img src="images/SPlayFileDiskView.png" alt="SPlayFileDiskView" width="912px"/>
