(
//--settings
var winRect= Rect(0, 60, 400, 400);  //x, y, w, h
var palette= SGUI.palette;

//--functions and objects
var parseAmplitudes, parseFrequencies;
var stringToFloats;

//--gui
var presetsPop;
var amplitudesTypePop, amplitudesText, amplitudesSendPop, amplitudesSendBut;
var frequenciesTypePop, frequenciesText, frequenciesSendPop, frequenciesSendBut;
var win= Window("sText", winRect);
win.layout= VLayout(
	HLayout(
		StaticText().string_("Presets:"),
		[presetsPop= PopUpMenu(), stretch:1]
	),
	HLayout(
		StaticText().string_("Amplitudes:"),
		amplitudesTypePop= PopUpMenu().items_(#["Floats (0-1)", "MIDI Velocity (0-127)", "dB"])
	),
	amplitudesText= TextView(),
	HLayout(
		amplitudesSendPop= PopUpMenu().items_(#["sCluster", "sDrone", "sGliss", "sStream-patterns", "sStream"]),
		amplitudesSendBut= Button().states_(#[["Send"]])
	),
	View().fixedHeight_(10),
	HLayout(
		StaticText().string_("Frequencies:"),
		frequenciesTypePop= PopUpMenu().items_(#["Hz", "MIDI Notes (0-127)"])
	),
	frequenciesText= TextView(),
	HLayout(
		frequenciesSendPop= PopUpMenu().items_(#["sCluster", "sDrone", "sGliss", "sStream-patterns", "sStream"]),
		frequenciesSendBut= Button().states_(#[["Send"]])
	)
);
SGUI.report(win);
SGUI.adapt(win);
win.onClose= {
	NetAddr.localAddr.sendMsg(\closed, \sText);
};
win.front;

presetsPop.items= #["", "15 random values", "Octaves", "Overtones", "Overtones2", "Cmaj7", "D#m", "Rumba"];
presetsPop.action= {|view|
	switch(view.value,
		0, {
			amplitudesText.string= "";
			frequenciesText.string= "";
		},
		1, {
			amplitudesText.string= ({1.0.linrand}!15).asString.drop(2).drop(-2);
			amplitudesTypePop.value= 0;
			frequenciesText.string= ({20.0.exprand(12000)}!15).asString.drop(2).drop(-2);
			frequenciesTypePop.value= 0;
		},
		2, {
			amplitudesText.string= "0.7, 0.6, 0.5";
			amplitudesTypePop.value= 0;
			frequenciesText.string= "261.6256, 523.25, 1046.5";
			frequenciesTypePop.value= 0;
		},
		3, {
			amplitudesText.string= "0, -3, -6, -9, -12, -15, -18";
			amplitudesTypePop.value= 2;
			frequenciesText.string= "131, 262, 393, 524, 655, 786, 917";
			frequenciesTypePop.value= 0;
		},
		4, {
			amplitudesText.string= "0.5, 0.5, 0.5, 0.5, 0.5";
			amplitudesTypePop.value= 0;
			frequenciesText.string= "100, 200, 300, 400, 500";
			frequenciesTypePop.value= 0;
		},
		5, {
			amplitudesText.string= "64, 60, 56, 52";
			amplitudesTypePop.value= 1;
			frequenciesText.string= "60, 64, 67, 71";
			frequenciesTypePop.value= 1;
		},
		6, {
			amplitudesText.string= "80, 80, 80, 0, 0, 0, 0, 0, 0, 0, 0, 0";
			amplitudesTypePop.value= 1;
			frequenciesText.string= "63, 66, 70";
			frequenciesTypePop.value= 1;
		},
		7, {
			amplitudesText.string= "1, 0, 1, 1, 0, 1, 0, 1, 0, 1, 1, 0, 1, 0, 1, 0";
			amplitudesTypePop.value= 0;
			frequenciesText.string= "60, 60, 60, 70, 60, 60, 60, 70, 60, 60, 60, 70, 55, 60, 60, 70";
			frequenciesTypePop.value= 1;
		}
	);
	amplitudesText.stringColor= palette.buttonText;
	frequenciesText.stringColor= palette.buttonText;
};

amplitudesText.keyDownAction= {|view|
	view.stringColor= palette.buttonText;
};
frequenciesText.keyDownAction= {|view|
	view.stringColor= palette.buttonText;
};

stringToFloats= {|str|
	str= str.split(Char.comma);
	str.collect{|s| s.asFloat};
};
parseAmplitudes= {|str|
	var amps= stringToFloats.value(str);
	switch(amplitudesTypePop.value,
		1, {  //convert from midi velocities
			amps= amps.collect{|x| x.clip(0, 127)/127};
		},
		2, {  //convert from db
			amps= amps.collect{|x| x.dbamp};
		}
	);
	amps;
};
amplitudesSendBut.action= {
	var amps, dest;
	amps= parseAmplitudes.value(amplitudesText.string);
	dest= amplitudesSendPop.items[amplitudesSendPop.value].asSymbol;
	if(dest=='sStream-patterns', {  //special case
		SInputs.destinations[\sStream].sendMsg(\patternAmplitudes, *amps.postln);
	}, {
		SInputs.destinations[dest].sendMsg(\amplitudes, *amps.postln);
	});
};
parseFrequencies= {|str|
	var freqs= stringToFloats.value(str);
	switch(frequenciesTypePop.value,
		1, {  //convert from midi notes
			freqs= freqs.collect{|x| x.clip(0, 127).midicps};
		}
	);
	freqs;
};
frequenciesSendBut.action= {
	var freqs, dest;
	freqs= parseFrequencies.value(frequenciesText.string).postln;
	dest= frequenciesSendPop.items[frequenciesSendPop.value].asSymbol;
	if(dest=='sStream-patterns', {  //special case
		SInputs.destinations[\sStream].sendMsg(\patternFrequencies, *freqs.postln);
	}, {
		SInputs.destinations[dest].sendMsg(\frequencies, *freqs.postln);
	});
};
)
