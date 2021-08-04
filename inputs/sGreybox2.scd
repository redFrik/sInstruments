//f.olofsson 2019

//teensy 3.2 with tamas2_teensy.ino, no leds
//TODO smoothing

(
//--settings
var serialPortName= "usbmodem1922351";  //greybox
var winRect= Rect(0, 80, 320, 240);  //x, y, w, h
var palette= SGUI.palette;
var fnt= SGUI.font;
var fntMono= Font.monospace(10);
var fps= 15;  //maximum gui updaterate - does not affect sensor input rate
var sliderInvert= #[false, false, false, true, true, true, true, true, true, true, false, false];  //true will be inverted

//--functions and objects
var path= SerialPort.devices.detect{|x| x.contains(serialPortName)};
var port= try{SerialPort(path, 115200, crtscts: true)};
var sendOsc;
var on= true;
var routineSerial, routineGui;
var matchArr, matchArrCopy, matchFunc, matchIndex;

var matchArr2, matchArr2Copy, matchFunc2, matchIndex2;
var lastArr= Array.newClear(12);
var lastArr2= Array.newClear(22);

//--gui
var onButton;
var plate;
var streamSliderElements= {SGUIelement()}!12;  //but only 7 working
var streamButtonElements= {SGUIelement()}!22;
var infoTextElementString= SGUIelementString();
var win= Window("sGreybox2", winRect);
win.layout= VLayout(
	onButton= Button().states_([
		["  Greybox2", palette.buttonText, palette.button],
		["•Greybox2", palette.buttonText, palette.highlight]
	]),
	plate= View().fixedSize_(Size(320, 240)).background_(Color.grey(0.9, 0.5)),
	infoTextElementString.addView(StaticText().fixedHeight_(" ".bounds(fntMono).height*2)
		.align_(\topLeft).background_(Color.grey(0.9, 0.5)))
);

win.onClose= {
	NetAddr.localAddr.sendMsg(\closed, \sGreybox2);
	routineGui.stop;
	routineSerial.stop;
	if(port.notNil, {
		port.close;
	});
};
if(port.notNil, {
	"sGreybox2 at %".format(path).postln;
	CmdPeriod.doOnce({
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

	matchArr= #[210, 211]++(nil!24)++212;
	matchArrCopy= matchArr.copy;
	matchIndex= 0;
	matchArr2= #[240, 241]++(nil!3)++242;
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
							matchArrCopy[25]<<8+matchArrCopy[24]
						]);
						matchIndex= 0;
					});
				}, {
					if(matchIndex==0 and:{matchArr2[matchIndex2].isNil or:{matchArr2[matchIndex2]==byte}}, {
						matchArr2Copy[matchIndex2]= byte;
						matchIndex2= matchIndex2+1;
						if(matchIndex2>=matchArr2.size, {
							matchFunc2.value(
								((matchArr2Copy[2]<<14)+(matchArr2Copy[3]<<6)+(matchArr2Copy[4]&63)).asBinaryDigits(22)
							);
							matchIndex2= 0;
						});
					});
				});
			});
		};
	});
}, {
	"sGreybox2 serial port not found!".postln;
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


//--slider functions
//streamSliderElements[0]  //unused
//streamSliderElements[1]  //unused
//streamSliderElements[2]  //unused
//streamSliderElements[10]  //unused
//streamSliderElements[11]  //unused

streamSliderElements[3].addView(Slider(plate, Rect.aboutPoint(Point(0.45, 0.75)*plate.bounds.extent, 10, 40)));
streamSliderElements[3].action= {|val| sendOsc.value([])};
StaticText(plate, Rect.aboutPoint(Point(0.45, 0.75)+0.01*plate.bounds.extent, 10, 40)).string_("3");

streamSliderElements[4].addView(Slider(plate, Rect.aboutPoint(Point(0.2, 0.3)*plate.bounds.extent, 40, 10)));
streamSliderElements[4].action= {|val| sendOsc.value([])};
StaticText(plate, Rect.aboutPoint(Point(0.3, 0.3)+0.01*plate.bounds.extent, 40, 10)).string_("4");

streamSliderElements[5].addView(Slider(plate, Rect.aboutPoint(Point(0.125, 0.75)*plate.bounds.extent, 10, 40)));
streamSliderElements[5].action= {|val| sendOsc.value([])};
StaticText(plate, Rect.aboutPoint(Point(0.125, 0.75)+0.01*plate.bounds.extent, 10, 40)).string_("5");

streamSliderElements[6].addView(Slider(plate, Rect.aboutPoint(Point(0.75, 0.25)*plate.bounds.extent, 10, 40)));
streamSliderElements[6].action= {|val| sendOsc.value([])};
StaticText(plate, Rect.aboutPoint(Point(0.75, 0.25)+0.01*plate.bounds.extent, 10, 40)).string_("6");

streamSliderElements[7].addView(Slider(plate, Rect.aboutPoint(Point(0.85, 0.25)*plate.bounds.extent, 10, 40)));
streamSliderElements[7].action= {|val| sendOsc.value([])};
StaticText(plate, Rect.aboutPoint(Point(0.85, 0.25)+0.01*plate.bounds.extent, 10, 40)).string_("7");

streamSliderElements[8].addView(Slider(plate, Rect.aboutPoint(Point(0.55, 0.25)*plate.bounds.extent, 10, 40)));
streamSliderElements[8].action= {|val| sendOsc.value([])};
StaticText(plate, Rect.aboutPoint(Point(0.55, 0.25)+0.01*plate.bounds.extent, 10, 40)).string_("8");

//broken hardware slider!
streamSliderElements[9].addView(Slider(plate, Rect.aboutPoint(Point(0.55, 0.75)*plate.bounds.extent, 10, 40)));
streamSliderElements[9].action= {|val| sendOsc.value([])};
StaticText(plate, Rect.aboutPoint(Point(0.55, 0.75)+0.01*plate.bounds.extent, 10, 40)).string_("9");


//--button functions

streamButtonElements[0].addView(Button(plate, Rect.aboutPoint(Point(0.85, 0.7)*plate.bounds.extent, 12, 10)).states_([
	["0", palette.buttonText, palette.button],
	["0", palette.buttonText, palette.highlight]
]));
streamButtonElements[0].action= {|val| if(val==1, {
	sendOsc.value([]);
	{streamButtonElements[0].value= 0}.defer(0.2);
})};

streamButtonElements[1].addView(Button(plate, Rect.aboutPoint(Point(0.85, 0.8)*plate.bounds.extent, 12, 10)).states_([
	["1", palette.buttonText, palette.button],
	["1", palette.buttonText, palette.highlight]
]));
streamButtonElements[1].action= {|val| if(val==1, {
	sendOsc.value([]);
	{streamButtonElements[1].value= 0}.defer(0.2);
})};

streamButtonElements[2].addView(Button(plate, Rect.aboutPoint(Point(0.95, 0.8)*plate.bounds.extent, 12, 10)).states_([
	["2", palette.buttonText, palette.button],
	["2", palette.buttonText, palette.highlight]
]));
streamButtonElements[2].action= {|val| if(val==1, {
	sendOsc.value([]);
	{streamButtonElements[2].value= 0}.defer(0.2);
})};

streamButtonElements[3].addView(Button(plate, Rect.aboutPoint(Point(0.95, 0.7)*plate.bounds.extent, 12, 10)).states_([
	["3", palette.buttonText, palette.button],
	["3", palette.buttonText, palette.highlight]
]));
streamButtonElements[3].action= {|val| if(val==1, {
	sendOsc.value([]);
	{streamButtonElements[3].value= 0}.defer(0.2);
})};

streamButtonElements[4].addView(Button(plate, Rect.aboutPoint(Point(0.95, 0.5)*plate.bounds.extent, 12, 10)).states_([
	["4", palette.buttonText, palette.button],
	["4", palette.buttonText, palette.highlight]
]));
streamButtonElements[4].action= {|val| if(val==1, {
	sendOsc.value([]);
	{streamButtonElements[4].value= 0}.defer(0.2);
})};

streamButtonElements[5].addView(Button(plate, Rect.aboutPoint(Point(0.95, 0.3)*plate.bounds.extent, 12, 10)).states_([
	["5", palette.buttonText, palette.button],
	["5", palette.buttonText, palette.highlight]
]));
streamButtonElements[5].action= {|val| if(val==1, {
	sendOsc.value([]);
	{streamButtonElements[5].value= 0}.defer(0.2);
})};

streamButtonElements[6].addView(Button(plate, Rect.aboutPoint(Point(0.15, 0.1)*plate.bounds.extent, 12, 10)).states_([
	["6", palette.buttonText, palette.button],
	["6", palette.buttonText, palette.highlight]
]));
streamButtonElements[6].action= {|val| if(val==1, {
	sendOsc.value([]);
	{streamButtonElements[6].value= 0}.defer(0.2);
})};

streamButtonElements[7].addView(Button(plate, Rect.aboutPoint(Point(0.45, 0.15)*plate.bounds.extent, 12, 10)).states_([
	["7", palette.buttonText, palette.button],
	["7", palette.buttonText, palette.highlight]
]));
streamButtonElements[7].action= {|val| if(val==1, {
	sendOsc.value([]);
	{streamButtonElements[7].value= 0}.defer(0.2);
})};

streamButtonElements[8].addView(Button(plate, Rect.aboutPoint(Point(0.2, 0.75)*plate.bounds.extent, 12, 10)).states_([
	["8", palette.buttonText, palette.button],
	["8", palette.buttonText, palette.highlight]
]));
streamButtonElements[8].action= {|val| if(val==1, {
	sendOsc.value([]);
	{streamButtonElements[8].value= 0}.defer(0.2);
})};

streamButtonElements[9].addView(Button(plate, Rect.aboutPoint(Point(0.225, 0.9)*plate.bounds.extent, 12, 10)).states_([
	["9", palette.buttonText, palette.button],
	["9", palette.buttonText, palette.highlight]
]));
streamButtonElements[9].action= {|val| if(val==1, {
	sendOsc.value([]);
	{streamButtonElements[9].value= 0}.defer(0.2);
})};

streamButtonElements[10].addView(Button(plate, Rect.aboutPoint(Point(0.25, 0.15)*plate.bounds.extent, 12, 10)).states_([
	["10", palette.buttonText, palette.button],
	["10", palette.buttonText, palette.highlight]
]));
streamButtonElements[10].action= {|val| if(val==1, {
	sendOsc.value([]);
	{streamButtonElements[10].value= 0}.defer(0.2);
})};

streamButtonElements[11].addView(Button(plate, Rect.aboutPoint(Point(0.75, 0.7)*plate.bounds.extent, 12, 10)).states_([
	["11", palette.buttonText, palette.button],
	["11", palette.buttonText, palette.highlight]
]));
streamButtonElements[11].action= {|val| if(val==1, {
	sendOsc.value([]);
	{streamButtonElements[11].value= 0}.defer(0.2);
})};

streamButtonElements[12].addView(Button(plate, Rect.aboutPoint(Point(0.65, 0.35)*plate.bounds.extent, 12, 10)).states_([
	["12", palette.buttonText, palette.button],
	["12", palette.buttonText, palette.highlight]
]));
streamButtonElements[12].action= {|val| if(val==1, {
	sendOsc.value([]);
	{streamButtonElements[12].value= 0}.defer(0.2);
})};

streamButtonElements[13].addView(Button(plate, Rect.aboutPoint(Point(0.75, 0.6)*plate.bounds.extent, 12, 10)).states_([
	["13", palette.buttonText, palette.button],
	["13", palette.buttonText, palette.highlight]
]));
streamButtonElements[13].action= {|val| if(val==1, {
	sendOsc.value([]);
	{streamButtonElements[13].value= 0}.defer(0.2);
})};

streamButtonElements[14].addView(Button(plate, Rect.aboutPoint(Point(0.85, 0.6)*plate.bounds.extent, 12, 10)).states_([
	["14", palette.buttonText, palette.button],
	["14", palette.buttonText, palette.highlight]
]));
streamButtonElements[14].action= {|val| if(val==1, {
	sendOsc.value([]);
	{streamButtonElements[14].value= 0}.defer(0.2);
})};

streamButtonElements[15].addView(Button(plate, Rect.aboutPoint(Point(0.95, 0.6)*plate.bounds.extent, 12, 10)).states_([
	["15", palette.buttonText, palette.button],
	["15", palette.buttonText, palette.highlight]
]));
streamButtonElements[15].action= {|val| if(val==1, {
	sendOsc.value([]);
	{streamButtonElements[15].value= 0}.defer(0.2);
})};

streamButtonElements[16].addView(Button(plate, Rect.aboutPoint(Point(0.355, 0.75)*plate.bounds.extent, 12, 10)).states_([
	["16", palette.buttonText, palette.button],
	["16", palette.buttonText, palette.highlight]
]));
streamButtonElements[16].action= {|val| if(val==1, {
	sendOsc.value([]);
	{streamButtonElements[16].value= 0}.defer(0.2);
})};

streamButtonElements[17].addView(Button(plate, Rect.aboutPoint(Point(0.275, 0.75)*plate.bounds.extent, 12, 10)).states_([
	["17", palette.buttonText, palette.button],
	["17", palette.buttonText, palette.highlight]
]));
streamButtonElements[17].action= {|val| if(val==1, {
	sendOsc.value([]);
	{streamButtonElements[17].value= 0}.defer(0.2);
})};

streamButtonElements[18].addView(Button(plate, Rect.aboutPoint(Point(0.35, 0.1)*plate.bounds.extent, 12, 10)).states_([
	["18", palette.buttonText, palette.button],
	["18", palette.buttonText, palette.highlight]
]));
streamButtonElements[18].action= {|val| if(val==1, {
	sendOsc.value([]);
	{streamButtonElements[18].value= 0}.defer(0.2);
})};

streamButtonElements[19].addView(Button(plate, Rect.aboutPoint(Point(0.35, 0.9)*plate.bounds.extent, 12, 10)).states_([
	["19", palette.buttonText, palette.button],
	["19", palette.buttonText, palette.highlight]
]));
streamButtonElements[19].action= {|val| if(val==1, {
	sendOsc.value([]);
	{streamButtonElements[19].value= 0}.defer(0.2);
})};

streamButtonElements[20].addView(Button(plate, Rect.aboutPoint(Point(0.05, 0.15)*plate.bounds.extent, 12, 10)).states_([
	["20", palette.buttonText, palette.button],
	["20", palette.buttonText, palette.highlight]
]));
streamButtonElements[20].action= {|val| if(val==1, {
	sendOsc.value([]);
	{streamButtonElements[20].value= 0}.defer(0.2);
})};

streamButtonElements[21].addView(Button(plate, Rect.aboutPoint(Point(0.05, 0.9)*plate.bounds.extent, 12, 10)).states_([
	["21", palette.buttonText, palette.button],
	["21", palette.buttonText, palette.highlight]
]));
streamButtonElements[21].action= {|val| if(val==1, {
	sendOsc.value([]);
	{streamButtonElements[21].value= 0}.defer(0.2);
})};

plate.allChildren.do{|view| if(view.isKindOf(StaticText), {view.acceptsMouse= false})};
if(SGUI.currentTheme!=\dark, {
	plate.children.select{|v| v.isKindOf(Slider)}.do{|v|
		v.background= Color.grey(0.7725, 0.5);
	};
});

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
win.front;
)
