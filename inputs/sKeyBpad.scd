//f.olofsson 2019

//arduino nano with sKeyBpad-firmware.ino

(
//--settings
var serialPortNames= [
	"/dev/tty.usbserial-[0-9]*",
	"/dev/cu.wchusbserial[0-9]*",
];  //regexp
var winRect= Rect(397, 270, 400, 200);  //x, y, w, h
var palette= SGUI.palette;
var fnt= Font.monospace(10);

//--functions and objects
var sendOsc;
var routine;
var buttonLookup= #[
	[64, 65, 66, 58, 50, 40, 41, 32, 33, 34],
	[68, 67, 63, 59, 54, 44, 43, 42, 39, 00],  //button on chip input 35 is missing so no 19
	[69, 62, 60, 61, 52, 45, 46, 36, 37, 38],
	[70, 71, 57, 56, 49, 48, 47, 53, 55, 51]
];

//--gui
var buttons= List.new;
var infoTextString;
var win= Window("sKeyBpad", winRect);
win.layout= VLayout(
	*({|i|
		HLayout(
			*({|j|
				buttons.add(Button().states_([
					[39-(i*10+j), palette.buttonText, palette.button],
					[39-(i*10+j), palette.buttonText, palette.highlight]
				]).fixedWidth_(25)).last;
			}!10);
		)
	}!4)
	++
	infoTextString= StaticText().fixedHeight_(" ".bounds(fnt).height*2)
	.align_(\topLeft).background_(Color.grey(0.9, 0.5))
);
SGUI.report(win);
SGUI.adapt(win);
win.front;
infoTextString.font= fnt;

buttons= buttons.reverse;
sendOsc= {|arr|
	var str= "";
	arr.do{|a|
		SInputs.destinations[a[0]].sendMsg(a[1], a[2].ascii);
		str= str++a;
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
						if(str.contains("sKeyBpad\r\n"), {
							timer= 0;
							portFound= true;
							"sKeyBpad found at %".format(path).postln;
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
		"sKeyBpad serial port not found".postln;
	}, {
		if(portFound.not, {
			"sKeyBpad serial port not responding".postln;
		}, {

			//--start reading from found port
			"sKeyBpad connected".postln;
			infoTextString.string= "connected!";
			routine= Routine.run({
				inf.do{|i|
					var cnt= 0, val, index;
					var byte= port.read;
					//32-71= button 1 to 40 down, 72-111= button 1 to 40 up
					if(byte>=72, {  //button down
						val= 1;
						byte= byte-40;
					}, {  //button up
						val= 0;
					});
					while({cnt<40}, {
						if(buttonLookup[cnt.div(10)][cnt%10]==byte, {
							index= cnt;
							cnt= 999;
						}, {
							cnt= cnt+1;
						});
					});
					//[byte, index, val].postln;  //debug
					if(index!=19, {  //mute 19 because chip input is broken
						{buttons[index].valueAction= val}.defer;
					});
				};
			});
			CmdPeriod.doOnce({
				port.close;
			});
		});
	});
	win.onClose= {
		NetAddr.localAddr.sendMsg(\closed, \sKeyBpad);
		routine.stop;
		if(port.notNil, {
			port.close;
		});
	};
}).play(AppClock);

buttons[0].action= {|view|
	if(view.value==1, {
		sendOsc.value([]);
	});
};
buttons[1].action= {|view|
	if(view.value==1, {
		sendOsc.value([]);
	});
};
[$,, $m, $n, $b, $v, $c, $x, $z].do{|chr, i|  //2-9
	buttons[i+2].action= {|view|
		if(view.value==1, {
			sendOsc.value([
				[\sCluster, \keyboard, chr],
				[\sDrone, \keyboard, chr],
				[\sFormant, \keyboard, chr],
				[\sGliss, \keyboard, chr],
				[\sStream, \keyboard, chr]
			]);
		});
	};
};
buttons[10].action= {|view|
	if(view.value==1, {
		sendOsc.value([]);
	});
};
[$k, $j, $h, $g, $f, $d, $s, $a].do{|chr, i|  //11-18
	buttons[i+11].action= {|view|
		if(view.value==1, {
			sendOsc.value([
				[\sCluster, \keyboard, chr],
				[\sDrone, \keyboard, chr],
				[\sFormant, \keyboard, chr],
				[\sGliss, \keyboard, chr],
				[\sStream, \keyboard, chr]
			]);
		});
	};
};
//number 19 broken
buttons[19].action= {|view|
	if(view.value==1, {
		sendOsc.value([]);
	});
};
[$p, $o, $i, $u, $y, $t, $r, $e, $w, $q].do{|chr, i|  //20-29
	buttons[i+20].action= {|view|
		if(view.value==1, {
			sendOsc.value([
				[\sCluster, \keyboard, chr],
				[\sDrone, \keyboard, chr],
				[\sFormant, \keyboard, chr],
				[\sGliss, \keyboard, chr],
				[\sStream, \keyboard, chr]
			]);
		});
	};
};
buttons[30].action= {|view|
	if(view.value==1, {
		sendOsc.value([]);
	});
};
[$9, $8, $7, $6, $5, $4, $3, $2, $1].do{|chr, i|  //31-39
	buttons[i+31].action= {|view|
		if(view.value==1, {
			sendOsc.value([
				[\sCluster, \keyboard, chr],
				[\sDrone, \keyboard, chr],
				[\sFormant, \keyboard, chr],
				[\sGliss, \keyboard, chr],
				[\sStream, \keyboard, chr]
			]);
		});
	};
};
)
