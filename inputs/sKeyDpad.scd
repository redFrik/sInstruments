//f.olofsson 2019

//arduino nano with keydpad.ino

(
//--settings
var serialPortName= "/dev/cu.wchusbserial14[0-9]*0";  //regexp
var winRect= Rect(170, 70, 160, 150);  //x, y, w, h
var palette= SGUI.palette;
var fnt= SGUI.font;
var fntMono= Font.monospace(10);
var recTimeout= 3;  //number of seconds to keep snapshot record gate open

//--functions and objects
var sendOsc;
var routine;
var lookup= #[6, 7, 4, 10, 11, 13, 3, 2, 12, 9, 8, 0, 1, 5];
var snapshotKeys= #[
	[$A, $S, $D, $F, $G, $H, $J, $K],
	[$Z, $X, $C, $V, $B, $N, $M, $,]
];
var bankKeys= #[  //more can be added
	$1, $2, $3, $4, $5, $6, $7, $8, $9
];

//--gui
var snapshotButtons= List.new;
var bankButtons= List.new;
var recButton;
var shiftButton;
var infoTextString;
var win= Window("sKeyDpad", winRect);
win.layout= VLayout(
	GridLayout.rows(
		*snapshotKeys[0].clump(4).collect{|arr|
			arr.collect{|chr|
				snapshotButtons.add(Button().states_([
					[chr, palette.window, Color.black],
					[chr, palette.window, palette.highlight]
				]).fixedWidth_(25)).last;
			};
		}
	),
	HLayout(
		*bankKeys.clump(4)[0].postln.collect{|chr|
			bankButtons.add(Button().states_([
				[chr, palette.window, Color.red],
				[chr, palette.window, palette.highlight]
			]).fixedWidth_(25)).last;
		};
	),
	HLayout(
		View(),
		recButton= Button().states_([
			["rec", palette.buttonText, Color.red],
			["rec", palette.button, Color.red]
		]).fixedWidth_(30),
		shiftButton= Button().states_([
			["shift", palette.buttonText, Color.red],
			["shift", palette.button, Color.red]
		]).fixedWidth_(30),
		View()
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
		SInputs.destinations[a[0]].sendMsg(a[1], *a[2..]);
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
							var val;
							8.do{|i|
								val= (lo&(1<<i)>0).not.binaryValue;
								if(snapshotButtons[lookup[i]].value!=val, {
									snapshotButtons[lookup[i]].valueAction= val;
								});
							};
							4.do{|i|
								val= (hi&(1<<i)>0).not.binaryValue;
								if(bankButtons[lookup[i+8]].value!=val, {
									bankButtons[lookup[i+8]].valueAction= val;
								});
							};
							val= (hi&(1<<4)>0).not.binaryValue;
							if(recButton[lookup[4+8]].value!=val, {
								recButton[lookup[4+8]].valueAction= val;
							});
							val= (hi&(1<<5)>0).not.binaryValue;
							if(shiftButton[lookup[5+8]].value!=val, {
								shiftButton[lookup[5+8]].valueAction= val;
							});
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
snapshotButtons.do{|but, i|
	but.action= {|view|
		if(view.value==1, {
			sendOsc.value([
				[\sStream, \snapshots, snapshotKeys[shiftButton.value][i].asString, recButton.value]
			]);
			{view.value= 0}.defer(0.15);
		});
	};
};

bankButtons.do{|but, i|
	but.action= {|view|
		if(view.value==1, {
			sendOsc.value([
				[\sStream, \snapshots, bankKeys[i].asString]
			]);
			{view.value= 0}.defer(0.15);
		});
	};
};

recButton.action= {|view|
	{view.value= 0}.defer(recTimeout);
};

shiftButton.action= {|view|
	snapshotButtons.do{|but, i|
		but.states= [
			[snapshotKeys[shiftButton.value][i], palette.window, Color.black],
			[snapshotKeys[shiftButton.value][i], palette.window, palette.highlight]
		];
	};
};
)
