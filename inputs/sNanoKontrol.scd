//f.olofsson 2019

//either nanokontrol v1 or v2

(
//--settings
var winRect= Rect(0, 70, 400, 200);  //x, y, w, h
var palette= SGUI.palette;
var fnt= SGUI.font;
var fntMono= Font.monospace(10);
var fps= 15;  //maximum gui updaterate - does not affect sensor input rate

//--functions and objects
var setupCCResponders, ccResponders;
var sendOsc;
var routineGui;
var version;  //nanokontrol v1 or v2
var ccMappings= (
	v1: (  //nanokontrol v1  (slider9+knob9 unused)
		\sliders: #[2, 3, 4, 5, 6, 8, 9, 12, 13],
		\knobs: #[14, 15, 16, 17, 18, 19, 20, 21, 22],
		\buttonsS: #[23, 24, 25, 26, 27, 28, 29, 30, 31],
		\buttonsR: #[33, 34, 35, 36, 37, 38, 39, 40, 41],
		\rew: 47,
		\play: 45,
		\ff: 48,
		\cycle: 49,
		\stop: 46,
		\rec: 44
	),
	v2: (  //nanokontrol v2
		\sliders: #[0, 1, 2, 3, 4, 5, 6, 7],
		\knobs: #[16, 17, 18, 19, 20, 21, 22, 23],
		\buttonsS: #[32, 33, 34, 35, 36, 37, 38, 39],
		\buttonsM: #[48, 49, 50, 51, 52, 53, 54, 55],
		\buttonsR: #[64, 65, 66, 67, 68, 69, 70, 71],
		\cycle: 46,
		\rew: 43,
		\ff: 44,
		\stop: 42,
		\play: 41,
		\rec: 45,
		\trkDec: 58,
		\trkInc: 59,
		\mrkSet: 60,
		\mrkDec: 61,
		\mrkInc: 62
	)
);

//--gui
var versionPopup;
var nanoKnobElements= {SGUIelement()}!9;
var nanoSliderElements= {SGUIelement()}!9;
var nanoButtonSElements= {SGUIelement()}!9;
var nanoButtonMElements= {SGUIelement()}!9;
var nanoButtonRElements= {SGUIelement()}!9;
var nanoChannelText;
var nanoCtrlButtons= (v1: (), v2: ());
var infoTextElementString= SGUIelementString();
var win= Window("sNanoKontrol", winRect);
win.layout= VLayout(
	versionPopup= PopUpMenu().items_(#["nanoKONTROL V1", "nanoKONTROL V2"]),
	HLayout(
		VLayout(
			HLayout(
				nanoCtrlButtons[\v1].put(\rew, Button().states_([
					["<<", palette.buttonText, palette.button],
					["<<", palette.buttonText, palette.highlight]
				]).fixedWidth_(25))[\rew],
				nanoCtrlButtons[\v1].put(\play, Button().states_([
					[">", palette.buttonText, palette.button],
					[">", palette.buttonText, palette.highlight]
				]).fixedWidth_(25))[\play],
				nanoCtrlButtons[\v1].put(\ff, Button().states_([
					[">>", palette.buttonText, palette.button],
					[">>", palette.buttonText, palette.highlight]
				]).fixedWidth_(25))[\ff]
			),
			HLayout(
				nanoCtrlButtons[\v1].put(\cycle, Button().states_([
					["o", palette.buttonText, palette.button],
					["o", palette.buttonText, palette.highlight]
				]).fixedWidth_(25))[\cycle],
				nanoCtrlButtons[\v1].put(\stop, Button().states_([
					[".", palette.buttonText, palette.button],
					[".", palette.buttonText, palette.highlight]
				]).fixedWidth_(25))[\stop],
				nanoCtrlButtons[\v1].put(\rec, Button().states_([
					["•", palette.buttonText, palette.button],
					["•", palette.buttonText, palette.highlight]
				]).fixedWidth_(25))[\rec]
			)
		),
		VLayout(
			HLayout(
				nanoCtrlButtons[\v2].put(\trkDec, Button().states_([
					["<", palette.buttonText, palette.button],
					["<", palette.buttonText, palette.highlight]
				]).fixedWidth_(25))[\trkDec],
				nanoCtrlButtons[\v2].put(\trkInc, Button().states_([
					[">", palette.buttonText, palette.button],
					[">", palette.buttonText, palette.highlight]
				]).fixedWidth_(25))[\trkInc],
				View()
			),
			HLayout(
				nanoCtrlButtons[\v2].put(\cycle, Button().states_([
					["cycle", palette.buttonText, palette.button],
					["cycle", palette.buttonText, palette.highlight]
				]).fixedWidth_(35))[\cycle],
				View(),
				nanoCtrlButtons[\v2].put(\mrkSet, Button().states_([
					["set", palette.buttonText, palette.button],
					["set", palette.buttonText, palette.highlight]
				]).fixedWidth_(25))[\mrkSet],
				nanoCtrlButtons[\v2].put(\mrkDec, Button().states_([
					["<", palette.buttonText, palette.button],
					["<", palette.buttonText, palette.highlight]
				]).fixedWidth_(25))[\mrkDec],
				nanoCtrlButtons[\v2].put(\mrkInc, Button().states_([
					[">", palette.buttonText, palette.button],
					[">", palette.buttonText, palette.highlight]
				]).fixedWidth_(25))[\mrkInc]
			),
			HLayout(
				nanoCtrlButtons[\v2].put(\rew, Button().states_([
					["<<", palette.buttonText, palette.button],
					["<<", palette.buttonText, palette.highlight]
				]).fixedWidth_(25))[\rew],
				nanoCtrlButtons[\v2].put(\ff, Button().states_([
					[">>", palette.buttonText, palette.button],
					[">>", palette.buttonText, palette.highlight]
				]).fixedWidth_(25))[\ff],
				nanoCtrlButtons[\v2].put(\stop, Button().states_([
					[".", palette.buttonText, palette.button],
					[".", palette.buttonText, palette.highlight]
				]).fixedWidth_(25))[\stop],
				nanoCtrlButtons[\v2].put(\play, Button().states_([
					[">", palette.buttonText, palette.button],
					[">", palette.buttonText, palette.highlight]
				]).fixedWidth_(25))[\play],
				nanoCtrlButtons[\v2].put(\rec, Button().states_([
					["•", palette.buttonText, palette.button],
					["•", palette.buttonText, palette.highlight]
				]).fixedWidth_(25))[\rec]
			)
		),
		View().maxWidth_(5),
		GridLayout.rows(
			nanoKnobElements.collect{|e| e.addView(Knob())},
			{|i|
				HLayout(
					VLayout(
						View(),
						nanoButtonSElements[i].addView(Button().states_([
							["S", palette.buttonText, palette.button],
							["S", palette.buttonText, palette.highlight]
						]).fixedWidth_(25)),
						nanoButtonMElements[i].addView(Button().states_([
							["M", palette.buttonText, palette.button],
							["M", palette.buttonText, palette.highlight]
						]).fixedWidth_(25)),
						nanoButtonRElements[i].addView(Button().states_([
							["R", palette.buttonText, palette.button],
							["R", palette.buttonText, palette.highlight]
						]).fixedWidth_(25)),
						View()
					),
					nanoSliderElements[i].addView(Slider().orientation_(\vertical))
				)
			}!nanoSliderElements.size,
			nanoChannelText= {|i| [StaticText().string_(i+1), align:\center]}!9
		)
	),
	infoTextElementString.addView(StaticText().fixedHeight_(" ".bounds(fntMono).height*2)
		.align_(\topLeft).background_(Color.grey(0.9, 0.5)))
);
win.onClose= {
	NetAddr.localAddr.sendMsg(\closed, \sNanoKontrol);
	ccResponders.do{|x| x.free};
	routineGui.stop;
};

versionPopup.action= {|view|
	switch(view.value,
		0, {
			"using nanoKONTROL V1 CC mappings".postln;
			version= \v1;
			nanoCtrlButtons[\v1].keysValuesDo{|key, val| val.visible= true};
			nanoCtrlButtons[\v2].keysValuesDo{|key, val| val.visible= false};
			nanoKnobElements[8].views.do{|view| view.visible= true};
			nanoSliderElements[8].views.do{|view| view.visible= true};
			nanoButtonSElements[8].views.do{|view| view.visible= true};
			nanoButtonMElements.do{|x| x.views.do{|view| view.visible= false}};
			nanoButtonRElements[8].views.do{|view| view.visible= true};
			nanoChannelText[8][0].visible= true;
		},
		1, {
			version= \v2;
			"using nanoKONTROL V2 CC mappings".postln;
			nanoCtrlButtons[\v1].keysValuesDo{|key, val| val.visible= false};
			nanoCtrlButtons[\v2].keysValuesDo{|key, val| val.visible= true};
			nanoKnobElements[8].views.do{|view| view.visible= false};
			nanoSliderElements[8].views.do{|view| view.visible= false};
			nanoButtonSElements[8].views.do{|view| view.visible= false};
			nanoButtonMElements.do{|x| x.views.do{|view| view.visible= true}};
			nanoButtonMElements[8].views.do{|view| view.visible= false};
			nanoButtonRElements[8].views.do{|view| view.visible= false};
			nanoChannelText[8][0].visible= false;
		}
	);
	ccResponders.do{|x| x.free};
	setupCCResponders.value;
};

setupCCResponders= {
	ccResponders= [

		//--midi functions
		ccMappings[version][\knobs].collect{|cc, i|
			MIDIFunc.cc({|val, num| nanoKnobElements[i].value= val/127}, cc);
		},
		ccMappings[version][\sliders].collect{|cc, i|
			MIDIFunc.cc({|val, num| nanoSliderElements[i].value= val/127}, cc);
		},
		ccMappings[version][\buttonsS].collect{|cc, i|
			MIDIFunc.cc({|val, num| nanoButtonSElements[i].value= val/127}, cc);
		},
		ccMappings[version][\buttonsM].collect{|cc, i|
			MIDIFunc.cc({|val, num| nanoButtonMElements[i].value= val/127}, cc);
		},
		ccMappings[version][\buttonsR].collect{|cc, i|
			MIDIFunc.cc({|val, num| nanoButtonRElements[i].value= val/127}, cc);
		},
		MIDIFunc.cc({|val, num|
			{nanoCtrlButtons[version][\rew].valueAction= (val>0).binaryValue}.defer;
		}, ccMappings[version][\rew]),
		MIDIFunc.cc({|val, num|
			{nanoCtrlButtons[version][\play].valueAction= (val>0).binaryValue}.defer;
		}, ccMappings[version][\play]),
		MIDIFunc.cc({|val, num|
			{nanoCtrlButtons[version][\ff].valueAction= (val>0).binaryValue}.defer;
		}, ccMappings[version][\ff]),
		MIDIFunc.cc({|val, num|
			{nanoCtrlButtons[version][\cycle].valueAction= (val>0).binaryValue}.defer;
		}, ccMappings[version][\cycle]),
		MIDIFunc.cc({|val, num|
			{nanoCtrlButtons[version][\stop].valueAction= (val>0).binaryValue}.defer;
		}, ccMappings[version][\stop]),
		MIDIFunc.cc({|val, num|
			{nanoCtrlButtons[version][\rec].valueAction= (val>0).binaryValue}.defer;
		}, ccMappings[version][\rec])
	];
	if(version==\v2, {
		ccResponders= ccResponders++[
			MIDIFunc.cc({|val, num|
				{nanoCtrlButtons[version][\trkDec].valueAction= (val>0).binaryValue}.defer;
			}, ccMappings[version][\trkDec]),
			MIDIFunc.cc({|val, num|
				{nanoCtrlButtons[version][\trkInc].valueAction= (val>0).binaryValue}.defer;
			}, ccMappings[version][\trkInc]),
			MIDIFunc.cc({|val, num|
				{nanoCtrlButtons[version][\mrkSet].valueAction= (val>0).binaryValue}.defer;
			}, ccMappings[version][\mrkSet]),
			MIDIFunc.cc({|val, num|
				{nanoCtrlButtons[version][\mrkDec].valueAction= (val>0).binaryValue}.defer;
			}, ccMappings[version][\mrkDec]),
			MIDIFunc.cc({|val, num|
				{nanoCtrlButtons[version][\mrkInc].valueAction= (val>0).binaryValue}.defer;
			}, ccMappings[version][\mrkInc])
		];
	});
	ccResponders= ccResponders.flat;
};

sendOsc= {|arr|
	var str= "";
	arr.do{|a|
		SInputs.destinations[a[0]].sendMsg(*a[1..]);
		str= str++a.collect{|x| if(x.isFloat, {SGUI.fixDec(x, 2)}, {x})};
	};
	infoTextElementString.value= str.replace("[ ", "[").replace(" ]", "] ").replace(",", "");
};


//--knob functions
nanoKnobElements[0].action= {|val|
	sendOsc.value([
		[\sCluster, \mainReverb, val],
		[\sDrone, \distortion, val],
		[\sFormant, \mainReverb, val],
		[\sGliss, \mainReverb, val],
		[\sStream, \metronome, val]
	]);
};
nanoKnobElements[1].action= {|val|
	sendOsc.value([
		[\sDrone, \efxHP, val],
		[\sGliss, \rate, val.lincurve(0, 1, 0, 1, 4)],
		[\sStream, \rateScale, val]
	]);
};
nanoKnobElements[2].action= {|val|
	sendOsc.value([
		[\sDrone, \efxLP, val]
	]);
};
nanoKnobElements[3].action= {|val|
	sendOsc.value([
		[\sCluster, \curvature, val],
		[\sDrone, \curvature, val],
		[\sGliss, \curvature, val],
	]);
};
nanoKnobElements[4].action= {|val|
	sendOsc.value([
		[\sDrone, \efxDec, val],
		[\sFormant, \yScale, val],
		[\sStream, \lvPitchBend, val]
	]);
};
nanoKnobElements[5].action= {|val|
	sendOsc.value([
		[\sStream, \lvSustain, val]
	]);
};
nanoKnobElements[6].action= {|val|
	sendOsc.value([
		[\sFormant, \ampHi, val],
		[\sStream, \avEntryDelayElement, val]
	]);
};
nanoKnobElements[7].action= {|val|
	sendOsc.value([
		[\sDrone, \freqLfoSpread, val],
		[\sFormant, \ampLo, val],
		[\sStream, \avDisplacementElement, val]
	]);
};
nanoKnobElements[8].action= {|val|
	//v1 only - unused
	sendOsc.value([]);
};


//--slider functions
nanoSliderElements[0].action= {|val|
	var vol= val.lincurve(0, 1, -90, 2, -4);
	sendOsc.value([
		[\sCluster, \mainVolume, vol],
		[\sDrone, \mainVolume, vol],
		[\sFormant, \mainVolume, vol],
		[\sGliss, \mainVolume, vol],
		[\sStream, \lvPitchesArrayPatternRangeLo, val]
	]);
};
nanoSliderElements[1].action= {|val|
	sendOsc.value([
		[\sCluster, \glissTime, val],
		[\sDrone, \glissTime, val],
		[\sGliss, \glissTime, val],
		[\sStream, \lvPitchesArrayPatternRangeHi, val]
	]);
};
nanoSliderElements[2].action= {|val|
	sendOsc.value([
		[\sCluster, \ampRange, val],
		[\sDrone, \efxDel, val],
		[\sGliss, \ampRange, val],
		[\sStream, \lvVelocitiesPatternRangeLo, val]
	]);
};
nanoSliderElements[3].action= {|val|
	sendOsc.value([
		[\sCluster, \freqRange, val],
		[\sDrone, \freqRange, val],
		[\sGliss, \freqRange, val],
		[\sStream, \lvVelocitiesPatternRangeHi, val]
	]);
};
nanoSliderElements[4].action= {|val|
	var fold= if(val<0.5, {val*2}, {1-(val-0.5*2)});
	sendOsc.value([
		[\sCluster, \ampLfoDepth, val],
		[\sDrone, \ampLfoDepth, val],
		[\sFormant, \lagUp, fold],
		[\sFormant, \lagDown, val],
		[\sGliss, \ampLfoDepth, val],
		[\sStream, \avPitchBend, val]
	]);
};
nanoSliderElements[5].action= {|val|
	sendOsc.value([
		[\sCluster, \ampLfoRate, val],
		[\sDrone, \ampLfoRate, val],
		[\sFormant, \detune, val],
		[\sGliss, \ampLfoRate, val],
		[\sStream, \avSustain, val]
	]);
};
nanoSliderElements[6].action= {|val|
	sendOsc.value([
		[\sCluster, \freqLfoDepth, val],
		[\sDrone, \freqLfoDepth, val],
		[\sFormant, \formOffset, val],
		[\sGliss, \freqLfoDepth, val],
		[\sStream, \avFalloutVoices, val]
	]);
};
nanoSliderElements[7].action= {|val|
	sendOsc.value([
		[\sCluster, \freqLfoRate, val],
		[\sDrone, \freqLfoRate, val],
		[\sFormant, \fundOffset, val],
		[\sGliss, \freqLfoRate, val],
		[\sStream, \avFalloutChords, val]
	]);
};
nanoSliderElements[8].action= {|val|
	//v1 only - unused
	sendOsc.value([]);
};


//--button functions
nanoButtonSElements[0].action= {|val| sendOsc.value([])};
nanoButtonSElements[1].action= {|val| sendOsc.value([])};
nanoButtonSElements[2].action= {|val|
	if(val>0, {
		sendOsc.value([
			[\sCluster, \ampRangeMinMax, 0.2, 0.8],
			[\sDrone, \efxDelMinMax, 0.0, 0.6],
			[\sGliss, \ampRangeMinMax, 0.2, 0.8]
		]);
	});
};
nanoButtonSElements[3].action= {|val|
	if(val>0, {
		sendOsc.value([
			[\sCluster, \freqRangeMinMax, 0.2, 0.8],
			[\sDrone, \freqRangeMinMax, 0.2, 0.8],
			[\sGliss, \freqRangeMinMax, 0.2, 0.8]
		]);
	});
};
nanoButtonSElements[4].action= {|val|
	if(val>0, {
		sendOsc.value([
			[\sStream, \avPitchBendOn, 1]
		]);
	});
};
nanoButtonSElements[5].action= {|val| sendOsc.value([])};
nanoButtonSElements[6].action= {|val| sendOsc.value([])};
nanoButtonSElements[7].action= {|val| sendOsc.value([])};
nanoButtonSElements[8].action= {|val| sendOsc.value([])};

nanoButtonMElements[0].action= {|val| sendOsc.value([])};
nanoButtonMElements[1].action= {|val| sendOsc.value([])};
nanoButtonMElements[2].action= {|val|
	if(val>0, {
		sendOsc.value([
			[\sCluster, \ampRangeMinMax, 0.3, 0.7],
			[\sDrone, \efxDelMinMax, 0.0, 0.3],
			[\sGliss, \ampRangeMinMax, 0.3, 0.7]
		]);
	});
};
nanoButtonMElements[3].action= {|val|
	if(val>0, {
		sendOsc.value([
			[\sCluster, \freqRangeMinMax, 0.3, 0.7],
			[\sDrone, \freqRangeMinMax, 0.3, 0.7],
			[\sGliss, \freqRangeMinMax, 0.3, 0.7]
		]);
	});
};
nanoButtonMElements[4].action= {|val| sendOsc.value([])};
nanoButtonMElements[5].action= {|val| sendOsc.value([])};
nanoButtonMElements[6].action= {|val| sendOsc.value([])};
nanoButtonMElements[7].action= {|val| sendOsc.value([])};
nanoButtonMElements[8].action= {|val| sendOsc.value([])};

nanoButtonRElements[0].action= {|val| sendOsc.value([])};
nanoButtonRElements[1].action= {|val| sendOsc.value([])};
nanoButtonRElements[2].action= {|val|
	if(val>0, {
		sendOsc.value([
			[\sCluster, \ampRangeMinMax, 0.4, 0.6],
			[\sDrone, \efxDelMinMax, 0.0, 0.0],
			[\sGliss, \ampRangeMinMax, 0.4, 0.6]
		]);
	});
};
nanoButtonRElements[3].action= {|val|
	if(val>0, {
		sendOsc.value([
			[\sCluster, \freqRangeMinMax, 0.4, 0.6],
			[\sDrone, \freqRangeMinMax, 0.4, 0.6],
			[\sGliss, \freqRangeMinMax, 0.4, 0.6]
		]);
	});
};
nanoButtonRElements[4].action= {|val| sendOsc.value([])};
nanoButtonRElements[5].action= {|val| sendOsc.value([])};
nanoButtonRElements[6].action= {|val| sendOsc.value([])};
nanoButtonRElements[7].action= {|val| sendOsc.value([])};
nanoButtonRElements[8].action= {|val| sendOsc.value([])};


//--control button functions
nanoCtrlButtons.collect{|d| d[\rew]}.do{|button|
	button.action= {|view|
		if(view.value>0, {
			sendOsc.value([
				[\sDrone, \freqSelect, -1],
				[\sGliss, \freqSelect, -1],
				[\sStream, \avOn, 1]
			]);
		});
	};
};
nanoCtrlButtons.collect{|d| d[\play]}.do{|button|
	button.postln.action= {|view|
		if(view.value>0, {
			sendOsc.value([
				[\sDrone, \freqLinesPlay, 1],
				[\sGliss, \freqLinesPlay, 1]
			]);
		});
	};
};
nanoCtrlButtons.collect{|d| d[\ff]}.do{|button|
	button.action= {|view|
		if(view.value>0, {
			sendOsc.value([
				[\sDrone, \freqSelect, 1],
				[\sGliss, \freqSelect, 1]
			]);
		});
	};
};
nanoCtrlButtons.collect{|d| d[\cycle]}.do{|button|
	button.action= {|view|
		if(view.value>0, {
			sendOsc.value([]);
		});
	};
};
nanoCtrlButtons.collect{|d| d[\stop]}.do{|button|
	button.action= {|view|
		if(view.value>0, {
			sendOsc.value([]);
		});
	};
};
nanoCtrlButtons.collect{|d| d[\rec]}.do{|button|
	button.action= {|view|
		if(view.value>0, {
			sendOsc.value([
				[\sCluster, \mainRecord, 1],
				[\sDrone, \mainRecord, 1],
				[\sFormant, \mainRecord, 1],
				[\sGliss, \mainRecord, 1],
				[\sStream, \mainRecord, 1]
			]);
		});
	};
};
nanoCtrlButtons[\v2][\trkDec].do{|button|
	button.action= {|view|
		if(view.value>0, {
			sendOsc.value([]);
		});
	};
};
nanoCtrlButtons[\v2][\trkInc].do{|button|
	button.action= {|view|
		if(view.value>0, {
			sendOsc.value([]);
		});
	};
};
nanoCtrlButtons[\v2][\mrkSet].do{|button|
	button.action= {|view|
		if(view.value>0, {
			sendOsc.value([]);
		});
	};
};
nanoCtrlButtons[\v2][\mrkDec].do{|button|
	button.action= {|view|
		if(view.value>0, {
			sendOsc.value([]);
		});
	};
};
nanoCtrlButtons[\v2][\mrkInc].do{|button|
	button.action= {|view|
		if(view.value>0, {
			sendOsc.value([]);
		});
	};
};


MIDIIn.connectAll;
//MIDIFunc.trace;  //debug

if(MIDIClient.sources.any{|x| x.device=="nanoKONTROL"}, {
	versionPopup.valueAction= 0;
}, {
	versionPopup.valueAction= 1;
});

routineGui= Routine({
	inf.do{
		nanoKnobElements.do{|e| e.update};
		nanoSliderElements.do{|e| e.update};
		nanoButtonSElements.do{|e| e.update};
		nanoButtonMElements.do{|e| e.update};
		nanoButtonRElements.do{|e| e.update};
		infoTextElementString.update;
		fps.reciprocal.wait;
	}
}).play(AppClock);
SGUI.report(win);
SGUI.adapt(win);
infoTextElementString.views.do{|view| view.font= fntMono};
win.front;
)
