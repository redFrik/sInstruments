//f.olofsson 2019

//arduino nano with sKeyDpad-firmware.ino

(
//--settings
var serialPortName= "/dev/cu.wchusbserial14[0-9]*0";  //regexp
var winRect= Rect(170, 70, 160, 150);  //x, y, w, h
var palette= SGUI.palette;
var fnt= Font.monospace(10);
var recTimeout= 3;  //number of seconds to keep snapshot record gate open

//--functions and objects
var sendOsc;
var routine;
var buttonLookup;
var lookup= #[6, 7, 4, 10, 11, 13, 3, 2, 12, 9, 8, 0, 1, 5];
var snapshotKeys= #[
	[$A, $S, $D, $F, $G, $H, $J, $K],
	[$Z, $X, $C, $V, $B, $N, $M, $,]
];
var bankKeys= #[  //more can be added
	$1, $2, $3, $4, $5, $6, $7, $8, $9
];
var switches= [0, 0, 0, 0];

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
		*bankKeys.clump(4)[0].collect{|chr|
			bankButtons.add(Button().states_([
				[chr, palette.window, Color.red],
				[chr, palette.window, palette.highlight]
			]).fixedWidth_(25)).last;
		};
	),
	HLayout(
		nil,
		recButton= Button().states_([
			["rec", palette.buttonText, Color.red],
			["rec", palette.button, Color.red]
		]).fixedWidth_(30),
		shiftButton= Button().states_([
			["shift", palette.buttonText, Color.red],
			["shift", palette.button, Color.red]
		]).fixedWidth_(30),
		nil
	),
	infoTextString= StaticText().fixedHeight_(" ".bounds(fnt).height*6)
	.align_(\topLeft).background_(Color.grey(0.9, 0.5))
);
SGUI.report(win);
SGUI.adapt(win);
win.front;
infoTextString.font= fnt;

buttonLookup= {|index|
	var i= lookup[index];
	case
	{i<snapshotButtons.size} {snapshotButtons[i]}
	{i<(snapshotButtons.size+bankButtons.size)} {bankButtons[i-snapshotButtons.size]}
	{i==12} {recButton}
	{i==13} {shiftButton}
};

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
							var but, val;
							8.do{|i|
								but= buttonLookup.value(i);
								val= (lo&(1<<i)>0).not.binaryValue;
								if(but.value!=val, {but.valueAction= val});
							};
							4.do{|i|
								but= buttonLookup.value(i+8);
								val= (hi&(1<<i)>0).not.binaryValue;
								if(but.value!=val, {but.valueAction= val});
							};
							but= buttonLookup.value(8+4);
							val= (hi&(1<<4)>0).not.binaryValue;
							if(but.value!=val, {but.valueAction= val});
							but= buttonLookup.value(8+5);
							val= (hi&(1<<5)>0).not.binaryValue;
							if(but.value!=val, {but.valueAction= val});
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
		var row;
		if(view.value==1, {
			sendOsc.value([
				[\sCluster, \snapshots, bankKeys.last.asString],
				[\sDrone, \snapshots, bankKeys.last.asString],
				[\sGliss, \snapshots, bankKeys.last.asString]
			]);
			row= switches[i%4]+i.div(4)%2;
			sendOsc.value([
				[\sCluster, \snapshots, snapshotKeys[row][i%4].asString, 0],
				[\sDrone, \snapshots, snapshotKeys[row][i%4].asString, 0],
				[\sGliss, \snapshots, snapshotKeys[row][i%4].asString, 0],
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
				[\sCluster, \snapshots, bankKeys.last.asString],
				[\sDrone, \snapshots, bankKeys.last.asString],
				[\sGliss, \snapshots, bankKeys.last.asString]
			]);
			sendOsc.value([
				[\sCluster, \snapshots, snapshotKeys[switches[i]][i].asString, 1],
				[\sDrone, \snapshots, snapshotKeys[switches[i]][i].asString, 1],
				[\sGliss, \snapshots, snapshotKeys[switches[i]][i].asString, 1],
				[\sStream, \snapshots, bankKeys[i].asString]
			]);
			switches.put(i, 1-switches[i]);
			{view.value= 0}.defer(0.15);
		});
	};
};

recButton.action= {|view|
	sendOsc.value([
		[\sCluster, \mainRecord],
		[\sDrone, \mainRecord],
		[\sGliss, \mainRecord]
	]);
	{view.value= 0}.defer(recTimeout);
};

shiftButton.action= {|view|
	snapshotButtons.do{|but, i|
		but.states= [
			[snapshotKeys[shiftButton.value][i], palette.window, Color.black],
			[snapshotKeys[shiftButton.value][i], palette.window, palette.highlight]
		];
	};
	sendOsc.value([
		[\sCluster, \onOff, 0],
		[\sDrone, \onOff, 0],
		[\sGliss, \onOff, 0]
	]);
};
)
