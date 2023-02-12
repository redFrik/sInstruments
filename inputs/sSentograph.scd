//f.olofsson 2019

//two 3d sensors with optoforceOsc2.py

(
//--settings
var winRect= Rect(0, 80, 320, 400);  //x, y, w, h
var palette= SGUI.palette;
var fnt= Font.monospace(10);
var fps= 15;  //maximum gui updaterate - does not affect sensor input rate

//--functions and objects
var on1= true, on2= true;
var sendFromSentograph1, sendFromSentograph2;
var calibrateSentograph;
var calibration;
var readCalibrationFromDisk, writeUserCalibrationToDisk;
var xyz1raw= [0, 0, 0];
var xyz2raw= [0, 0, 0];
var setupOscResponders, oscResponders;
var sendOsc;
var routineGui;

//--gui
var calibrateWin;
var onButton1, calButton1;
var xyz1Elements= {SGUIelement()}!3;
var onButton2, calButton2;
var xyz2Elements= {SGUIelement()}!3;
var infoTextElementString= SGUIelementString();
var win= Window("sSentograph", winRect);
win.layout= VLayout(
	HLayout(
		VLayout(
			HLayout(
				onButton1= Button().states_([
					["  Sentograph 1", palette.buttonText, palette.button],
					["•Sentograph 1", palette.buttonText, palette.highlight]
				]).fixedWidth_(100),
				(calButton1= SGUIsettings()).view
			),
			GridLayout.rows(
				["X", "Y", "Z"].collect{|str, i|
					VLayout(
						[StaticText().string_(str), align:\center],
						xyz1Elements[i].addView(Slider().orientation_(\vertical))
					)
				}
			)
		),
		View().fixedWidth_(15),
		VLayout(
			HLayout(
				onButton2= Button().states_([
					["  Sentograph 2", palette.buttonText, palette.button],
					["•Sentograph 2", palette.buttonText, palette.highlight]
				]).fixedWidth_(100),
				(calButton2= SGUIsettings()).view
			),
			GridLayout.rows(
				["X", "Y", "Z"].collect{|str, i|
					VLayout(
						[StaticText().string_(str), align:\center],
						xyz2Elements[i].addView(Slider().orientation_(\vertical))
					)
				}
			)
		)
	),
	StaticText().string_("Input Recorder"),  //TODO
	HLayout(
		Button().states_([["Record"]]),
		Button().states_([["Play"]]),
		PopUpMenu().items_(["_"]),
	),
	infoTextElementString.addView(StaticText().fixedHeight_(" ".bounds(fnt).height*4)
		.align_(\topLeft).background_(Color.grey(0.9, 0.5))),
	View()
);
win.onClose= {
	NetAddr.localAddr.sendMsg(\closed, \sSentograph);
	routineGui.stop;
	oscResponders.do{|x| x.free};
	if(calibrateWin.notNil, {calibrateWin.close});
};

onButton1.value= on1.binaryValue;
onButton1.action= {|view|
	on1= view.value.booleanValue;
};
calButton1.action= {calibrateSentograph.value(1)};
onButton2.value= on2.binaryValue;
onButton2.action= {|view|
	on2= view.value.booleanValue;
};
calButton2.action= {calibrateSentograph.value(0)};


xyz1Elements[0].action= {|val|
	sendOsc.value([
		[\sCluster, \ampLfoDepth, (val-0.5*3).abs],
		[\sDrone, \efxDec, 0, val-0.5],
		[\sGliss, \ampLfoRateAdd, (val-0.5).abs*2],
		[\sStream, \x, val]
	]);
};
xyz1Elements[1].action= {|val|
	sendOsc.value([
		[\sCluster, \freqLfoDepth, (val-0.5*3).abs],
		[\sDrone, \freqLfoDepth, (val-0.5*3).abs],
		[\sStream, \y, val]
	]);
};
xyz1Elements[2].action= {|val|
	sendOsc.value([
		[\sDrone, \efxDel, val],
		[\sGliss, \freqLfoRateAdd, val],
		[\sStream, \z, val]
	]);
};

xyz2Elements[0].action= {|val|
	var bal= val.linlin(0, 1, -0.6, 0.6);
	sendOsc.value([
		[\sDrone, \mainBalance, bal],
		[\sFormant, \fundFreq, val],
		[\sFormant, \x, val-0.5],
		[\sFormant, \mainBalance, bal],
		[\sGliss, \mainBalance, bal]
	]);
};
xyz2Elements[1].action= {|val|
	sendOsc.value([
		[\sDrone, \distortion, 0, val-0.5*1.5],
		[\sFormant, \formFreq, val],
		[\sFormant, \y, val-0.5]
	]);
};
xyz2Elements[2].action= {|val|
	sendOsc.value([
		[\sCluster, \amp, val],
		[\sDrone, \amp, val],
		[\sFormant, \amp, val],
		[\sGliss, \amp, val]
	]);
};

setupOscResponders= {
	oscResponders= [

		//--from optoforceOsc2.py
		OSCFunc({|msg, time|
			//TODO smoothing?
			if(on1 and:{msg[1]==1}, {  //Sentograph 1
				xyz1raw[0]= msg[2];
				xyz1raw[1]= msg[3];
				xyz1raw[2]= msg[4];
				xyz1Elements[0].value= (msg[2]+calibration[1][2]).lincurve(calibration[1][0], calibration[1][1], 0, 1, calibration[1][3]);
				xyz1Elements[1].value= (msg[3]+calibration[1][6]).lincurve(calibration[1][4], calibration[1][5], 0, 1, calibration[1][7]);
				xyz1Elements[2].value= (msg[4]+calibration[1][10]).min(0).lincurve(calibration[1][8], calibration[1][9], 1, 0, calibration[1][11]);
			}, {
				if(on2 and:{msg[1]==0}, {  //Sentograph 2
					xyz2raw[0]= msg[2];
					xyz2raw[1]= msg[3];
					xyz2raw[2]= msg[4];
					xyz2Elements[0].value= (msg[2]+calibration[0][2]).lincurve(calibration[0][0], calibration[0][1], 0, 1, calibration[0][3]);
					xyz2Elements[1].value= (msg[3]+calibration[0][6]).lincurve(calibration[0][4], calibration[0][5], 0, 1, calibration[0][7]);
					xyz2Elements[2].value= (msg[4]+calibration[0][10]).min(0).lincurve(calibration[0][8], calibration[0][9], 1, 0, calibration[0][11]);
				});
			});
		}, \optoforce, recvPort:SInputs.destinations.sSentograph.port);
	];
};
setupOscResponders.value;

sendOsc= {|arr|
	var str= "";
	arr.do{|a|
		SInputs.destinations[a[0]].sendMsg(*a[1..]);
		str= str++a.collect{|x| if(x.isFloat, {SGUI.fixDec(x, 2)}, {x})};
	};
	infoTextElementString.value= str.replace("[ ", "[").replace(" ]", "] ").replace(",", "");
};

readCalibrationFromDisk= {|path|
	var cal;
	if(File.exists(path), {
		try{
			cal= path.parseYAMLFile;
			calibration= cal.collect{|dict|
				[
					dict["xmin"],
					dict["xmax"],
					dict["xoff"],
					dict["xcurv"],
					dict["ymin"],
					dict["ymax"],
					dict["yoff"],
					dict["ycurv"],
					dict["zmin"],
					dict["zmax"],
					dict["zoff"],
					dict["zcurv"]
				].asInteger;
			};
		};
	});
};
writeUserCalibrationToDisk= {  //(re)write all user patterns to disk
	File.use(SInstruments.dataDir+/+"sSentograph_calibrationUSER.json", "w", {|file|
		file.write("[");
		calibration.do{|arr, i|
			file.write("\n\t{");
			file.write("\n\t\t'xmin': %,".format(arr[0]));
			file.write("\n\t\t'xmax': %,".format(arr[1]));
			file.write("\n\t\t'xoff': %,".format(arr[2]));
			file.write("\n\t\t'xcurv': %,".format(arr[3]));
			file.write("\n\t\t'ymin': %,".format(arr[4]));
			file.write("\n\t\t'ymax': %,".format(arr[5]));
			file.write("\n\t\t'yoff': %,".format(arr[6]));
			file.write("\n\t\t'ycurv': %,".format(arr[7]));
			file.write("\n\t\t'zmin': %,".format(arr[8]));
			file.write("\n\t\t'zmax': %,".format(arr[9]));
			file.write("\n\t\t'zoff': %,".format(arr[10]));
			file.write("\n\t\t'zcurv': %,".format(arr[11]));
			file.write("\n\t}");
		};
		file.write("\n]");
	});
};
readCalibrationFromDisk.value(SInstruments.dataDir+/+"sSentograph_calibration.json");
readCalibrationFromDisk.value(SInstruments.dataDir+/+"sSentograph_calibrationUSER.json");

calibrateSentograph= {|index|
	var updateCalibrationNumbers;
	var calibrateRoutineGui;
	var resetButton;
	var xSpec= ControlSpec(-4500, 4500, 'lin', 0, 0);  //TODO check for real min and max
	var ySpec= ControlSpec(-4500, 4500, 'lin', 0, 0);
	var zSpec= ControlSpec(-9000, 0, 'lin', 0, 0);
	var xNumberElement= SGUIelement();
	var yNumberElement= SGUIelement();
	var zNumberElement= SGUIelement();
	var xLeftButton, xLeftNumber;
	var xRightButton, xRightNumber;
	var yTopButton, yTopNumber;
	var yBottomButton, yBottomNumber;
	var zLightestButton, zLightestNumber;
	var zHardestButton, zHardestNumber;
	var noTouchButton, noTouchXNumber, noTouchYNumber, noTouchZNumber;
	var xCurvUsr, xCurvSlider, xCurvSpec;
	var yCurvUsr, yCurvSlider, yCurvSpec;
	var zCurvUsr, zCurvSlider, zCurvSpec;
	var storeButton, closeButton;
	if(calibrateWin.notNil, {calibrateWin.close});
	calibrateWin= Window("calibrateSentograph", Rect(400, 100, 480, 480));
	calibrateWin.layout= VLayout(
		HLayout(
			StaticText().string_("Sentograph"+index),
			nil,
			resetButton= Button().states_([["Reset to defaults"]])
		),
		GridLayout.rows(
			[
				View(),
				[StaticText().string_("X"), align:\center],
				[StaticText().string_("Y"), align:\center],
				[StaticText().string_("Z"), align:\center]
			],
			[
				View(),
				xNumberElement.addView(NumberBox(), xSpec),
				yNumberElement.addView(NumberBox(), ySpec),
				zNumberElement.addView(NumberBox(), zSpec)
			],
			[
				View(),
				View(),
				View(),
				View()
			],
			[
				xLeftButton= Button().states_([["X left"]]),
				xLeftNumber= NumberBox(),
				View(),
				View()
			],
			[
				xRightButton= Button().states_([["X right"]]),
				xRightNumber= NumberBox(),
				View(),
				View()
			],
			[
				yTopButton= Button().states_([["Y top"]]),
				View(),
				yTopNumber= NumberBox(),
				View()
			],
			[
				yBottomButton= Button().states_([["Y bottom"]]),
				View(),
				yBottomNumber= NumberBox(),
				View()
			],
			[
				zLightestButton= Button().states_([["Z lightest touch"]]),
				View(),
				View(),
				zLightestNumber= NumberBox()
			],
			[
				zHardestButton= Button().states_([["Z hardest possible"]]),
				View(),
				View(),
				zHardestNumber= NumberBox()
			],
			[
				noTouchButton= Button().states_([["No touch"]]),
				noTouchXNumber= NumberBox(),
				noTouchYNumber= NumberBox(),
				noTouchZNumber= NumberBox()
			],
			[
				View(),
				View(),
				View(),
				View()
			],
			[
				StaticText().string_("Curvatures"),
				HLayout(
					xCurvSlider= Slider().orientation_(\vertical).maxSize_(22@100),
					xCurvUsr= UserView().fixedSize_(Size(67, 67))
				),
				HLayout(
					yCurvSlider= Slider().orientation_(\vertical).maxSize_(22@100),
					yCurvUsr= UserView().fixedSize_(Size(67, 67))
				),
				HLayout(
					zCurvSlider= Slider().orientation_(\vertical).maxSize_(22@100),
					zCurvUsr= UserView().fixedSize_(Size(67, 67))
				)
			]
		),
		View(),
		View(),
		HLayout(
			View(),
			storeButton= Button().states_([["Store"]]),
			closeButton= Button().states_([["Close"]])
		)
	);
	SGUI.adapt(calibrateWin);
	if(SGUI.currentTheme!=\dark, {
		calibrateWin.view.children.select{|v| v.isKindOf(Slider)}.do{|v|
			v.background= Color.grey(0.7725, 0.5);
		};
	});
	calibrateWin.front;
	CmdPeriod.doOnce({calibrateWin.close});
	calibrateWin.view.keyDownAction= {|view, chr, mod, unicode, keycode, key|
		if(unicode==27, {calibrateWin.close});  //esc
	};
	calibrateWin.onClose= {
		calibrateRoutineGui.stop;
	};

	xCurvSpec= ControlSpec(-20, 20, 'lin', 0, 0);
	yCurvSpec= ControlSpec(-20, 20, 'lin', 0, 0);
	zCurvSpec= ControlSpec(-20, 20, 'lin', 0, 0);
	updateCalibrationNumbers= {
		xLeftNumber.value= calibration[index][0];  //xmin
		xRightNumber.value= calibration[index][1];  //xmax
		yTopNumber.value= calibration[index][4];  //ymin
		yBottomNumber.value= calibration[index][5];  //ymax
		zLightestNumber.value= calibration[index][9];  //zmax
		zHardestNumber.value= calibration[index][8];  //zmin
		noTouchXNumber.value= calibration[index][2];  //xoff
		noTouchYNumber.value= calibration[index][6];  //yoff
		noTouchZNumber.value= calibration[index][10];  //zoff
		xCurvSlider.value= xCurvSpec.unmap(calibration[index][3]);  //xcurv
		yCurvSlider.value= yCurvSpec.unmap(calibration[index][7]);  //ycurv
		zCurvSlider.value= zCurvSpec.unmap(calibration[index][11]);  //zcurv
		xCurvUsr.refresh;
		yCurvUsr.refresh;
		zCurvUsr.refresh;
	};
	updateCalibrationNumbers.value;

	resetButton.action= {|view|
		readCalibrationFromDisk.value(SInstruments.dataDir+/+"sSentograph_calibration.json");
		updateCalibrationNumbers.value;
	};
	xLeftNumber.action= {|view|
		calibration[index][0]= view.value;
	};
	xRightNumber.action= {|view|
		calibration[index][1]= view.value;
	};
	yTopNumber.action= {|view|
		calibration[index][4]= view.value;
	};
	yBottomNumber.action= {|view|
		calibration[index][5]= view.value;
	};
	zLightestButton.action= {|view|
		zLightestNumber.valueAction= [xyz2raw, xyz1raw][index][2];
	};
	zLightestNumber.action= {|view|
		calibration[index][9]= view.value;
	};
	zHardestButton.action= {|view|
		zHardestNumber.valueAction= [xyz2raw, xyz1raw][index][2];
	};
	zHardestNumber.action= {|view|
		calibration[index][8]= view.value.postln;
	};
	noTouchButton.action= {|view|
		noTouchXNumber.valueAction= [xyz2raw, xyz1raw][index][0];
		noTouchYNumber.valueAction= [xyz2raw, xyz1raw][index][1];
		noTouchZNumber.valueAction= [xyz2raw, xyz1raw][index][2];
	};
	noTouchXNumber.action= {|view|
		calibration[index][2]= view.value;
	};
	noTouchYNumber.action= {|view|
		calibration[index][6]= view.value;
	};
	noTouchZNumber.action= {|view|
		calibration[index][10]= view.value;
	};

	xCurvUsr.background= Color.clear;
	xCurvUsr.drawFunc= {|usr|
		var uw= usr.bounds.width;
		var uh= usr.bounds.height;
		var cur= xCurvSpec.map(xCurvSlider.value);
		Pen.strokeColor= palette.buttonText;
		a= (0..99)/99;
		if(cur!=0, {
			~func= {|t, a= 15| atan((t-0.5)*a)/(2*atan(0.5*a))+0.5};
		}, {
			~func= {|t, a= 15| t};
		});
		a.do{|val, i|
			var x= i.linlin(0, a.size-1, 0, uw);
			var y= ~func.value(val, cur).linlin(0, 1, uh-1, 1);
			if(i==0, {
				Pen.moveTo(Point(0, y));
			}, {
				Pen.lineTo(Point(x, y));
			});
		};
		Pen.stroke;
	};
	xCurvSlider.action= {|view|
		xCurvUsr.refresh;
	};

	yCurvUsr.background= Color.clear;
	yCurvUsr.drawFunc= {|usr|
		var uw= usr.bounds.width;
		var uh= usr.bounds.height;
		var cur= yCurvSpec.map(yCurvSlider.value);
		Pen.strokeColor= palette.buttonText;
		a= (0..99)/99;
		if(cur!=0, {
			~func= {|t, a= 15| atan((t-0.5)*a)/(2*atan(0.5*a))+0.5};
		}, {
			~func= {|t, a= 15| t};
		});
		a.do{|val, i|
			var x= i.linlin(0, a.size-1, 0, uw);
			var y= ~func.value(val, cur).linlin(0, 1, uh-1, 1);
			if(i==0, {
				Pen.moveTo(Point(0, y));
			}, {
				Pen.lineTo(Point(x, y));
			});
		};
		Pen.stroke;
	};
	yCurvSlider.action= {|view|
		yCurvUsr.refresh;
	};

	zCurvUsr.background= Color.clear;
	zCurvUsr.drawFunc= {|usr|
		var uw= usr.bounds.width;
		var uh= usr.bounds.height;
		var cur= zCurvSpec.map(zCurvSlider.value);
		Pen.strokeColor= palette.buttonText;
		a= (0..99)/99;
		if(cur!=0, {
			~func= {|t, a= 15| atan((t-0.5)*a)/(2*atan(0.5*a))+0.5};
		}, {
			~func= {|t, a= 15| t};
		});
		a.do{|val, i|
			var x= i.linlin(0, a.size-1, 0, uw);
			var y= ~func.value(val, cur).linlin(0, 1, uh-1, 1);
			if(i==0, {
				Pen.moveTo(Point(0, y));
			}, {
				Pen.lineTo(Point(x, y));
			});
		};
		Pen.stroke;
	};
	zCurvSlider.action= {|view|
		zCurvUsr.refresh;
	};

	storeButton.action= {
		SGUIdialogWindow({
			writeUserCalibrationToDisk.value;
			calibrateWin.close;
		});
	};
	closeButton.action= {
		calibrateWin.close;
	};
	calibrateRoutineGui.stop;
	calibrateRoutineGui= Routine({
		inf.do{
			/*xNumberElement.value= [xyz2Elements[0], xyz1Elements[0]][index].value;  //TODO show also calibrated values with sliders?
			yNumberElement.value= [xyz2Elements[1], xyz1Elements[1]][index].value;
			zNumberElement.value= [xyz2Elements[2], xyz1Elements[2]][index].value;*/
			xNumberElement.value= xSpec.unmap([xyz2raw[0], xyz1raw[0]][index].value);
			yNumberElement.value= ySpec.unmap([xyz2raw[1], xyz1raw[1]][index].value);
			zNumberElement.value= zSpec.unmap([xyz2raw[2], xyz1raw[2]][index].value);
			xNumberElement.update;
			yNumberElement.update;
			zNumberElement.update;
			fps.reciprocal.wait;
		}
	}).play(AppClock);
};

routineGui= Routine({
	inf.do{
		xyz1Elements.do{|e| e.update};
		xyz2Elements.do{|e| e.update};
		infoTextElementString.update;
		fps.reciprocal.wait;
	}
}).play(AppClock);
SGUI.report(win);
SGUI.adapt(win);
infoTextElementString.views.do{|view| view.font= fnt};
if(SGUI.currentTheme!=\dark, {
	win.view.children.select{|v| v.isKindOf(Slider)}.do{|v|
		v.background= Color.grey(0.7725, 0.5);
	};
});
win.front;
)
