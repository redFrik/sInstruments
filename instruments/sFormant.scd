//f.olofsson 2019
//based on optoformant3

(
//--settings
var oscPort= SInputs.destinations.sFormant.port;
var winRect= Rect(242, 242, 600, 600);  //x, y, w, h
var palette= SGUI.palette((highlight: Color.grey(2/3, 0.5)));
var fps= 25;  //maximum gui updaterate - does not affect sensor input rate
var minFreq= 5, maxFreq= 500;  //Hz
var snapshotKeys= #[  //more can be added
	[$A, $S, $D, $F, $G, $H, $J, $K],
	[$Z, $X, $C, $V, $B, $N, $M, $,]
];
var bankKeys= #[  //more can be added
	$1, $2, $3, $4, $5, $6, $7, $8, $9
];
var snapshotFiles= [  //name and file (both can be changed)
	\Bank1 -> "sFormant_snapshots_Bank1.scd",
	\Bank2 -> "sFormant_snapshots_Bank2.scd",
	\Bank3 -> "sFormant_snapshots_Bank3.scd",
	\Bank4 -> "sFormant_snapshots_Bank4.scd",
	\Bank5 -> "sFormant_snapshots_Bank5.scd",
	\Bank6 -> "sFormant_snapshots_Bank6.scd",
	\Bank7 -> "sFormant_snapshots_Bank7.scd",
	\Bank8 -> "sFormant_snapshots_Bank8.scd",
	\Bank9 -> "sFormant_snapshots_Bank9.scd"
];

//--defaults
var defaultAmplitudes= #[0.5, 0.5];
var defaultFrequencies= #[50, 99];  //Hz
var defaultAttack= 4;
var defaultRelease= 4;
var defaultMainVolume= 0.0;  //dB

s.options.numWireBufs= s.options.numWireBufs.max(128);
s.options.memSize= s.options.memSize.max(2**16);
s.latency= 0.08;
s.waitForBoot{

	//--functions and objects
	var formant, createFormant;
	var setupOscResponders, oscResponders;
	var routineGui;

	//--gui
	var ampHiElement= SGUIelement();
	var ampHiSpec= ControlSpec(0, 1, 3, 0, defaultAmplitudes[0]);
	var ampLoElement= SGUIelement();
	var ampLoSpec= ControlSpec(0, 1, 3, 0, defaultAmplitudes[1]);
	var ampAddElement= SGUIelement();
	var ampAddSpec= ControlSpec(0, 1, 'lin', 0, 0);
	var fundFreqElement= SGUIelement();
	var fundFreqSpec= ControlSpec(minFreq, maxFreq, 'exp', 0, defaultFrequencies[0]);
	var fundOffsetElement= SGUIelement();
	var fundOffsetSpec= ControlSpec(0, 1000, 3, 0, 50);
	var detuneElement= SGUIelement();
	var detuneSpec= ControlSpec(0, 2.5, 3, 0, 0);
	var formFreqElement= SGUIelement();
	var formFreqSpec= ControlSpec(minFreq, maxFreq, 'exp', 0, defaultFrequencies[1]);
	var formOffsetElement= SGUIelement();
	var formOffsetSpec= ControlSpec(0, 1000, 3, 0, 50);
	var lagUpElement= SGUIelement();
	var lagUpSpec= ControlSpec(0.025, 10, 3, 0, 0.001);
	var lagDownElement= SGUIelement();
	var lagDownSpec= ControlSpec(0.025, 10, 3, 0, 0.01);
	var onElement= SGUIelement();
	var attackElement= SGUIelement();
	var attackSpec= ControlSpec(0, 99, 'lin', 0.1, defaultAttack, "s");
	var releaseElement= SGUIelement();
	var releaseSpec= ControlSpec(0, 99, 'lin', 0.1, defaultRelease, "s");
	var xElement= SGUIelement();
	var xSpec= ControlSpec(-511.5, 511.5, 'lin', 0, 0);
	var yElement= SGUIelement();
	var ySpec= ControlSpec(0, 511.5, 'lin', 0, 0);
	var yScaleElement= SGUIelement();
	var yScaleSpec= ControlSpec(1, 3, 3, 0, 1);
	var snapshots;
	var mainBalanceElement= SGUIelement();
	var mainVolume;
	var mainReverbElement= SGUIelement();
	var mainRecord;
	var backgroundImage;
	var win= Window("sFormant", winRect);
	win.layout= HLayout(

		VLayout(

			//--amplitude control section
			StaticText().string_("Amplitude control"),
			VLayout(
				HLayout(
					StaticText().string_("AmpHi").fixedWidth_(50),
					[ampHiElement.addView(Slider().orientation_(\horizontal)), stretch:1],
					ampHiElement.addView(NumberBox().decimals_(3), ampHiSpec)
				),
				HLayout(
					StaticText().string_("AmpLo").fixedWidth_(50),
					[ampLoElement.addView(Slider().orientation_(\horizontal)), stretch:1],
					ampLoElement.addView(NumberBox().decimals_(3), ampLoSpec)
				),
				HLayout(
					StaticText().string_("AmpAdd").fixedWidth_(50),
					[ampAddElement.addView(Slider().orientation_(\horizontal)), stretch:1],
					ampAddElement.addView(NumberBox().decimals_(3), ampAddSpec)
				)
			),

			//--frequency control section
			StaticText().string_("Frequency control"),
			HLayout(
				StaticText().string_("Detune").fixedWidth_(50),
				[detuneElement.addView(Slider().orientation_(\horizontal)), stretch:1],
				detuneElement.addView(NumberBox().decimals_(3), detuneSpec)
			),
			GridLayout.rows(
				[
					[StaticText().string_("FundFreq"), align:\center],
					[StaticText().string_("FundOffset"), align:\center],
					[StaticText().string_("FormFreq"), align:\center],
					[StaticText().string_("FormOffset"), align:\center]
				],
				[
					fundFreqElement.addView(Slider().orientation_(\vertical)),
					fundOffsetElement.addView(Slider().orientation_(\vertical)),
					formFreqElement.addView(Slider().orientation_(\vertical)),
					formOffsetElement.addView(Slider().orientation_(\vertical))
				],
				[
					fundFreqElement.addView(NumberBox(), fundFreqSpec),
					fundOffsetElement.addView(NumberBox(), fundOffsetSpec),
					formFreqElement.addView(NumberBox(), formFreqSpec),
					formOffsetElement.addView(NumberBox(), formOffsetSpec)
				]
			),
			HLayout(
				StaticText().string_("GlissUp").fixedWidth_(60),
				[lagUpElement.addView(Slider().orientation_(\horizontal)), stretch:1],
				lagUpElement.addView(NumberBox().decimals_(3), lagUpSpec)
			),
			HLayout(
				StaticText().string_("GlissDown").fixedWidth_(60),
				[lagDownElement.addView(Slider().orientation_(\horizontal)), stretch:1],
				lagDownElement.addView(NumberBox().decimals_(3), lagDownSpec)
			)
		),

		VLayout(

			//--synth section
			onElement.addView(Button().states_([
				["Formant Off", palette.buttonText, palette.button],
				["Formant On", palette.buttonText, palette.highlight]
			])),
			HLayout(
				SGUI.shrink(StaticText().string_("Attack")),
				[attackElement.addView(NumberBox().scroll_step_(0.1).decimals_(3), attackSpec), align:\left],
				SGUI.shrink(StaticText().string_("Release")),
				[releaseElement.addView(NumberBox().scroll_step_(0.1).decimals_(3), releaseSpec), align:\left]
			),
			HLayout(
				SGUI.shrink(StaticText().string_("X")),
				[xElement.addView(Slider().orientation_(\horizontal)), stretch:1],
				xElement.addView(NumberBox().decimals_(3), xSpec)
			),
			HLayout(
				SGUI.shrink(StaticText().string_("Y")),
				[yElement.addView(Slider().orientation_(\horizontal)), stretch:1],
				yElement.addView(NumberBox().decimals_(3), ySpec)
			),
			HLayout(
				SGUI.shrink(StaticText().string_("YScale")),
				[yScaleElement.addView(Slider().orientation_(\horizontal)), stretch:1],
				yScaleElement.addView(NumberBox().decimals_(3), yScaleSpec)
			),

			//--presets section
			View(),
			(
				snapshots= SGUIsnapshots(SInstruments.snapshotsDir, snapshotFiles, bankKeys, snapshotKeys, \sFormant)
			).view,

			//--output section
			View(),
			StaticText().string_("Output"),
			HLayout(
				StaticText().string_("Balance").fixedWidth_(45),
				mainBalanceElement.addView(Slider().orientation_(\horizontal))
			),
			(mainVolume= SGUIvolume()).view,
			HLayout(
				StaticText().string_("Reverb").fixedWidth_(45),
				mainReverbElement.addView(Slider().orientation_(\horizontal))
			),
			HLayout(
				SGUIcpu(s).view,
				(mainRecord= SGUIrecord(s, SInstruments.recordingsDir, "sFormant_")).view
			)
		)
	);
	backgroundImage= Image(500, 500).draw({|img|
		Pen.width= 5;
		200.do{|i|
			if(i%3==0, {
				Pen.strokeColor= Color.white;
			}, {
				Pen.strokeColor= palette.highlight.complementary;
			});
			Pen.strokeOval(Rect(i*14%500-25, i*13%500-25, i+5, i+5));
		};
	});
	win.view.setBackgroundImage(backgroundImage, 10, 0.15);
	if(SGUI.currentTheme!=\dark, {
		win.view.children.select{|v| v.isKindOf(Slider)}.do{|v|
			v.background= Color.grey(0.7725, 0.5);
		};
	});
	win.view.keyDownAction= {|view, chr, mod, unicode, keycode, key|
		if(unicode==13, {
			win.view.focus;
		}, {
			if(chr==Char.space, {
				onElement.valueAction= 1-onElement.value;
			}, {
				snapshots.keyDownAction(chr, mod);
			});
		});
	};
	win.onClose= {
		NetAddr.localAddr.sendMsg(\closed, \sFormant);
		routineGui.stop;
		oscResponders.do{|x| x.free};
		formant.release(1)
	};
	CmdPeriod.doOnce({
		formant.free;
		formant= nil;
	});


	ampHiElement.action= {|val|
		formant.setAmplitudes([ampHiSpec.map(val), ampLoSpec.map(ampLoElement.value)]);
	};
	ampLoElement.action= {|val|
		formant.setAmplitudes([ampHiSpec.map(ampHiElement.value), ampLoSpec.map(val)]);
	};
	ampAddElement.action= {|val|
		formant.set(\ampAdd, ampAddSpec.map(val));
	};

	detuneElement.action= {|val|
		formant.set(\detune, detuneSpec.map(val));
	};

	fundFreqElement.action= {|val|
		formant.setFrequencies([fundFreqSpec.map(val), formFreqSpec.map(formFreqElement.value)]);
	};
	fundOffsetElement.action= {|val|
		formant.set(\fundOffset, fundOffsetSpec.map(val));
	};

	formFreqElement.action= {|val|
		formant.setFrequencies([fundFreqSpec.map(fundFreqElement.value), formFreqSpec.map(val)]);
	};
	formOffsetElement.action= {|val|
		formant.set(\formOffset, formOffsetSpec.map(val));
	};

	lagUpElement.action= {|val|
		formant.set(\lagUp, lagUpSpec.map(val));
	};
	lagDownElement.action= {|val|
		formant.set(\lagDown, lagDownSpec.map(val));
	};


	onElement.action= {|val|
		formant.set(\on, val);
		SInputs.destinations.sKeyDpad.sendMsg(\iOnOff, \sFormant, val.asInteger);
	};
	attackElement.value= attackSpec.unmap(defaultAttack);
	attackElement.action= {|val|
		formant.set(\atk, attackSpec.map(val));
	};
	releaseElement.value= releaseSpec.unmap(defaultRelease);
	releaseElement.action= {|val|
		formant.set(\rel, releaseSpec.map(val));
	};

	xElement.action= {|val|
		formant.set(\x, xSpec.map(val));
	};
	yElement.action= {|val|
		formant.set(\y, ySpec.map(val));
	};
	yScaleElement.action= {|val|
		formant.set(\yScale, yScaleSpec.map(val));
	};

	snapshots.recallFunctions= (
		snapshotInstrument: {},
		snapshotVersion: {},
		//any other key will default to view.valueAction= assoc.value
	);
	snapshots.include= [  //order is important
		snapshotInstrument: \sFormant,
		snapshotVersion: 1.1,
		ampHiElement: ampHiElement,
		ampLoElement: ampLoElement,
		ampAddElement: ampAddElement,
		detuneElement: detuneElement,
		fundFreqElement: fundFreqElement,
		fundOffsetElement: fundOffsetElement,
		formFreqElement: formFreqElement,
		formOffsetElement: formOffsetElement,
		lagUpElement: lagUpElement,
		lagDownElement: lagDownElement,
		onElement: onElement,
		attackElement: attackElement,
		releaseElement: releaseElement,
		xElement: xElement,
		yElement: yElement,
		yScaleElement: yScaleElement,
		mainBalanceElement: mainBalanceElement,
		mainVolume: mainVolume,
		mainReverbElement: mainReverbElement
	];

	mainBalanceElement.value= 0.5;
	mainBalanceElement.action= {|val|
		formant.set(\pan, val*2-1);
	};

	mainVolume.action= {|val|
		formant.set(\vol, val);
	};

	mainReverbElement.action= {|val|
		formant.set(\verb, val.lincurve(0, 1, 0, 0.5, 3));
	};


	//--network
	setupOscResponders= {
		oscResponders= [

			//--from sKeyBpad and sQWERTYKeyboard
			OSCFunc({|msg|
				{win.view.keyDownAction.value(win.view, msg[1].asAscii, 0)}.defer;
			}, \keyboard, recvPort:oscPort),

			//--from sKeyCpad
			OSCFunc({|msg| onElement.valueAction= 1-onElement.value}, \on, recvPort:oscPort),

			//--from sKeyDpad
			OSCFunc({|msg| onElement.valueAction= msg[1]}, \onOff, recvPort:oscPort),

			//--from sNanokontrol
			OSCFunc({|msg| ampHiElement.value= msg[1]}, \ampHi, recvPort:oscPort),
			OSCFunc({|msg| ampLoElement.value= msg[1]}, \ampLo, recvPort:oscPort),
			OSCFunc({|msg| detuneElement.value= msg[1]}, \detune, recvPort:oscPort),
			OSCFunc({|msg| fundOffsetElement.value= msg[1]}, \fundOffset, recvPort:oscPort),
			OSCFunc({|msg| formOffsetElement.value= msg[1]}, \formOffset, recvPort:oscPort),
			OSCFunc({|msg| lagUpElement.value= msg[1]}, \lagUp, recvPort:oscPort),
			OSCFunc({|msg| lagDownElement.value= msg[1]}, \lagDown, recvPort:oscPort),
			OSCFunc({|msg| yScaleElement.value= msg[1]}, \yScale, recvPort:oscPort),
			OSCFunc({|msg| {mainVolume.valueAction= msg[1]}.defer}, \mainVolume, recvPort:oscPort),
			OSCFunc({|msg| mainReverbElement.value= msg[1]}, \mainReverb, recvPort:oscPort),
			OSCFunc({|msg| {mainRecord.valueAction= 1-mainRecord.value}.defer}, \mainRecord, recvPort:oscPort),

			//--from sSentograph
			OSCFunc({|msg| ampAddElement.value= msg[1]}, \amp, recvPort:oscPort),
			OSCFunc({|msg| fundFreqElement.value= msg[1]}, \fundFreq, recvPort:oscPort),
			OSCFunc({|msg| formFreqElement.value= msg[1]}, \formFreq, recvPort:oscPort),
			OSCFunc({|msg| xElement.value= msg[1]/2+0.5}, \x, recvPort:oscPort),
			OSCFunc({|msg| yElement.value= msg[1].max(0)}, \y, recvPort:oscPort),
			OSCFunc({|msg| mainBalanceElement.value= msg[1]+1/2}, \mainBalance, recvPort:oscPort),

			//--other/unused
			OSCFunc({|msg| attackElement.value= msg[1]}, \attack, recvPort:oscPort),
			OSCFunc({|msg| releaseElement.value= msg[1]}, \release, recvPort:oscPort),
		];
	};


	//--formant
	createFormant= {
		var args= [
			\on, onElement.value,
			\atk, attackSpec.map(attackElement.value),
			\rel, releaseSpec.map(releaseElement.value),
			\frequencies, defaultFrequencies,
			\amplitudes, defaultAmplitudes
		];
		//"_________".postln; args.pairsDo{|a, b| [a, b].postln};  //debug
		SFormant(args: args);
	};
	formant= createFormant.value;

	{
		ampHiElement.value= ampHiSpec.unmap(ampHiSpec.default);
		ampLoElement.value= ampLoSpec.unmap(ampLoSpec.default);
		ampAddElement.value= ampAddSpec.unmap(ampAddSpec.default);
		detuneElement.value= detuneSpec.unmap(detuneSpec.default);
		fundFreqElement.value= fundFreqSpec.unmap(fundFreqSpec.default);
		fundOffsetElement.value= fundOffsetSpec.unmap(fundOffsetSpec.default);
		formFreqElement.value= formFreqSpec.unmap(formFreqSpec.default);
		formOffsetElement.value= formOffsetSpec.unmap(formOffsetSpec.default);
		lagUpElement.value= lagUpSpec.unmap(lagUpSpec.default);
		lagDownElement.value= lagDownSpec.unmap(lagDownSpec.default);
		xElement.value= xSpec.unmap(xSpec.default);
		yElement.value= ySpec.unmap(ySpec.default);
		yScaleElement.value= yScaleSpec.unmap(yScaleSpec.default);
		mainVolume.valueAction= defaultMainVolume;
		setupOscResponders.value;
		routineGui= Routine({
			inf.do{
				ampHiElement.update;
				ampLoElement.update;
				ampAddElement.update;
				detuneElement.update;
				fundFreqElement.update;
				fundOffsetElement.update;
				formFreqElement.update;
				formOffsetElement.update;
				lagUpElement.update;
				lagDownElement.update;
				xElement.update;
				yElement.update;
				yScaleElement.update;
				onElement.update;
				attackElement.update;
				releaseElement.update;
				mainBalanceElement.update;
				mainReverbElement.update;
				fps.reciprocal.wait;
			}
		}).play(AppClock);
		SGUI.report(win);
		SGUI.adapt(win);
		win.front;
	}.defer(1);
};
)
