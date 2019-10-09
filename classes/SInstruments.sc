//f.olofsson 2019

SInstruments {
	classvar <rootDir;
	classvar <dataDir;
	classvar <>inputsDir;
	classvar <>instrumentsDir;
	classvar <>recordingsDir;
	classvar <>snapshotsDir;
	classvar <>soundfilesDir;
	classvar <>preferencesDir;

	*initClass {
		rootDir= SInstruments.filenameSymbol.asString.dirname.dirname;
		dataDir= rootDir+/+"data";
		instrumentsDir= rootDir+/+"instruments";
		inputsDir= rootDir+/+"inputs";
		recordingsDir= rootDir+/+"recordings";
		snapshotsDir= rootDir+/+"snapshots";
		soundfilesDir= rootDir+/+"soundfiles";
		preferencesDir= rootDir+/+"preferences";
	}
	*version {
		var version= "-1";
		var quarkFile= File.use(rootDir+/+"sInstruments.quark", "r", {|file|
			var str= file.readAllString;
			version= str.findRegexp("version.*?,")[0][1].split(34.asAscii)[1];
		});
		^version;
	}
	*instruments {
		^(instrumentsDir+/+"s*.scd").pathMatch.collect{|x| x.basename.splitext[0].asSymbol};
	}
	*toFront {|name, file|
		var w;
		if(name.notNil and:{name!='_'}, {
			w= Window.allWindows.detect{|x| x.name.asSymbol==name.asSymbol};
			file= file??{name++".scd"};  //load file with same name if not given
			if(w.isNil, {
				case
				{File.exists(SInstruments.instrumentsDir+/+file)} {
					(SInstruments.instrumentsDir+/+file).load;
				}
				{File.exists(SInstruments.inputsDir+/+file)} {
					(SInstruments.inputsDir+/+file).load;
				}
				{
					"SInstruments file % not found in any directory".format(file).warn;
				};
			}, {
				w.front;
				w.alwaysOnTop= true;  //TODO remove this temp hack when fixed in sc
				w.alwaysOnTop= false;
			});
		});
	}
}
