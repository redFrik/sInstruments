//f.olofsson 2019

//arduino nano with keydpad.ino

(
//--settings
var serialPortName= "/dev/cu.wchusbserial14[0-9]*0";  //regexp
var winRect= Rect(170, 70, 150, 150);  //x, y, w, h
var palette= SGUI.palette;
var fnt= SGUI.font;
var fntMono= Font.monospace(10);

//--functions and objects
var sendOsc;
var routine;
var plate= #[
	[0, 1, 2, 3],  //row1-black
	[4, 5, 6, 7],  //row2-black
	[8, 9, 10, 11],  //row3-red
	[nil, 12, 13, nil]  //row3-red
];

//--gui
var plateButtons= List.new;
var infoTextString;
var win= Window("sKeyDpad", winRect);
win.layout= VLayout(
	GridLayout.rows(
		*plate.collect{|arr|
			arr.collect{|number|
				if(number.notNil, {
					plateButtons.add(Button().states_([
						[number, palette.buttonText, palette.button],
						[number, palette.buttonText, palette.highlight]
					]).fixedWidth_(25)).last;
				}, {
					View()
				});
			};
		}
	),
	infoTextString= StaticText().fixedHeight_(" ".bounds(fntMono).height*2)
	.align_(\topLeft).background_(Color.grey(0.9, 0.5))
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
						if(str.contains("sKeyDpad\r\n"), {
							timer= 0;
							portFound= true;
							"sKeyDpad found at %".format(path).postln;
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
		"sKeyDpad serial port not found".postln;
	}, {
		if(portFound.not, {
			"sKeyDpad serial port not responding".postln;
		}, {

			//--start reading from found port
			"sKeyDpad connected".postln;
			infoTextString.string= "connected!";
			routine= Routine.run({
				var state= 0;
				var lo, hi;
				inf.do{
					var byte= port.read;
					case
					{state==0 and:{byte==253}} {
						state= 1;
					}
					{state==1 and:{byte==254}} {
						state= 2;
					}
					{state==2} {
						lo= byte;
						state= 3;
					}
					{state==3} {
						hi= byte;
						state= 4;
					}
					{state==4 and:{byte==255}} {
						//[lo, hi].postln;  //debug
						{
							8.do{|i|
								var val= (lo&(1<<i)>0).not.binaryValue;
								if(plateButtons[i].value!=val, {
									plateButtons[i].valueAction= val;
								});
							};
							6.do{|i|
								var val= (hi&(1<<i)>0).not.binaryValue;
								if(plateButtons[i+8].value!=val, {
									plateButtons[i+8].valueAction= val;
								});
							};
						}.defer;
						state= 0;
					} {
						state= 0;
					};
				};
			});
			CmdPeriod.doOnce({
				port.close;
			});
		});
	});
	win.onClose= {
		NetAddr.localAddr.sendMsg(\closed, \sKeyDpad);
		routine.stop;
		if(port.notNil, {
			port.close;
		});
	};
}).play(AppClock);

//--button functions

//--row1-back
plateButtons[0].action= {|view|
	if(view.value==1, {
		sendOsc.value([[\sStream, \on, 1]]);  //example
	});
};
plateButtons[1].action= {|view|
	if(view.value==1, {
		sendOsc.value([]);
	});
};
plateButtons[2].action= {|view|
	if(view.value==1, {
		sendOsc.value([]);
	});
};
plateButtons[3].action= {|view|
	if(view.value==1, {
		sendOsc.value([]);
	});
};

//--row2-back
plateButtons[4].action= {|view|
	if(view.value==1, {
		sendOsc.value([]);
	});
};
plateButtons[5].action= {|view|
	if(view.value==1, {
		sendOsc.value([]);
	});
};
plateButtons[6].action= {|view|
	if(view.value==1, {
		sendOsc.value([]);
	});
};
plateButtons[7].action= {|view|
	if(view.value==1, {
		sendOsc.value([]);
	});
};

//--row3-red
plateButtons[8].action= {|view|
	if(view.value==1, {
		sendOsc.value([]);
	});
};
plateButtons[9].action= {|view|
	if(view.value==1, {
		sendOsc.value([]);
	});
};
plateButtons[10].action= {|view|
	if(view.value==1, {
		sendOsc.value([]);
	});
};
plateButtons[11].action= {|view|
	if(view.value==1, {
		sendOsc.value([]);
	});
};

//--row4-red
plateButtons[12].action= {|view|
	if(view.value==1, {
		sendOsc.value([]);
	});
};
plateButtons[13].action= {|view|
	if(view.value==1, {
		sendOsc.value([]);
	});
};

)
