//f.olofsson 2019

//arduino nano with sKeyDpad-firmware.ino

(
//--settings
var oscPort= SInputs.destinations.sKeyDpad.port;
var serialPortNames= [
	"/dev/tty.usbserial-[0-9]*",
	"/dev/cu.wchusbserial[0-9]*",
];  //regexp
var winRect= Rect(800, 320, 160, 300);  //x, y, w, h
var palette= SGUI.palette;
var fnt= Font.monospace(10);

//--functions and objects
var sendOsc;
var routine;
var setupOscResponders, oscResponders;
var iOnOffDict= (), activeDict;

//--gui
var blackButtons= List.new;
var redButtons= List.new;
var recButton;
var onoffButton;
var infoTextString;
var win= Window("sKeyDpad", winRect);
win.layout= VLayout(
	GridLayout.rows(
		*{{
			blackButtons.add(Button().states_([
				["", palette.window, Color.black],
				["", palette.window, palette.highlight]
			]).fixedWidth_(25)).last;
		}.dup(4)}.dup(2)
	),
	HLayout(
		*{
			redButtons.add(Button().states_([
				["", palette.window, Color.red],
				["", palette.window, palette.highlight]
			]).fixedWidth_(25)).last;
		}.dup(4)
	),
	HLayout(
		nil,
		(recButton= SGUIrecord(s, SInstruments.recordingsDir, "sInstrument_")).view
		.states_([
			["rec", palette.buttonText, Color.red],
			["rec", palette.button, Color.red]
		]).fixedWidth_(30),
		onoffButton= Button().states_([
			["on", palette.buttonText, Color.red],
			["off", palette.button, Color.red]
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

sendOsc= {|arr|
	var str= "";
	arr.do{|a|
		var addr= SInputs.destinations[a[0]];
		if(addr.notNil, {
			addr.sendMsg(a[1], *a[2..]);
			str= str++a;
		});
	};
	infoTextString.string= str.replace("[ ", "[").replace(" ]", "] ").replace(", ", " ");
};

//--
Routine({
	var port, portFound= false;

	//--try multiple ports if many with similar name
	SerialPort.devices.select{|path|
		serialPortNames.any{|name| name.matchRegexp(path)}
	}.do{|path|
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
							if(hi.bitTest(3).not, {blackButtons[0].valueAction= 1-blackButtons[0].value});
							if(hi.bitTest(4).not, {blackButtons[1].valueAction= 1-blackButtons[1].value});
							if(lo.bitTest(7).not, {blackButtons[2].valueAction= 1-blackButtons[2].value});
							if(lo.bitTest(6).not, {blackButtons[3].valueAction= 1-blackButtons[3].value});
							if(lo.bitTest(2).not, {blackButtons[4].valueAction= 1-blackButtons[4].value});
							if(hi.bitTest(5).not, {blackButtons[5].valueAction= 1-blackButtons[5].value});
							if(lo.bitTest(0).not, {blackButtons[6].valueAction= 1-blackButtons[6].value});
							if(lo.bitTest(1).not, {blackButtons[7].valueAction= 1-blackButtons[7].value});

							if(hi.bitTest(2).not, {redButtons[0].valueAction= 1-redButtons[0].value});
							if(hi.bitTest(1).not, {redButtons[1].valueAction= 1-redButtons[1].value});
							if(lo.bitTest(3).not, {redButtons[2].valueAction= 1-redButtons[2].value});
							if(lo.bitTest(4).not, {redButtons[3].valueAction= 1-redButtons[3].value});

							if(hi.bitTest(0).not, {recButton.valueAction= 1-recButton.value});
							if(lo.bitTest(5).not, {onoffButton.valueAction= 1-onoffButton.value});
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
		oscResponders.do{|x| x.free};
	};
}).play(AppClock);

//--button functions
blackButtons.do{|but, i|
	but.action= {|view|
		if(view.value==1, {
			sendOsc.value([
				[\sOBS, \scene, i+1],
			]);
			{view.value= 0}.defer(0.15);
		});
	};
};

redButtons.do{|but, i|
	but.action= {|view|
		if(view.value==1, {
			infoTextString.string= "not connected";
			{view.value= 0}.defer(0.15);
		});
	};
};

onoffButton.action= {|view|
	if(view.value==1, {  //off
		activeDict= ();
		iOnOffDict.keysValuesDo{|k, v|
			if(v==1, {activeDict.put(k, 1)});
		};
		sendOsc.value(SInstruments.instruments.collect{|name| [name, \onOff, 1-view.value]});
	}, {
		if(activeDict.keys.size>0, {
			sendOsc.value([activeDict.keys.asArray, \onOff, 1].flop);
		});
	});
};

//--network
setupOscResponders= {
	oscResponders= [
		OSCFunc({|msg|
			iOnOffDict.put(msg[1], msg[2]);
		}, \iOnOff, recvPort:oscPort),
	]
};
setupOscResponders.value;
)
