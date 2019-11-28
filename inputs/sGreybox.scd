//f.olofsson 2019

//teensy 3.2 with tamas_teensy.ino
//TODO sync gui with functions (metro, sustain, bend...)
//TODO smoothing

(
//--settings
var serialPortName= "usbmodem2062641";  //greybox
var winRect= Rect(0, 80, 320, 240);  //x, y, w, h
var palette= SGUI.palette;
var fnt= SGUI.font;
var fntMono= Font.monospace(10);
var fps= 15;  //maximum gui updaterate - does not affect sensor input rate
var sliderInvert= #[false, false, false, false, true, false, false, true, true, true, true, true, true, true, true, true];  //true will be inverted

//--functions and objects
var path= SerialPort.devices.detect{|x| x.contains(serialPortName)};
var port= try{SerialPort(path, 115200, crtscts: true)};
var sendOsc;
var on= true;
var updateLeds;
var leds= 0;  //16bit value
var lastLeds= 0;
var lastLedsTime= 0;
var setupOscResponders, oscResponders;
var routineSerial, routineGui;
var matchArr, matchArrCopy, matchFunc, matchIndex;

var matchArr2, matchArr2Copy, matchFunc2, matchIndex2;
var lastArr= Array.newClear(16);
var lastArr2= Array.newClear(16);

//--gui
var onButton;
var plate;
var streamSliderElements= {SGUIelement()}!16;  //but only 14 working
var streamButtonElements= {SGUIelement()}!16;  //but only 15 working
var infoTextElementString= SGUIelementString();
var win= Window("sGreybox", winRect);
win.layout= VLayout(
	onButton= Button().states_([
		["  Greybox", palette.buttonText, palette.button],
		["•Greybox", palette.buttonText, palette.highlight]
	]),
	plate= View().fixedSize_(Size(320, 240)).background_(Color.grey(0.9, 0.5)),
	infoTextElementString.addView(StaticText().fixedHeight_(" ".bounds(fntMono).height*2)
		.align_(\topLeft).background_(Color.grey(0.9, 0.5)))
);

win.onClose= {
	NetAddr.localAddr.sendMsg(\closed, \sGreybox);
	routineGui.stop;
	routineSerial.stop;
	if(port.notNil, {
		port.close;
	});
};
if(port.notNil, {
	"sGreybox at %".format(path).postln;
	CmdPeriod.doOnce({
		oscResponders.do{|x| x.free};
		port.close;
	});

	onButton.action= {|view|
		on= view.value.booleanValue;
	};
	onButton.value= on.binaryValue;

	matchFunc= {|arr|  //analog inputs
		//[\ana, arr].postln;  //debug
		streamSliderElements.do{|sld, i|
			if(sliderInvert[i], {
				sld.value= 1-(arr[i]/1023);
			}, {
				sld.value= arr[i]/1023;
			});
		};
	};

	matchFunc2= {|arr|  //digital inputs
		//[\dig, arr].postln;  //debug
		streamButtonElements.do{|but, i|
			if(arr[i]!=lastArr2[i], {
				lastArr2[i]= arr[i];
				but.value= arr[i];
			});
		};
	};

	matchArr= #[200, 201]++(nil!32)++202;
	matchArrCopy= matchArr.copy;
	matchIndex= 0;
	matchArr2= #[250, 251]++(nil!2)++252;
	matchArr2Copy= matchArr2.copy;
	matchIndex2= 0;

	routineSerial= Routine.run({
		inf.do{
			var byte= port.read;
			if(on, {
				if(matchIndex2==0 and:{matchArr[matchIndex].isNil or:{matchArr[matchIndex]==byte}}, {
					matchArrCopy[matchIndex]= byte;
					matchIndex= matchIndex+1;
					if(matchIndex>=matchArr.size, {
						matchFunc.value([
							matchArrCopy[3]<<8+matchArrCopy[2],
							matchArrCopy[5]<<8+matchArrCopy[4],
							matchArrCopy[7]<<8+matchArrCopy[6],
							matchArrCopy[9]<<8+matchArrCopy[8],
							matchArrCopy[11]<<8+matchArrCopy[10],
							matchArrCopy[13]<<8+matchArrCopy[12],
							matchArrCopy[15]<<8+matchArrCopy[14],
							matchArrCopy[17]<<8+matchArrCopy[16],
							matchArrCopy[19]<<8+matchArrCopy[18],
							matchArrCopy[21]<<8+matchArrCopy[20],
							matchArrCopy[23]<<8+matchArrCopy[22],
							matchArrCopy[25]<<8+matchArrCopy[24],
							matchArrCopy[27]<<8+matchArrCopy[26],
							matchArrCopy[29]<<8+matchArrCopy[28],
							matchArrCopy[31]<<8+matchArrCopy[30],
							matchArrCopy[33]<<8+matchArrCopy[32]
						]);
						matchIndex= 0;
					});
				}, {
					if(matchIndex==0 and:{matchArr2[matchIndex2].isNil or:{matchArr2[matchIndex2]==byte}}, {
						matchArr2Copy[matchIndex2]= byte;
						matchIndex2= matchIndex2+1;
						if(matchIndex2>=matchArr2.size, {
							matchFunc2.value(
								((matchArr2Copy[2]<<8)+matchArr2Copy[3]).asBinaryDigits(16)
							);
							matchIndex2= 0;
						});
					});
				});
			});
		};
	});
}, {
	"sGreybox serial port not found!".postln;
	SerialPort.listDevices;
});

//--network
sendOsc= {|arr|
	var str= "";
	arr.do{|a|
		SInputs.destinations[a[0]].sendMsg(*a[1..]);
		str= str++a.collect{|x| if(x.isFloat, {SGUI.fixDec(x, 2)}, {x})};
	};
	infoTextElementString.value= str.replace("[ ", "[").replace(" ]", "] ").replace(",", "");
};

setupOscResponders= {
	oscResponders= [

		//--from sStream
		OSCFunc({|msg|
			var index;
			var val= msg[2];
			switch(msg[1],
				\metroOn, {index= 0},  //174
				\lvOn, {index= 9},  //73
				\sustain, {index= 10},  //175
				\avBendOn, {index= 12},  //176
				\avOn, {index= 13},  //72
				\lvBendOn, {index= 14},  //32
				\avSustainOn, {index= 15},  //198
				\pitchState, {
					index= #[1, 11];  //178, 177
					switch(msg[2],
						0, {val= #[0, 0]},
						1, {val= #[1, 0]},
						2, {val= #[0, 1]},
						3, {val= #[1, 1]}
					);
				}
			);
			if(index.notNil, {
				index.asArray.do{|x, i|
					leds= leds.setBit(x.clip(0, 15), val.asArray[i].booleanValue);
				};
				updateLeds.value;
			}, {
				"sGreybox: led index % not found".format(msg[1]).postln;
			});
		}, \led, recvPort:SInputs.destinations.sGreybox.port)
	];
};

//--leds
updateLeds= {
	if(port.notNil and:{leds!=lastLeds and:{Main.elapsedTime-lastLedsTime>0.2}}, {  //limit updaterate
		lastLeds= leds;
		lastLedsTime= Main.elapsedTime;
		port.putAll(Int8Array[100, 101, leds&255, leds>>8, 102]);
	});
};


//--slider functions
/*
8 - c_11 - (ST_32) minimum entry delay
9 - c_14 - (ST_48) lv loudness
10 - c_12 - (ST_31) maximum pitch
11 - c_10 - (ST_34) duration (sustain)
12 - c_37 - (ST_46) chord delay (metronome)
13 - c_13 - (ST_47) av loudness
14 - c_17 - (ST_35) pitchbend range
15 - c_9 - (ST_30) minimum pitch
*/

streamSliderElements[0].addView(Slider(plate, Rect.aboutPoint(Point(0.4, 0.4)*plate.bounds.extent, 10, 40)));
streamSliderElements[0].action= {|val| sendOsc.value([[\sStream, \lvVolume, val]])};
StaticText(plate, Rect.aboutPoint(Point(0.4, 0.4)+0.01*plate.bounds.extent, 10, 40)).string_("109");

streamSliderElements[1].addView(Slider(plate, Rect.aboutPoint(Point(0.6, 0.75)*plate.bounds.extent, 10, 40)));
streamSliderElements[1].action= {|val| sendOsc.value([])};
StaticText(plate, Rect.aboutPoint(Point(0.6, 0.75)+0.01*plate.bounds.extent, 10, 40)).string_("110");

streamSliderElements[2].addView(Slider(plate, Rect.aboutPoint(Point(0.375, 0.75)*plate.bounds.extent, 10, 40)));
streamSliderElements[2].action= {|val| sendOsc.value([])};
StaticText(plate, Rect.aboutPoint(Point(0.375, 0.75)+0.01*plate.bounds.extent, 10, 40)).string_("111");

streamSliderElements[3].addView(Slider(plate, Rect.aboutPoint(Point(0.85, 0.95)*plate.bounds.extent, 40, 10)));
streamSliderElements[3].action= {|val| sendOsc.value([])};
StaticText(plate, Rect.aboutPoint(Point(0.85, 0.95)+0.01*plate.bounds.extent, 40, 10)).string_("112");

streamSliderElements[5].addView(Slider(plate, Rect.aboutPoint(Point(0.525, 0.75)*plate.bounds.extent, 10, 40)));
streamSliderElements[5].action= {|val| sendOsc.value([])};
StaticText(plate, Rect.aboutPoint(Point(0.525, 0.75)+0.01*plate.bounds.extent, 10, 40)).string_("114");

streamSliderElements[6].addView(Slider(plate, Rect.aboutPoint(Point(0.45, 0.75)*plate.bounds.extent, 10, 40)));
streamSliderElements[6].action= {|val| sendOsc.value([])};
StaticText(plate, Rect.aboutPoint(Point(0.45, 0.75)+0.01*plate.bounds.extent, 10, 40)).string_("115");


streamSliderElements[8].addView(Slider(plate, Rect.aboutPoint(Point(0.8, 0.35)*plate.bounds.extent, 10, 40)));
streamSliderElements[8].action= {|val| sendOsc.value([[\sStream, \rateScale, val]])};
StaticText(plate, Rect.aboutPoint(Point(0.8, 0.35)+0.01*plate.bounds.extent, 10, 40)).string_("11");

streamSliderElements[10].addView(Slider(plate, Rect.aboutPoint(Point(0.7, 0.3)*plate.bounds.extent, 10, 40)));
streamSliderElements[10].action= {|val| sendOsc.value([[\sStream, \lvPitchMinMaxRangeHi, val]])};
StaticText(plate, Rect.aboutPoint(Point(0.7, 0.3)+0.01*plate.bounds.extent, 10, 40)).string_("12");

streamSliderElements[15].addView(Slider(plate, Rect.aboutPoint(Point(0.6, 0.3)*plate.bounds.extent, 10, 40)));
streamSliderElements[15].action= {|val| sendOsc.value([[\sStream, \lvPitchMinMaxRangeLo, val]])};
StaticText(plate, Rect.aboutPoint(Point(0.6, 0.3)+0.02*plate.bounds.extent, 10, 40)).string_("9");

/*streamSliderElements[13].addView(Slider(plate, Rect.aboutPoint(Point(0.35, 0.35)*plate.bounds.extent, 10, 40)));
streamSliderElements[13].action= {|val| sendOsc.value([[\sStream, \lvVolume, val]])};
StaticText(plate, Rect.aboutPoint(Point(0.35, 0.35)+0.01*plate.bounds.extent, 10, 40)).string_("14");*/  //hardware broken

streamSliderElements[9].addView(Slider(plate, Rect.aboutPoint(Point(0.5, 0.35)*plate.bounds.extent, 10, 40)));
streamSliderElements[9].action= {|val| sendOsc.value([[\sStream, \avVolume, val]])};
StaticText(plate, Rect.aboutPoint(Point(0.5, 0.35)+0.01*plate.bounds.extent, 10, 40)).string_("13");


streamSliderElements[14].addView(Slider(plate, Rect.aboutPoint(Point(0.85, 0.65)*plate.bounds.extent, 40, 10)));
streamSliderElements[14].action= {|val| sendOsc.value([[\sStream, \lvPitchBend, val]])};
StaticText(plate, Rect.aboutPoint(Point(0.85, 0.65)+0.01*plate.bounds.extent, 40, 10)).string_("17");

streamSliderElements[11].addView(Slider(plate, Rect.aboutPoint(Point(0.85, 0.75)*plate.bounds.extent, 40, 10)));
streamSliderElements[11].action= {|val| sendOsc.value([[\sStream, \lvSustain, val]])};
StaticText(plate, Rect.aboutPoint(Point(0.85, 0.75)+0.01*plate.bounds.extent, 40, 10)).string_("10");

streamSliderElements[12].addView(Slider(plate, Rect.aboutPoint(Point(0.85, 0.85)*plate.bounds.extent, 40, 10)));
//streamSliderElements[12].action= {|val| sendOsc.value([[\sStream, \metronome, val]])};
StaticText(plate, Rect.aboutPoint(Point(0.85, 0.85)+0.01*plate.bounds.extent, 40, 10)).string_("37");

//--button functions
/*
√	0 - b_172 - (bgr_6) e-del maximum 25
-	1 - b_196 - (ST_11) outputrec start playback (new interv. into 16Buffer)
-	2 - b_192 - (bgr_8) DPlacement within range
-	3 - b_198 - (ST_18) outputrec start record (activate 16PitchBuffer)
√	4 - b_32 - (ST_15) LV PB on/off
√	5 - b_175 - (ST_6) sustain on/off
√	6 - b_33 - (ST_28) AutoBeat Velocity Modulation (pianotec onoff toggle)
√	7 - b_179 - (ST_17) AV-RhythmListSwitch (garageband onoff toggle)
√	8 - b_173 - (bgr_6) e-del maximum 0
√	9 - b_174 - (ST_13) metro on/off
√	10 - b_176 - (ST_20) AV PB on/off
√	11 - b_72 - (ST_12) AV on/off
√	12 - b_73 - (ST_19) LV on/off
√	13 - b_178 - (bgr_34) - Metronom Pitch
-	14 - b_193 - (bgr_8) DPlacement outside range
√	15 - b_177 - (bgr_34) - Direct Pitch
*/
streamButtonElements[8].addView(Button(plate, Rect.aboutPoint(Point(0.925, 0.35)*plate.bounds.extent, 12, 10)).states_([
	["173", palette.buttonText, palette.button],
	["173", palette.buttonText, palette.highlight]
]));
streamButtonElements[8].action= {|val| if(val==1, {
	sendOsc.value([[\sStream, \rateMultiplier, 1]]);
	{streamButtonElements[8].value= 0}.defer(0.2);
})};

streamButtonElements[0].addView(Button(plate, Rect.aboutPoint(Point(0.925, 0.225)*plate.bounds.extent, 12, 10)).states_([
	["172", /*palette.buttonText*/Color.grey(0.7), palette.button],
	["172", palette.buttonText, palette.highlight]
]));
streamButtonElements[0].action= {|val| if(val==1, {
	sendOsc.value([]);  //unused
	infoTextElementString.value= "172 - unused";
	{streamButtonElements[0].value= 0}.defer(0.2);
})};

streamButtonElements[5].addView(Button(plate, Rect.aboutPoint(Point(0.2, 0.9)*plate.bounds.extent, 12, 10)).states_([
	["32", palette.buttonText, palette.button],
	["32", palette.buttonText, palette.highlight]
]));
streamButtonElements[5].action= {|val| if(val==1, {
	sendOsc.value([[\sStream, \lvPitchLoopMode, 3]]);
	{streamButtonElements[5].value= 0}.defer(0.2);
})};

streamButtonElements[4].addView(Button(plate, Rect.aboutPoint(Point(0.2, 0.8)*plate.bounds.extent, 12, 10)).states_([
	["175", palette.buttonText, palette.button],
	["175", palette.buttonText, palette.highlight]
]));
streamButtonElements[4].action= {|val| if(val==1, {
	sendOsc.value([[\sStream, \lvPitchLoopMode, 1]]);
	{streamButtonElements[4].value= 0}.defer(0.2);
})};

streamButtonElements[10].addView(Button(plate, Rect.aboutPoint(Point(0.1, 0.75)*plate.bounds.extent, 12, 10)).states_([
	["176", palette.buttonText, palette.button],
	["176", palette.buttonText, palette.highlight]
]));
streamButtonElements[10].action= {|val| if(val==1, {
	sendOsc.value([[\sStream, \lvPitchLoopMode, 2]]);
	{streamButtonElements[10].value= 0}.defer(0.2);
})};

streamButtonElements[9].addView(Button(plate, Rect.aboutPoint(Point(0.925, 0.5)*plate.bounds.extent, 12, 10)).states_([
	["174", palette.buttonText, palette.button],
	["174", palette.buttonText, palette.highlight]
]));
streamButtonElements[9].action= {|val| if(val==1, {
	sendOsc.value([[\sStream, \metronomeOn, 1]]);
	{streamButtonElements[9].value= 0}.defer(0.2);
})};

streamButtonElements[6].addView(Button(plate, Rect.aboutPoint(Point(0.1, 0.85)*plate.bounds.extent, 12, 10)).states_([
	["33", palette.buttonText, palette.button],
	["33", palette.buttonText, palette.highlight]
]));
streamButtonElements[6].action= {|val| if(val==1, {
	sendOsc.value([[\sStream, \lvPitchLoopMode, 0]]);
	{streamButtonElements[6].value= 0}.defer(0.2);
})};

streamButtonElements[7].addView(Button(plate, Rect.aboutPoint(Point(0.075, 0.1)*plate.bounds.extent, 12, 10)).states_([
	["179", /*palette.buttonText*/Color.grey(0.7), palette.button],
	["179", palette.buttonText, palette.highlight]
]));
streamButtonElements[7].action= {|val| if(val==1, {
	sendOsc.value([]);  //unused
	infoTextElementString.value= "179 - unused";
	{streamButtonElements[7].value= 0}.defer(0.2);
})};

streamButtonElements[11].addView(Button(plate, Rect.aboutPoint(Point(0.75, 0.05)*plate.bounds.extent, 12, 10)).states_([
	["72", palette.buttonText, palette.button],
	["72", palette.buttonText, palette.highlight]
]));
streamButtonElements[11].action= {|val| if(val==1, {
	sendOsc.value([[\sStream, \avOn, 1]]);
	{streamButtonElements[11].value= 0}.defer(0.2);
})};

streamButtonElements[12].addView(Button(plate, Rect.aboutPoint(Point(0.5, 0.05)*plate.bounds.extent, 12, 10)).states_([
	["73", palette.buttonText, palette.button],
	["73", palette.buttonText, palette.highlight]
]));
streamButtonElements[12].action= {|val| if(val==1, {
	sendOsc.value([[\sStream, \lvOn, 1]]);
	{streamButtonElements[12].value= 0}.defer(0.2);
})};

streamButtonElements[13].addView(Button(plate, Rect.aboutPoint(Point(0.2, 0.25)*plate.bounds.extent, 12, 10)).states_([
	["178", palette.buttonText, palette.button],
	["178", palette.buttonText, palette.highlight]
]));
streamButtonElements[13].action= {|val| if(val==1, {
	sendOsc.value([[\sStream, \lvPitchesPattern, \toggle]]);
	{streamButtonElements[13].value= 0}.defer(0.2);
})};

streamButtonElements[15].addView(Button(plate, Rect.aboutPoint(Point(0.2, 0.35)*plate.bounds.extent, 12, 10)).states_([
	["177", palette.buttonText, palette.button],
	["177", palette.buttonText, palette.highlight]
]));
streamButtonElements[15].action= {|val| if(val==1, {
	sendOsc.value([[\sStream, \lvPitchesPattern, \mix]]);
	{streamButtonElements[15].value= 0}.defer(0.2);
})};

streamButtonElements[1].addView(Button(plate, Rect.aboutPoint(Point(0.2, 0.1)*plate.bounds.extent, 12, 10)).states_([
	["196", /*palette.buttonText*/Color.grey(0.7), palette.button],
	["196", palette.buttonText, palette.highlight]
]));
streamButtonElements[1].action= {|val| if(val==1, {
	sendOsc.value([]);  //unused
	infoTextElementString.value= "196 - unused";
	{streamButtonElements[1].value= 0}.defer(0.2);
})};

//192 button is broken
/*
streamButtonElements[2].addView(Button(plate, Rect.aboutPoint(Point(0.075, 0.95)*plate.bounds.extent, 12, 10)).states_([
["192", /*palette.buttonText*/Color.grey(0.7), palette.button],
["192", palette.buttonText, palette.highlight]
]));
streamButtonElements[2].action= {|val| if(val==1, {
sendOsc.value([]);  //unused
infoTextElementString.value= "192 - unused";
{streamButtonElements[2].value= 0}.defer(0.2);
})};
*/

streamButtonElements[3].addView(Button(plate, Rect.aboutPoint(Point(0.05
	, 0.3)*plate.bounds.extent, 12, 10)).states_([
	["198", palette.buttonText, palette.button],
	["198", palette.buttonText, palette.highlight]
]));
streamButtonElements[3].action= {|val| if(val==1, {
	sendOsc.value([[\sStream, \avSustainOn, 1]]);
	{streamButtonElements[3].value= 0}.defer(0.2);
})};

streamButtonElements[14].addView(Button(plate, Rect.aboutPoint(Point(0.1, 0.95)*plate.bounds.extent, 12, 10)).states_([
	["193", palette.buttonText, palette.button],
	["193", palette.buttonText, palette.highlight]
]));
streamButtonElements[14].action= {|val| if(val==1, {
	sendOsc.value([[\sStream, \lvPitchLoopMode, 4]]);
	{streamButtonElements[14].value= 0}.defer(0.2);
})};

plate.allChildren.do{|view| if(view.isKindOf(StaticText), {view.acceptsMouse= false})};

routineGui= Routine({
	inf.do{
		streamSliderElements.do{|e| e.update};
		streamButtonElements.do{|e| e.update};
		infoTextElementString.update;
		fps.reciprocal.wait;
	};
}).play(AppClock);
SGUI.report(win);
SGUI.adapt(win);
infoTextElementString.views.do{|view| view.font= fntMono};
setupOscResponders.value;
win.front;
)
