//f.olofsson 2019

//either nanokontrol v1 or v2

(
var nk= SNanoKontrol("sNanoKontrolStream", Point(480, 0));

//--knob functions
nk.nanoKnobElements[0].action= {|val|
	nk.sendOsc([
	]);
};
nk.nanoKnobElements[1].action= {|val|
	nk.sendOsc([
	]);
};
nk.nanoKnobElements[2].action= {|val|
	nk.sendOsc([
	]);
};
nk.nanoKnobElements[3].action= {|val|
	nk.sendOsc([
	]);
};
nk.nanoKnobElements[4].action= {|val|
	nk.sendOsc([
	]);
};
nk.nanoKnobElements[5].action= {|val|
	nk.sendOsc([
	]);
};
nk.nanoKnobElements[6].action= {|val|
	nk.sendOsc([
	]);
};
nk.nanoKnobElements[7].action= {|val|
	nk.sendOsc([
	]);
};
nk.nanoKnobElements[8].action= {|val|
	//v1 only - unused
	nk.sendOsc([]);
};


//--slider functions
nk.nanoSliderElements[0].action= {|val|
	nk.sendOsc([
		[\sStream, \y, val]
	]);
};
nk.nanoSliderElements[1].action= {|val|
	nk.sendOsc([
		[\sStream, \metronome, val]
	]);
};
nk.nanoSliderElements[2].action= {|val|
	var vol= val.lincurve(0, 1, -90, 2, -4);
	nk.sendOsc([
		[\sStream, \lvVolume, val]
	]);
};
nk.nanoSliderElements[3].action= {|val|
	nk.sendOsc([
		[\sStream, \lvPitchBend, val]
	]);
};
nk.nanoSliderElements[4].action= {|val|
	nk.sendOsc([
		[\sStream, \avPitchBend, val]
	]);
};
nk.nanoSliderElements[5].action= {|val|
	nk.sendOsc([
		[\sStream, \lvSustain, val]
	]);
};
nk.nanoSliderElements[6].action= {|val|
	nk.sendOsc([
		[\sStream, \avSustain, val]
	]);
};
nk.nanoSliderElements[7].action= {|val|
	nk.sendOsc([
		[\sStream, \z, val]
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
		]);
	});
};
nk.nanoButtonSElements[3].action= {|val|
	if(val>0, {
		nk.sendOsc([
		]);
	});
};
nk.nanoButtonSElements[4].action= {|val|
	if(val>0, {
		nk.sendOsc([
		]);
	});
};
nk.nanoButtonSElements[5].action= {|val| nk.sendOsc([])};
nk.nanoButtonSElements[6].action= {|val| nk.sendOsc([])};
nk.nanoButtonSElements[7].action= {|val| nk.sendOsc([])};
nk.nanoButtonSElements[8].action= {|val| nk.sendOsc([])};

nk.nanoButtonMElements[0].action= {|val| nk.sendOsc([])};
nk.nanoButtonMElements[1].action= {|val|
	if(val>0, {
		nk.sendOsc([
			[\sStream, \metronomeOn, 1]
		]);
	});
};
nk.nanoButtonMElements[2].action= {|val|
	if(val>0, {
		nk.sendOsc([
		]);
	});
};
nk.nanoButtonMElements[3].action= {|val|
	if(val>0, {
		nk.sendOsc([
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
		]);
	});
};
nk.nanoButtonRElements[3].action= {|val|
	if(val>0, {
		nk.sendOsc([
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
				[\sStream, \avOn, 1]
			]);
		});
	};
};
nk.nanoCtrlButtons.collect{|d| d[\play]}.do{|button|
	button.action= {|view|
		if(view.value>0, {
			nk.sendOsc([
			]);
		});
	};
};
nk.nanoCtrlButtons.collect{|d| d[\ff]}.do{|button|
	button.action= {|view|
		if(view.value>0, {
			nk.sendOsc([
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
