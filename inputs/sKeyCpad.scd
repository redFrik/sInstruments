//f.olofsson 2019

//arduino nano with sKeyCpad-firmware.ino

(
//--settings
var serialPortName= "/dev/cu.wchusbserial14[0-9]*0";  //regexp
var winRect= Rect(0, 70, 400, 175);  //x, y, w, h
var palette= SGUI.palette;
var fnt= SGUI.font;
var fntMono= Font.monospace(10);

//--functions and objects
var sendOsc;
var routine;
var plate= #[
	[0, 1, 2, 3, 4, 5],
	[6, 7, 8, 9, 10, 11],
	[12, 13, 14, 15, 16, 17],
	[18, 19, 20, 21]
];
var external= #[
	[80, 81, 82, 83, 84, 85],
	[86]
];

//--gui
var plateButtons= List.new;
var externalButtons= List.new;
var infoTextString;
var win= Window("sKeyCpad", winRect);
win.layout= HLayout(
	GridLayout.rows(
		*plate.collect{|arr|
			arr.collect{|number|
				plateButtons.add(Button().states_([
					[number, palette.buttonText, palette.button],
					[number, palette.buttonText, palette.highlight]
				]).fixedWidth_(25)).last;
			};
		}
	),
	View().fixedWidth_(15),
	VLayout(
		GridLayout.rows(
			*external.collect{|arr|
				arr.collect{|number|
					externalButtons.add(Button().states_([
						[number, palette.buttonText, palette.button],
						[number, palette.buttonText, palette.highlight]
					]).fixedWidth_(25)).last;
				};
			}
		),
		infoTextString= StaticText().fixedHeight_(" ".bounds(fntMono).height*2)
		.align_(\topLeft).background_(Color.grey(0.9, 0.5))
	)
);
SGUI.report(win);
SGUI.adapt(win);
win.front;
infoTextString.font= fntMono;

sendOsc= {|arr|
	var str= "";
	arr.do{|a|
		SInputs.destinations[a[0]].sendMsg(a[1], a[2]);
		str= str++a;
	};
	infoTextString.string= str.replace("[ ", "[").replace(" ]", "] ").replace(", ", " ");
};

//--
Routine({
	var port, portFound= false;

	//--try multiple ports if many with similar name
	SerialPort.devices.select{|path| serialPortName.matchRegexp(path)}.do{|path|
		var str= "", byte, timer;
		if(portFound.not, {
			port= try{SerialPort(path, 38400, crtscts: true)};
			if(port.notNil, {
				timer= Main.elapsedTime;
				while({byte!=10 and:{Main.elapsedTime-timer<2}}, {
					byte= port.next;
					if(byte.notNil, {
						str= str++byte.asAscii;
						if(str.contains("sKeyCpad\r\n"), {
							timer= 0;
							portFound= true;
							"sKeyCpad found at %".format(path).postln;
						});
					});
					0.01.wait;
				});
				if(portFound.not, {
					port.close;
				});
			});
		});
	};
	if(port.isNil, {
		"sKeyCpad serial port not found".postln;
	}, {
		if(portFound.not, {
			"sKeyCpad serial port not responding".postln;
		}, {

			//--start reading from found port
			"sKeyCpad connected".postln;
			infoTextString.string= "connected!";
			routine= Routine.run({
				inf.do{|i|
					var val;
					var byte= port.read;
					//32-55= button 1 to 24 down, 56-79= button 1 to 24 up
					//80-86= ext pin 1 to 7 down, 87-93= ext pin 1 to 7 up
					case
					{byte>=32 and:{byte<56}} {  //button up
						val= 0;
					}
					{byte>=56 and:{byte<80}} {  //button down
						val= 1;
						byte= byte-24;
					}
					{byte>=80 and:{byte<87}} {  //ext pin up
						val= 1;
					}
					{byte>=87 and:{byte<94}} {  //ext pin down
						val= 0;
						byte= byte-7;
					};
					if(val.notNil, {
						if(byte<80, {
							if(byte>=50, {
								byte= byte-2;  //compensate for two unused inputs
							});
							{plateButtons[byte-32].valueAction= val}.defer;
						}, {
							{externalButtons.at(#[6, 3, 2, 1, 0, 4, 5])[(byte-80)].valueAction= val}.defer;
						});
						//[byte, val].postln;  //debug
					});
				};
			});
			CmdPeriod.doOnce({
				port.close;
			});
		});
	});
	win.onClose= {
		NetAddr.localAddr.sendMsg(\closed, \sKeyCpad);
		routine.stop;
		if(port.notNil, {
			port.close;
		});
	};
}).play(AppClock);

plateButtons[0].action= {|view|
	if(view.value==1, {
		sendOsc.value([]);
	});
};

externalButtons[0].action= {|view|
	if(view.value==1, {
		sendOsc.value([[\sStream, \on, 1]]);
	});
};
externalButtons[1].action= {|view|
	if(view.value==1, {
		sendOsc.value([[\sGliss, \on, 1]]);
	});
};
externalButtons[2].action= {|view|
	if(view.value==1, {
		sendOsc.value([[\sDrone, \on, 1]]);
	});
};
externalButtons[3].action= {|view|
	if(view.value==1, {
		sendOsc.value([[\sCluster, \on, 1]]);
	});
};
externalButtons[4].action= {|view|
	if(view.value==1, {
		sendOsc.value([[\sFormant, \on, 1]]);
	});
};
externalButtons[5].action= {|view|
	if(view.value==1, {
		sendOsc.value([]);
	});
};
externalButtons[6].action= {|view|
	if(view.value==1, {
		sendOsc.value([]);
	});
};
)