//f.olofsson 2019

//either nanokontrol v1 or v2

(
var nk= SNanoKontrol("sNanoKontrol2", Point(170, 70));

//--knob functions
nk.nanoKnobElements[0].action= {|val|
	nk.sendOsc([
		[\sCluster, \mainReverb, val],
		[\sDrone, \distortion, val],
		[\sFormant, \mainReverb, val],
		[\sGliss, \mainReverb, val],
		[\sStream, \metronome, val]
	]);
};
nk.nanoKnobElements[1].action= {|val|
	nk.sendOsc([
		[\sDrone, \efxHP, val],
		[\sGliss, \rate, val.lincurve(0, 1, 0, 1, 4)],
		[\sStream, \rateScale, val]
	]);
};
nk.nanoKnobElements[2].action= {|val|
	nk.sendOsc([
		[\sDrone, \efxLP, val]
	]);
};
nk.nanoKnobElements[3].action= {|val|
	nk.sendOsc([
		[\sCluster, \curvature, val],
		[\sDrone, \curvature, val],
		[\sGliss, \curvature, val],
	]);
};
nk.nanoKnobElements[4].action= {|val|
	nk.sendOsc([
		[\sDrone, \efxDec, val],
		[\sFormant, \yScale, val],
		[\sStream, \lvPitchBend, val]
	]);
};
nk.nanoKnobElements[5].action= {|val|
	nk.sendOsc([
		[\sStream, \lvSustain, val]
	]);
};
nk.nanoKnobElements[6].action= {|val|
	nk.sendOsc([
		[\sFormant, \ampHi, val],
		[\sStream, \avEntryDelayElement, val]
	]);
};
nk.nanoKnobElements[7].action= {|val|
	nk.sendOsc([
		[\sDrone, \freqLfoSpread, val],
		[\sFormant, \ampLo, val],
		[\sStream, \avDisplacementElement, val]
	]);
};
nk.nanoKnobElements[8].action= {|val|
	//v1 only - unused
	nk.sendOsc([]);
};


//--slider functions
nk.nanoSliderElements[0].action= {|val|
	var vol= val.lincurve(0, 1, -90, 2, -4);
	nk.sendOsc([
		[\sCluster, \mainVolume, vol],
		[\sDrone, \mainVolume, vol],
		[\sFormant, \mainVolume, vol],
		[\sGliss, \mainVolume, vol],
		[\sStream, \lvPitchesArrayPatternRangeLo, val]
	]);
};
nk.nanoSliderElements[1].action= {|val|
	nk.sendOsc([
		[\sCluster, \glissTime, val],
		[\sDrone, \glissTime, val],
		[\sGliss, \glissTime, val],
		[\sStream, \lvPitchesArrayPatternRangeHi, val]
	]);
};
nk.nanoSliderElements[2].action= {|val|
	nk.sendOsc([
		[\sCluster, \ampRange, val],
		[\sDrone, \efxDel, val],
		[\sGliss, \ampRange, val],
		[\sStream, \lvVelocitiesPatternRangeLo, val]
	]);
};
nk.nanoSliderElements[3].action= {|val|
	nk.sendOsc([
		[\sCluster, \freqRange, val],
		[\sDrone, \freqRange, val],
		[\sGliss, \freqRange, val],
		[\sStream, \lvVelocitiesPatternRangeHi, val]
	]);
};
nk.nanoSliderElements[4].action= {|val|
	var fold= if(val<0.5, {val*2}, {1-(val-0.5*2)});
	nk.sendOsc([
		[\sCluster, \ampLfoDepth, val],
		[\sDrone, \ampLfoDepth, val],
		[\sFormant, \lagUp, fold],
		[\sFormant, \lagDown, val],
		[\sGliss, \ampLfoDepth, val],
		[\sStream, \avPitchBend, val]
	]);
};
nk.nanoSliderElements[5].action= {|val|
	nk.sendOsc([
		[\sCluster, \ampLfoRate, val],
		[\sDrone, \ampLfoRate, val],
		[\sFormant, \detune, val],
		[\sGliss, \ampLfoRate, val],
		[\sStream, \avSustain, val]
	]);
};
nk.nanoSliderElements[6].action= {|val|
	nk.sendOsc([
		[\sCluster, \freqLfoDepth, val],
		[\sDrone, \freqLfoDepth, val],
		[\sFormant, \formOffset, val],
		[\sGliss, \freqLfoDepth, val],
		[\sStream, \avFalloutVoices, val]
	]);
};
nk.nanoSliderElements[7].action= {|val|
	nk.sendOsc([
		[\sCluster, \freqLfoRate, val],
		[\sDrone, \freqLfoRate, val],
		[\sFormant, \fundOffset, val],
		[\sGliss, \freqLfoRate, val],
		[\sStream, \avFalloutChords, val]
	]);
};
nk.nanoSliderElements[8].action= {|val|
	//v1 only - unused
	nk.sendOsc([]);
};


//--button functions
nk.nanoButtonSElements[0].action= {|val| nk.sendOsc([])};
nk.nanoButtonSElements[1].action= {|val| nk.sendOsc([])};
nk.nanoButtonSElements[2].action= {|val|
	if(val>0, {
		nk.sendOsc([
			[\sCluster, \ampRangeMinMax, 0.2, 0.8],
			[\sDrone, \efxDelMinMax, 0.0, 0.6],
			[\sGliss, \ampRangeMinMax, 0.2, 0.8]
		]);
	});
};
nk.nanoButtonSElements[3].action= {|val|
	if(val>0, {
		nk.sendOsc([
			[\sCluster, \freqRangeMinMax, 0.2, 0.8],
			[\sDrone, \freqRangeMinMax, 0.2, 0.8],
			[\sGliss, \freqRangeMinMax, 0.2, 0.8]
		]);
	});
};
nk.nanoButtonSElements[4].action= {|val|
	if(val>0, {
		nk.sendOsc([
			[\sStream, \avPitchBendOn, 1]
		]);
	});
};
nk.nanoButtonSElements[5].action= {|val| nk.sendOsc([])};
nk.nanoButtonSElements[6].action= {|val| nk.sendOsc([])};
nk.nanoButtonSElements[7].action= {|val| nk.sendOsc([])};
nk.nanoButtonSElements[8].action= {|val| nk.sendOsc([])};

nk.nanoButtonMElements[0].action= {|val| nk.sendOsc([])};
nk.nanoButtonMElements[1].action= {|val| nk.sendOsc([])};
nk.nanoButtonMElements[2].action= {|val|
	if(val>0, {
		nk.sendOsc([
			[\sCluster, \ampRangeMinMax, 0.3, 0.7],
			[\sDrone, \efxDelMinMax, 0.0, 0.3],
			[\sGliss, \ampRangeMinMax, 0.3, 0.7]
		]);
	});
};
nk.nanoButtonMElements[3].action= {|val|
	if(val>0, {
		nk.sendOsc([
			[\sCluster, \freqRangeMinMax, 0.3, 0.7],
			[\sDrone, \freqRangeMinMax, 0.3, 0.7],
			[\sGliss, \freqRangeMinMax, 0.3, 0.7]
		]);
	});
};
nk.nanoButtonMElements[4].action= {|val| nk.sendOsc([])};
nk.nanoButtonMElements[5].action= {|val| nk.sendOsc([])};
nk.nanoButtonMElements[6].action= {|val| nk.sendOsc([])};
nk.nanoButtonMElements[7].action= {|val| nk.sendOsc([])};
nk.nanoButtonMElements[8].action= {|val| nk.sendOsc([])};

nk.nanoButtonRElements[0].action= {|val| nk.sendOsc([])};
nk.nanoButtonRElements[1].action= {|val| nk.sendOsc([])};
nk.nanoButtonRElements[2].action= {|val|
	if(val>0, {
		nk.sendOsc([
			[\sCluster, \ampRangeMinMax, 0.4, 0.6],
			[\sDrone, \efxDelMinMax, 0.0, 0.0],
			[\sGliss, \ampRangeMinMax, 0.4, 0.6]
		]);
	});
};
nk.nanoButtonRElements[3].action= {|val|
	if(val>0, {
		nk.sendOsc([
			[\sCluster, \freqRangeMinMax, 0.4, 0.6],
			[\sDrone, \freqRangeMinMax, 0.4, 0.6],
			[\sGliss, \freqRangeMinMax, 0.4, 0.6]
		]);
	});
};
nk.nanoButtonRElements[4].action= {|val| nk.sendOsc([])};
nk.nanoButtonRElements[5].action= {|val| nk.sendOsc([])};
nk.nanoButtonRElements[6].action= {|val| nk.sendOsc([])};
nk.nanoButtonRElements[7].action= {|val| nk.sendOsc([])};
nk.nanoButtonRElements[8].action= {|val| nk.sendOsc([])};


//--control button functions
nk.nanoCtrlButtons.collect{|d| d[\rew]}.do{|button|
	button.action= {|view|
		if(view.value>0, {
			nk.sendOsc([
				[\sDrone, \freqSelect, -1],
				[\sGliss, \freqSelect, -1],
				[\sStream, \avOn, 1]
			]);
		});
	};
};
nk.nanoCtrlButtons.collect{|d| d[\play]}.do{|button|
	button.action= {|view|
		if(view.value>0, {
			nk.sendOsc([
				[\sDrone, \freqLinesPlay, 1],
				[\sGliss, \freqLinesPlay, 1]
			]);
		});
	};
};
nk.nanoCtrlButtons.collect{|d| d[\ff]}.do{|button|
	button.action= {|view|
		if(view.value>0, {
			nk.sendOsc([
				[\sDrone, \freqSelect, 1],
				[\sGliss, \freqSelect, 1]
			]);
		});
	};
};
nk.nanoCtrlButtons.collect{|d| d[\cycle]}.do{|button|
	button.action= {|view|
		if(view.value>0, {
			nk.sendOsc([]);
		});
	};
};
nk.nanoCtrlButtons.collect{|d| d[\stop]}.do{|button|
	button.action= {|view|
		if(view.value>0, {
			nk.sendOsc([]);
		});
	};
};
nk.nanoCtrlButtons.collect{|d| d[\rec]}.do{|button|
	button.action= {|view|
		if(view.value>0, {
			nk.sendOsc([
				[\sCluster, \mainRecord, 1],
				[\sDrone, \mainRecord, 1],
				[\sFormant, \mainRecord, 1],
				[\sGliss, \mainRecord, 1],
				[\sStream, \mainRecord, 1]
			]);
		});
	};
};
nk.nanoCtrlButtons[\v2][\trkDec].do{|button|
	button.action= {|view|
		if(view.value>0, {
			nk.sendOsc([]);
		});
	};
};
nk.nanoCtrlButtons[\v2][\trkInc].do{|button|
	button.action= {|view|
		if(view.value>0, {
			nk.sendOsc([]);
		});
	};
};
nk.nanoCtrlButtons[\v2][\mrkSet].do{|button|
	button.action= {|view|
		if(view.value>0, {
			nk.sendOsc([]);
		});
	};
};
nk.nanoCtrlButtons[\v2][\mrkDec].do{|button|
	button.action= {|view|
		if(view.value>0, {
			nk.sendOsc([]);
		});
	};
};
nk.nanoCtrlButtons[\v2][\mrkInc].do{|button|
	button.action= {|view|
		if(view.value>0, {
			nk.sendOsc([]);
		});
	};
};

)
