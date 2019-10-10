//f.olofsson 2019

(
//--settings
var oscPort= 13061;
var maxNumVoices= 30;  //maximum number of voices for the synth
var winRect= Rect(242, 242, 900, 780);  //x, y, w, h
var palette= SGUI.palette((highlight: Color.red(2/3, 0.5)));
var fnt= SGUI.font;
var fnt2= SGUI.font.copy.size_(10);
var fps= 25;
var minFreq= 20, maxFreq= 12000;  //Hz
var glag= 1;  //global control lag for dist, hp, dmin etc
var transposeKeys= #[
	$Q, $W, $E, $R, $T, $Y, $U, $I, $O, $P, $Å, $^  //last two hardcoded in class
];
var snapshotKeys= #[  //more can be added
	[$A, $S, $D, $F, $G, $H, $J, $K],
	[$Z, $X, $C, $V, $B, $N, $M, $,]
];
var bankKeys= #[  //more can be added
	$1, $2, $3, $4, $5, $6, $7, $8, $9
];
var snapshotFiles= [  //name and file (both can be changed)
	\Bank1 -> "sDrone_snapshots_Bank1.scd",
	\Bank2 -> "sDrone_snapshots_Bank2.scd",
	\Bank3 -> "sDrone_snapshots_Bank3.scd",
	\Bank4 -> "sDrone_snapshots_Bank4.scd",
	\Bank5 -> "sDrone_snapshots_Bank5.scd",
	\Bank6 -> "sDrone_snapshots_Bank6.scd",
	\Bank7 -> "sDrone_snapshots_Bank7.scd",
	\Bank8 -> "sDrone_snapshots_Bank8.scd",
	\Bank9 -> "sDrone_snapshots_Bank9.scd"
];

//--defaults
var defaultNumVoices= 5;  //number of green circles
var defaultAttack= 0.1;
var defaultRelease= 3;
var defaultAmplitudes= 0.25!defaultNumVoices;
var defaultFrequencies= 99!defaultNumVoices;  //Hz
var defaultAmpRange= #[0, 0.75];  //minmax percent
var defaultAmpLfoDepth= 0;  //percent
var defaultAmpLfoRate= 0.01;  //Hz
var defaultFreqRange= #[0.05, 0.95];  //minmax percent
var defaultFreqLfoDepth= 0.01;
var defaultFreqLfoSpread= 0.1;
var defaultFreqLfoRate= 50;  //Hz
var defaultFreqGlissTime= 3;  //seconds
var defaultMainVolume= 0.0;  //dB

s.options.numWireBufs= s.options.numWireBufs.max(128);
s.options.memSize= s.options.memSize.max(2**16);
s.latency= 0.08;
s.waitForBoot{

	//--functions and objects
	var soundfiles= SoundFile.collect(SInstruments.soundfilesDir+/+"*");
	var folders= (SInstruments.soundfilesDir+/+"*").pathMatch.select{|x| PathName(x).isFolder};
	var soundfolders= folders.collect{|f| (path: f, soundfiles: SoundFile.collect(f+/+"*"))};
	var buffer, fileIndex, loadBuffer;
	var typeFromPopup, itemFromPopup, filePathFromPopup, filePathInFolderFromPopup;
	var drone, createDrone;
	var usrPadding= Size(25, 20);
	var ampTargets= {|i|
		(
			position: Point(0, defaultAmplitudes.wrapAt(i)),  //coordinates
			amplitude: defaultAmplitudes.wrapAt(i).linlin(*[defaultAmpRange, 0, 1].flat)
		)
	}!maxNumVoices;
	var ampSelectFunc;
	var ampClosestTarget, ampUpdate, ampTask;
	var ampLinesA= {0.5+0.5.linrand}!20, ampLinesB= {0.5-0.5.linrand}!20, ampClosestLine;
	var ampLinesAY, ampLinesBY, ampLinesFunc, ampLinesCursor= 0;
	var freqTargets= {|i|
		(
			position: Point(0, 0),  //coordinates
			frequency: defaultFrequencies.wrapAt(i).explin(*[defaultFreqRange.linexp(0, 1, minFreq, maxFreq), 0, 1].flat)
		)
	}!maxNumVoices;
	var freqSelectFunc;
	var freqClosestTarget, freqUpdate, freqTask;
	var freqLinesA= {0.5+0.5.linrand}!20, freqLinesB= {0.5-0.5.linrand}!20, freqClosestLine;
	var freqLinesAY, freqLinesBY, freqLinesFunc, freqLinesCursor= 0;
	var efxDecA, efxDecB;
	var distortionA, distortionB;
	var setupOscResponders, oscResponders;
	var routineGui;
	var sDrone_bus;
	var mainOutSyn;

	//--gui
	var ampSelectButtons, ampStack;
	var ampRangeElement= SGUIelementRange();
	var ampRandProbElement= SGUIelement();
	var ampRandRateElement= SGUIelement();
	var ampRandRateSpec= ControlSpec(0.05, 5, 'lin', 0, 2);
	var ampRampFreqElement= SGUIelement();
	var ampRampFreqSpec= ControlSpec(-1, 1, 'lin', 0, -0.01);
	var ampRampRateElement= SGUIelement();
	var ampRampRateSpec= ControlSpec(0.001, 1, 'lin', 0, 0.15);
	var ampRampCurvElement= SGUIelement();
	var ampRampCurvSpec= ControlSpec(-8, 8, 'lin', 0, 0);
	var ampWaveFreqElement= SGUIelement();
	var ampWaveFreqSpec= ControlSpec(-1, 1, 'lin', 0, 0.02);
	var ampWaveRateElement= SGUIelement();
	var ampWaveRateSpec= ControlSpec(0.001, 1, 'lin', 0, 0.15);
	var ampWaveCurvElement= SGUIelement();
	var ampWaveCurvSpec= ControlSpec(-8, 8, 'lin', 0, 0);
	var ampLinesButtonLeft, ampLinesButtonRight, ampLinesPopup;
	var ampUsr, ampUsrAnim, ampUserView;
	var ampLfoDepthElement= SGUIelement();
	var ampLfoDepthSpec= ControlSpec(0, 100, 'lin', 1, defaultAmpLfoDepth, "%");
	var ampLfoRateElement= SGUIelement();
	var ampLfoRateSpec= ControlSpec(0.005, 5, 'exp', 0, defaultAmpLfoRate, "Hz");
	var freqSelectButtons, freqStack;
	var freqRangeElement= SGUIelementRange();
	var freqRangeSpec= ControlSpec(minFreq, maxFreq, 'exp', 0, 99, "Hz");
	var freqGlissButton, freqXFadeButton;
	var freqRandRateElement= SGUIelement();
	var freqRandRateSpec= ControlSpec(0.05, 5, 'lin', 0, 1);
	var freqRandProbElement= SGUIelement();
	var freqRampFreqElement= SGUIelement();
	var freqRampFreqSpec= ControlSpec(-1, 1, 'lin', 0, -0.01);
	var freqRampRateElement= SGUIelement();
	var freqRampRateSpec= ControlSpec(0.001, 1, 'lin', 0, 0.15);
	var freqRampCurvElement= SGUIelement();
	var freqRampCurvSpec= ControlSpec(-8, 8, 'lin', 0, 0);
	var freqWaveFreqElement= SGUIelement();
	var freqWaveFreqSpec= ControlSpec(0.01, 1, 'lin', 0, 0.002);
	var freqWaveRateElement= SGUIelement();
	var freqWaveRateSpec= ControlSpec(0.001, 1, 'lin', 0, 0.25);
	var freqWaveCurvElement= SGUIelement();
	var freqWaveCurvSpec= ControlSpec(-8, 8, 'lin', 0, 0);
	var freqLinesButtonLeft, freqLinesButtonRight, freqLinesPopup;
	var freqUsr, freqUsrAnim, freqUserView;
	var freqLfoDepthElement= SGUIelement();
	var freqLfoDepthSpec= ControlSpec(0.01, 1, 'exp', 0, defaultFreqLfoDepth);
	var freqLfoSpreadElement= SGUIelement();
	var freqLfoSpreadSpec= ControlSpec(0.01, 50, 'exp', 0, defaultFreqLfoSpread);
	var freqLfoRateElement= SGUIelement();
	var freqLfoRateSpec= ControlSpec(0.05, 500, 'exp', 0, defaultFreqLfoRate, "Hz");
	var scalesTunings;
	var curvature;
	var masterTuning;
	var glissTime;
	var numVoicesNumber, droneButton, attackNumber, releaseNumber;
	var typePopup;
	var nextButton, randButton, lockButton;
	var distortionSlider;
	var efxHPNumber, efxHPSpec, efxHPSlider;
	var efxLPNumber, efxLPSpec, efxLPSlider;
	var efxDelSlider, efxDelSpec;
	var efxDecNumber, efxDecSpec, efxDecSlider;
	var transposition;
	var snapshots;
	var mainBalanceElement= SGUIelement();
	var mainVolume;
	var mainReverbElement= SGUIelement();
	var mainRecord;
	var backgroundImage;
	var win= Window("sDrone", winRect);
	win.layout= HLayout(

		VLayout(

			//--amplitude control section
			HLayout(
				StaticText().string_("Amplitude control").fixedWidth_(120),
				*ampSelectButtons= #["targets", "random", "ramp", "wave", "lines"].collect{|x|
					Button().states_([
						["  "++x, palette.buttonText, palette.button],
						["•"++x, palette.buttonText, palette.highlight]
					])
				}
			),
			HLayout(
				ampStack= StackLayout(
					View().layout_(HLayout(  //targets
						View().fixedHeight_(18)
					)),
					View().layout_(HLayout(  //random
						StaticText().string_("Probability"),
						ampRandProbElement.addView(Slider().orientation_(\horizontal)),
						StaticText().string_("Rate"),
						ampRandRateElement.addView(NumberBox().decimals_(2).scroll_step_(0.01), ampRandRateSpec)
					)),
					View().layout_(HLayout(  //ramp
						StaticText().string_("Freq"),
						ampRampFreqElement.addView(NumberBox().decimals_(3).scroll_step_(0.001), ampRampFreqSpec),
						StaticText().string_("Rate"),
						ampRampRateElement.addView(NumberBox().decimals_(3).scroll_step_(0.001), ampRampRateSpec),
						StaticText().string_("Curve"),
						ampRampCurvElement.addView(NumberBox().scroll_step_(0.1), ampRampCurvSpec)
					)),
					View().layout_(HLayout(  //wave
						StaticText().string_("Freq"),
						ampWaveFreqElement.addView(NumberBox().decimals_(3).scroll_step_(0.001), ampWaveFreqSpec),
						StaticText().string_("Rate"),
						ampWaveRateElement.addView(NumberBox().decimals_(3).scroll_step_(0.001), ampWaveRateSpec),
						StaticText().string_("Curve"),
						ampWaveCurvElement.addView(NumberBox().scroll_step_(0.1), ampWaveCurvSpec)
					)),
					View().layout_(HLayout(  //lines
						ampLinesButtonLeft= Button().states_([
							["<", palette.buttonText, palette.button],
							["<", palette.buttonText, palette.highlight]
						]).maxWidth_(50),
						ampLinesButtonRight= Button().states_([
							[">", palette.buttonText, palette.button],
							[">", palette.buttonText, palette.highlight]
						]).maxWidth_(50),
						ampLinesPopup= PopUpMenu().items_(#[
							"loop off", "loop on", "loop palindrome",
							"random direction", "random jump", "sync freq",
							"scratch"
						])
					))
				)
			),
			HLayout(
				VLayout(
					View().fixedSize_(15@5),
					ampRangeElement.addView(RangeSlider().orientation_(\vertical).minSize_(15@80)),
					View().fixedSize_(15@5)
				),
				[StackLayout(
					ampUsr= UserView().minSize_(500@100),
					ampUsrAnim= UserView().minSize_(500@100)
				).mode_(\stackAll), stretch:1]
			),
			HLayout(
				StaticText().string_("Amp.LFO Depth").fixedWidth_(100),
				ampLfoDepthElement.addView(Slider().orientation_(\horizontal)),
				ampLfoDepthElement.addView(NumberBox().step_(1).fixedWidth_(50), ampLfoDepthSpec),
				StaticText().string_("%").fixedWidth_(20)
			),
			HLayout(
				StaticText().string_("Amp.LFO Rate").fixedWidth_(100),
				ampLfoRateElement.addView(Slider().orientation_(\horizontal)),
				ampLfoRateElement.addView(NumberBox().decimals_(3).fixedWidth_(50), ampLfoRateSpec),
				StaticText().string_("Hz").fixedWidth_(20)
			),

			View().fixedHeight_(10),  //spacing

			//--frequency control section
			HLayout(
				StaticText().string_("Frequency control").fixedWidth_(120),
				*freqSelectButtons= #["targets", "random", "ramp", "wave", "lines"].collect{|x|
					Button().states_([
						["  "++x, palette.buttonText, palette.button],
						["•"++x, palette.buttonText, palette.highlight]
					])
				},
			),
			HLayout(
				freqStack= StackLayout(
					View().layout_(HLayout(  //targets
						freqGlissButton= Button().states_([
							["  Gliss", palette.buttonText, palette.button],
							["•Gliss", palette.buttonText, palette.highlight]
						]),
						freqXFadeButton= Button().states_([
							["XFade", palette.buttonText, palette.button]
						]),
						View()
					)),
					View().layout_(HLayout(  //random
						StaticText().string_("Probability"),
						freqRandProbElement.addView(Slider().orientation_(\horizontal)),
						StaticText().string_("Rate"),
						freqRandRateElement.addView(NumberBox().decimals_(2).scroll_step_(0.01), freqRandRateSpec)
					)),
					View().layout_(HLayout(  //ramp
						StaticText().string_("Freq"),
						freqRampFreqElement.addView(NumberBox().decimals_(3).scroll_step_(0.001), freqRampFreqSpec),
						StaticText().string_("Rate"),
						freqRampRateElement.addView(NumberBox().decimals_(3).scroll_step_(0.001), freqRampRateSpec),
						StaticText().string_("Curve"),
						freqRampCurvElement.addView(NumberBox().scroll_step_(0.1), freqRampCurvSpec)
					)),
					View().layout_(HLayout(  //wave
						StaticText().string_("Freq"),
						freqWaveFreqElement.addView(NumberBox().decimals_(3).scroll_step_(0.001), freqWaveFreqSpec),
						StaticText().string_("Rate"),
						freqWaveRateElement.addView(NumberBox().decimals_(3).scroll_step_(0.001), freqWaveRateSpec),
						StaticText().string_("Curve"),
						freqWaveCurvElement.addView(NumberBox().scroll_step_(0.1), freqWaveCurvSpec)
					)),
					View().layout_(HLayout(  //lines
						freqLinesButtonLeft= Button().states_([
							["<", palette.buttonText, palette.button],
							["<", palette.buttonText, palette.highlight]
						]).maxWidth_(50),
						freqLinesButtonRight= Button().states_([
							[">", palette.buttonText, palette.button],
							[">", palette.buttonText, palette.highlight]
						]).maxWidth_(50),
						freqLinesPopup= PopUpMenu().items_(#[
							"loop off", "loop on", "loop palindrome",
							"random direction", "random jump", "sync amp",
							"scratch"
						])
					))
				)
			),
			HLayout(
				VLayout(
					View().fixedSize_(15@5),
					freqRangeElement.addView(RangeSlider().orientation_(\vertical).minSize_(15@180)),
					View().fixedSize_(15@5)
				),
				[StackLayout(
					freqUsr= UserView().minSize_(500@200),
					freqUsrAnim= UserView().minSize_(500@200)
				).mode_(\stackAll), stretch:1]
			),
			HLayout(
				StaticText().string_("Fre.LFO Depth").fixedWidth_(100),
				freqLfoDepthElement.addView(Slider().orientation_(\horizontal)),
				freqLfoDepthElement.addView(NumberBox().decimals_(3).fixedWidth_(50), freqLfoDepthSpec),
				View().fixedWidth_(20)
			),
			HLayout(
				StaticText().string_("Fre.LFO Spread").fixedWidth_(100),
				freqLfoSpreadElement.addView(Slider().orientation_(\horizontal)),
				freqLfoSpreadElement.addView(NumberBox().decimals_(3).fixedWidth_(50), freqLfoSpreadSpec),
				View().fixedWidth_(20)
			),
			HLayout(
				StaticText().string_("Fre.LFO Rate").fixedWidth_(100),
				freqLfoRateElement.addView(Slider().orientation_(\horizontal)),
				freqLfoRateElement.addView(NumberBox().decimals_(3).fixedWidth_(50), freqLfoRateSpec),
				StaticText().string_("Hz").fixedWidth_(20)
			),
			HLayout(
				(scalesTunings= SGUIscalesTunings().fixedHeight_(125)).view,
				VLayout(
					(curvature= SGUIcurvature()).view,
					(masterTuning= SGUImasterTuning()).view
				)
			),
			(glissTime= SGUIglissTime(defaultFreqGlissTime)).view
		),

		VLayout(

			//--synth section
			HLayout(
				SGUI.shrink(StaticText().string_("Number of Voices")),
				numVoicesNumber= NumberBox().scroll_(false).step_(1)
			),
			droneButton= Button().states_([
				["Drone Off", palette.buttonText, palette.button],
				["Drone On", palette.buttonText, palette.highlight]
			]),
			HLayout(
				SGUI.shrink(StaticText().string_("Attack")),
				attackNumber= NumberBox().scroll_step_(0.1),
				SGUI.shrink(StaticText().string_("Release")),
				releaseNumber= NumberBox().scroll_step_(0.1)
			),
			HLayout(
				StaticText().string_("Synth").fixedWidth_(60),
				[typePopup= PopUpMenu(), align:\left],
				nextButton= Button().states_([["next"]]).fixedWidth_(30),
				randButton= Button().states_([["rand"]]).fixedWidth_(30),
				lockButton= Button().states_([
					["lock", palette.buttonText, palette.button],
					["lock", palette.buttonText, palette.highlight]
				]).fixedWidth_(30),
				View()
			),
			HLayout(
				StaticText().string_("Distortion").fixedWidth_(60),
				distortionSlider= Slider().orientation_(\horizontal)
			),

			//--effect section
			HLayout(
				StaticText().string_("HiPass").fixedWidth_(60),
				efxHPSlider= Slider().orientation_(\horizontal),
				efxHPNumber= NumberBox().decimals_(3).fixedWidth_(50)
			),
			HLayout(
				StaticText().string_("LoPass").fixedWidth_(60),
				efxLPSlider= Slider().orientation_(\horizontal),
				efxLPNumber= NumberBox().decimals_(3).fixedWidth_(50)
			),
			HLayout(
				StaticText().string_("Delay").fixedWidth_(60),
				efxDelSlider= RangeSlider().orientation_(\horizontal)
			),
			HLayout(
				StaticText().string_("Decay").fixedWidth_(60),
				efxDecSlider= Slider().orientation_(\horizontal),
				efxDecNumber= NumberBox().decimals_(1).fixedWidth_(50)
			),

			View(),
			(
				transposition= SGUItransposition(transposeKeys)
			).view,

			View(),
			(
				snapshots= SGUIsnapshots(SInstruments.snapshotsDir, snapshotFiles, bankKeys, snapshotKeys, \sCluster)
			).view,

			//--output section
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
				(mainRecord= SGUIrecord(s, SInstruments.recordingsDir, "sDrone_")).view
			),
			View()
		)
	);
	SGUI.report(win);
	SGUI.adapt(win);
	backgroundImage= Image(winRect.width, winRect.height).draw({|img|
		Pen.strokeColor= palette.highlight;
		Pen.translate(img.width*0.54, img.height*0.5);
		200.do{|i|
			var r= i*(winRect.width*0.002)+1;
			Pen.width= i.linlin(0, 199, 0.5, 0.01);
			Pen.strokeOval(Rect.aboutPoint(Point(0.gauss(8), 0.gauss(8)), r, r));
		};
	});
	win.view.setBackgroundImage(backgroundImage, 10, 0.3);
	win.view.keyDownAction= {|view, chr, mod, unicode, keycode, key|
		case
		{unicode==13} {
			win.view.focus;
		}
		{chr==Char.space} {
			droneButton.valueAction= 1-droneButton.value;
		}
		{
			transposition.keyDownAction(chr, mod, unicode, keycode);
			snapshots.keyDownAction(chr, mod);
		}
	};
	win.view.keyUpAction= {|view, chr, mod, unicode, keycode, key|
		transposition.keyUpAction(chr, mod, unicode, keycode);
	};
	win.onClose= {
		NetAddr.localAddr.sendMsg(\closed, \sDrone);
		routineGui.stop;
		ampTask.stop;
		freqTask.stop;
		oscResponders.do{|x| x.free};
		drone.release(1, {
			buffer.free;
			mainOutSyn.free;
			sDrone_bus.free;
		});
	};
	CmdPeriod.doOnce({
		drone.free;
		drone= nil;
		mainOutSyn= nil;
		sDrone_bus.free;
		sDrone_bus= nil;
	});


	ampSelectButtons.do{|but, i|
		but.action= {|view|
			ampSelectFunc.value(i);
		};
	};
	ampSelectButtons[0].value= 1;
	ampSelectFunc= {|index|
		ampSelectButtons.do{|b, i|
			if(index==i, {
				b.value= 1;
			}, {
				b.value= 0;
			});
		};
		ampStack.index= index;
		ampTask.stop;
		switch(index,
			0, {  //targets
				ampUpdate.value;
			},
			1, {  //random
				ampTask= Routine({
					inf.do{|i|
						var syn= drone.controllers.last.amplitudes.syn;
						drone.numChannels.do{|i|
							var amp;
							if((ampRandProbElement.value/3).coin, {
								amp= if(0.5.coin, {
									ampRangeElement.value[0].rrand(ampRangeElement.value[1]);
								}, {
									ampRangeElement.value[0];
								});
								syn.seti(\amplitudes, i, amp);
							});
						};
						ampRandRateSpec.map(ampRandRateElement.value).wait;
					};
				}).play(AppClock);
			},
			2, {  //ramp
				ampTask= Routine({
					inf.do{|i|
						var rfre= ampRampFreqSpec.map(ampRampFreqElement.value);
						var rcur= ampRampCurvSpec.map(ampRampCurvElement.value);
						var amps= Array.fill(drone.numChannels, {|j|
							(i*(j+1)*rfre%1).lincurve(0, 1, ampRangeElement.value[0], ampRangeElement.value[1], rcur);
						});
						drone.setAmplitudes(amps);
						ampRampRateSpec.map(ampRampRateElement.value).wait;
					};
				}).play(AppClock);
			},
			3, {  //wave
				ampTask= Routine({
					inf.do{|i|
						var wfre= ampWaveFreqSpec.map(ampWaveFreqElement.value);
						var wcur= ampWaveCurvSpec.map(ampWaveCurvElement.value);
						var amps= Array.fill(drone.numChannels, {|j|
							sin(i*(j+1)*wfre).lincurve(-1, 1, ampRangeElement.value[0], ampRangeElement.value[1], wcur);
						});
						drone.setAmplitudes(amps);
						ampWaveRateSpec.map(ampWaveRateElement.value).wait;
					};
				}).play(AppClock);
			},
			4, {  //lines
				ampTask= Routine({
					var lastCursor= -1;
					inf.do{|i|
						var step= 1/(glissTime.value*fps);
						if(ampLinesButtonLeft.value==1, {
							ampLinesCursor= ampLinesCursor-step;
						}, {
							if(ampLinesButtonRight.value==1, {
								ampLinesCursor= ampLinesCursor+step;
							});
						});
						switch(ampLinesPopup.value,
							0, {  //off
								ampLinesCursor= ampLinesCursor.clip(0, 1);
							},
							1, {  //on
								ampLinesCursor= ampLinesCursor.wrap(0, 1);
							},
							2, {  //palindrome
								if(ampLinesCursor>1, {
									ampLinesButtonLeft.value= 1;
									ampLinesButtonRight.value= 0;
								}, {
									if(ampLinesCursor<0, {
										ampLinesButtonLeft.value= 0;
										ampLinesButtonRight.value= 1;
									});
								});
								ampLinesCursor= ampLinesCursor.fold(0, 1);
							},
							3, {  //random direction
								if(0.03.coin, {
									if(0.5.coin, {
										ampLinesButtonLeft.value= 0;
										ampLinesButtonRight.value= 1;
									}, {
										ampLinesButtonLeft.value= 1;
										ampLinesButtonRight.value= 0;
									});
								});
								ampLinesCursor= ampLinesCursor.wrap(0, 1);
							},
							4, {  //random jump
								if(0.03.coin, {
									ampLinesCursor= 1.0.rand;
								}, {
									ampLinesCursor= ampLinesCursor.wrap(0, 1);
								});
							},
							5, {  //sync
								ampLinesCursor= freqLinesCursor;
							},
							6, {  //scratch
								//see mouseOverAction
								ampLinesCursor= ampLinesCursor.clip(0, 1);
							}
						);
						if(drone.controllers.last.notNil, {  //can happen when changing numVoices
							if(ampLinesCursor!=lastCursor, {  //only when cursor moved
								lastCursor= ampLinesCursor;
								ampUpdate.value;
							});
						});
						fps.reciprocal.wait;
					};
				}).play(AppClock);
			}
		);
		ampUsr.refresh;
	};

	ampLinesButtonLeft.action= {|view|
		if(view.value==1, {
			ampLinesButtonRight.value= 0;
		});
	};
	ampLinesButtonRight.action= {|view|
		if(view.value==1, {
			ampLinesButtonLeft.value= 0;
		});
	};

	ampRangeElement.action= {|val|
		{ampUpdate.value}.defer;
	};

	ampUsrAnim.background= Color.clear;
	ampUsrAnim.clearOnRefresh= true;
	ampUsrAnim.frameRate= fps;
	ampUsrAnim.acceptsMouse= false;
	ampUsrAnim.drawFunc= {|usr|
		var amps, ampWidth;
		var uw= usr.bounds.width-usrPadding.width;
		var uh= usr.bounds.height-(usrPadding.height*2);
		Pen.translate(usrPadding.width, uh+usrPadding.height);
		switch(ampStack.index,
			4, {  //lines
				Pen.strokeColor= palette.highlight;
				Pen.moveTo(Point(ampLinesCursor*uw, 0));
				Pen.lineTo(Point(ampLinesCursor*uw, 0-uh));
				Pen.stroke;
			},
			{
				Pen.font= fnt2;
				Pen.fillColor= palette.buttonText;
				amps= drone.getAmplitudes.last;  //read from control bus
				ampWidth= uw/amps.size*0.4;
				amps.do{|amp, i|
					var x= ampTargets[i].position.x*uw;
					var y= amp.linlin(ampRangeElement.value[0], ampRangeElement.value[1], 0, 0-uh);
					var str= SGUI.fixDec(amp, 2);
					Pen.addRect(Rect(x-ampWidth, y-0.5, ampWidth*2, 1));
					Pen.stringCenteredIn(str, Rect.aboutPoint(Point(x, y+15), 25, 10));
				};
				Pen.fill;
			}
		);
	};

	ampUserView= SGUIampUserView(ampUsr, usrPadding);
	ampUsr.drawFunc= {|usr|
		Pen.translate(usrPadding.width, usrPadding.height+ampUserView.uh);
		Pen.font= fnt2;
		ampUserView.drawMarkings(5, ampRangeElement.value[0], ampRangeElement.value[1]);
		switch(ampStack.index,
			0, {  //targets
				Pen.fillColor= palette.highlight;
				drone.numChannels.do{|i|
					ampUserView.drawTarget(ampTargets[i], ampRangeElement.value[0], ampRangeElement.value[1]);
				};
			},
			4, {  //lines
				Pen.strokeColor= palette.buttonText;
				drone.numChannels.do{|i|
					var ndex= i/(drone.numChannels-1).max(1);
					ampUserView.uw.asInteger.do{|x|
						var y= 0-ampLinesFunc.value(x/ampUserView.uw, ndex)*ampUserView.uh;
						if(x==0, {
							Pen.moveTo(Point(0, y));
						}, {
							Pen.lineTo(Point(x, y));
						});
					};
				};
				Pen.stroke;
			}
		);
	};
	ampUsr.mouseDownAction= {|view, x, y, mod|
		var nx= x.linlin(usrPadding.width, view.bounds.width, 0, 1);
		var ny;
		var minDist;
		switch(ampStack.index,
			0, {  //targets
				minDist= inf;
				drone.numChannels.do{|i|
					var target= ampTargets[i];
					var dst= (target.position.x-nx).abs;
					if(dst<minDist, {
						minDist= dst;
						ampClosestTarget= target;
					});
				};
			},
			4, {  //lines
				ny= y.linlin(usrPadding.height, view.bounds.height-usrPadding.height, 1, 0);
				if(abs(ny-ampLinesAY.value(nx))<abs(ny-ampLinesBY.value(nx)), {
					ampClosestLine= ampLinesA;
				}, {
					ampClosestLine= ampLinesB;
				});
			}
		);
		ampUsr.mouseMoveAction.value(view, x, y, mod);
	};
	ampUsr.mouseMoveAction= {|view, x, y, mod|
		var nx;
		var ny= y.linlin(usrPadding.height, view.bounds.height-usrPadding.height, 1, 0);
		var index, diff;
		switch(ampStack.index,
			0, {  //targets
				ampClosestTarget.amplitude= ny;
				ampUpdate.value;
			},
			4, {  //lines
				if(ampClosestLine.notNil, {
					nx= x.linlin(usrPadding.width, view.bounds.width, 0, 1);
					index= (nx*(ampLinesA.size-1)).round;
					if(mod.isShift, {
						if(ampLinesA==ampClosestLine, {
							diff= ampLinesB[index]+(ny-ampLinesA[index]);
							ampLinesB.put(index, diff.clip(0, 1));
						}, {
							diff= ampLinesA[index]+(ny-ampLinesB[index]);
							ampLinesA.put(index, diff.clip(0, 1));
						});
					});
					ampClosestLine.put(index, ny);
				});
				ampUpdate.value;
			}
		);
	};
	ampUsr.parent.acceptsMouseOver= true;
	ampUsr.mouseOverAction= {|view, x, y|
		switch(ampStack.index,
			4, {  //lines
				switch(ampLinesPopup.value,
					6, {  //scratch
						ampLinesCursor= x.linlin(usrPadding.width, view.bounds.width-1, 0, 1);
					}
				);
			}
		);
	};

	ampLfoDepthElement.action= {|val|
		drone.set(\min, ampLfoDepthSpec.map(val).linlin(0, 100, 1, 0));
	};
	ampLfoRateElement.action= {|val|
		drone.set(\rate, ampLfoRateSpec.map(val));
	};

	ampLinesAY= {|nx|
		ampLinesA.blendAt(nx*(ampLinesA.size-1));
	};
	ampLinesBY= {|nx|
		ampLinesB.blendAt(nx*(ampLinesB.size-1));
	};
	ampLinesFunc= {|nx, ny|
		var a= ampLinesAY.value(nx);
		var b= ampLinesBY.value(nx);
		a.blend(b, ny);
	};

	ampUpdate= {
		var amps, syn;
		switch(ampStack.index,
			0, {  //targets
				amps= Array.fill(drone.numChannels, {|i|
					var target= ampTargets[i];
					var amp= target.amplitude.linlin(0, 1, ampRangeElement.value[0], ampRangeElement.value[1]);
					target.position.y= amp;
					amp;
				});
				drone.setAmplitudes(amps);
			},
			4, {  //lines
				syn= drone.controllers.last.amplitudes.syn;
				amps= Array.fill(drone.numChannels, {|i|
					var j= i/(drone.numChannels-1).max(1);
					ampLinesFunc.value(ampLinesCursor, j).linlin(0, 1, ampRangeElement.value[0], ampRangeElement.value[1]);
				});
				syn.seti(\amplitudes, 0, amps);
			}
		);
		ampUsr.refresh;
	};


	freqSelectButtons.do{|but, i|
		but.action= {|view|
			freqSelectFunc.value(i);
		};
	};
	freqSelectButtons[0].value= 1;
	freqSelectFunc= {|index|
		freqSelectButtons.do{|b, i|
			if(index==i, {
				b.value= 1;
			}, {
				b.value= 0;
			});
		};
		freqStack.index= index;
		freqTask.stop;
		drone.set(\flag, glissTime.value);  //remove any lag override from line
		switch(index,
			0, {  //targets
				freqUpdate.value;
			},
			1, {  //random
				freqTask= Routine({
					inf.do{|i|
						var syn= drone.controllers.last.frequencies.syn;
						drone.numChannels.do{|j|
							var freq;
							if((freqRandProbElement.value/3).coin, {
								freq= 0.4.gauss(0.2).linexp(
									0,
									1,
									freqRangeSpec.map(freqRangeElement.value[0]),
									freqRangeSpec.map(freqRangeElement.value[1])
								);
								freq= scalesTunings.tune(freq, transposition.value);
								freq= masterTuning.tune(freq).clip(minFreq, maxFreq);
								syn.seti(\frequencies, j, freq);
							});
						};
						freqRandRateSpec.map(freqRandRateElement.value).wait;
					};
				}).play(AppClock);
			},
			2, {  //ramp
				freqTask= Routine({
					inf.do{|i|
						var rfre= freqRampFreqSpec.map(freqRampFreqElement.value);
						var rcur= freqRampCurvSpec.map(freqRampCurvElement.value);
						var freqs= Array.fill(drone.numChannels, {|j|
							var freq= (i*(j+1)*rfre%1).lincurve(0, 1, 0, 1, rcur);
							freq= freq.linexp(
								0,
								1,
								freqRangeSpec.map(freqRangeElement.value[0]),
								freqRangeSpec.map(freqRangeElement.value[1])
							);
							freq= scalesTunings.tune(freq, transposition.value);
							freq= masterTuning.tune(freq).clip(minFreq, maxFreq);
						});
						drone.setFrequencies(freqs);
						freqRampRateSpec.map(freqRampRateElement.value).wait;
					};
				}).play(AppClock);
			},
			3, {  //wave
				freqTask= Routine({
					inf.do{|i|
						var wfre= freqWaveFreqSpec.map(freqWaveFreqElement.value);
						var wcur= freqWaveCurvSpec.map(freqWaveCurvElement.value);
						var freqs= Array.fill(drone.numChannels, {|j|
							var freq= sin(i*(j+1)*wfre).lincurve(-1, 1, -1, 1, wcur);
							freq= freq.linexp(
								-1,
								1,
								freqRangeSpec.map(freqRangeElement.value[0]),
								freqRangeSpec.map(freqRangeElement.value[1])
							);
							freq= scalesTunings.tune(freq, transposition.value);
							freq= masterTuning.tune(freq).clip(minFreq, maxFreq);
						});
						drone.setFrequencies(freqs);
						freqWaveRateSpec.map(freqWaveRateElement.value).wait;
					};
				}).play(AppClock);
			},
			4, {  //lines
				freqTask= Routine({
					var lastCursor= -1;
					inf.do{|i|
						var step= 1/(glissTime.value*fps);
						if(freqLinesButtonLeft.value==1, {
							freqLinesCursor= freqLinesCursor-step;
						}, {
							if(freqLinesButtonRight.value==1, {
								freqLinesCursor= freqLinesCursor+step;
							});
						});
						switch(freqLinesPopup.value,
							0, {  //off
								freqLinesCursor= freqLinesCursor.clip(0, 1);
							},
							1, {  //on
								freqLinesCursor= freqLinesCursor.wrap(0, 1);
							},
							2, {  //palindrome
								if(freqLinesCursor>1, {
									freqLinesButtonLeft.value= 1;
									freqLinesButtonRight.value= 0;
								}, {
									if(freqLinesCursor<0, {
										freqLinesButtonLeft.value= 0;
										freqLinesButtonRight.value= 1;
									});
								});
								freqLinesCursor= freqLinesCursor.fold(0, 1);
							},
							3, {  //random direction
								if(0.03.coin, {
									if(0.5.coin, {
										freqLinesButtonLeft.value= 0;
										freqLinesButtonRight.value= 1;
									}, {
										freqLinesButtonLeft.value= 1;
										freqLinesButtonRight.value= 0;
									});
								});
								freqLinesCursor= freqLinesCursor.wrap(0, 1);
							},
							4, {  //random jump
								if(0.03.coin, {
									freqLinesCursor= 1.0.rand;
								}, {
									freqLinesCursor= freqLinesCursor.wrap(0, 1);
								});
							},
							5, {  //sync
								freqLinesCursor= ampLinesCursor;
							},
							6, {  //scratch
								//see mouseOverAction
								freqLinesCursor= freqLinesCursor.clip(0, 1);
							}
						);
						if(drone.controllers.last.notNil, {  //can happen when changing numVoices
							if(freqLinesCursor!=lastCursor, {  //only when cursor moved
								lastCursor= freqLinesCursor;
								freqUpdate.value;
							});
						});
						fps.reciprocal.wait;
					};
				}).play(AppClock);
			}
		);
		freqUsr.refresh;
	};

	freqGlissButton.action= {|view|
		freqUpdate.value;
	};
	freqXFadeButton.action= {|view|
		freqUpdate.value(true);
	};

	freqLinesButtonLeft.action= {|view|
		if(view.value==1, {
			freqLinesButtonRight.value= 0;
		});
	};
	freqLinesButtonRight.action= {|view|
		if(view.value==1, {
			freqLinesButtonLeft.value= 0;
		});
	};

	freqRangeElement.action= {|val|
		{freqUpdate.value}.defer;
	};

	freqUsrAnim.background= Color.clear;
	freqUsrAnim.clearOnRefresh= true;
	freqUsrAnim.frameRate= fps;
	freqUsrAnim.acceptsMouse= false;
	freqUsrAnim.drawFunc= {|usr|
		var freqs, freqWidth;
		var uw= usr.bounds.width-usrPadding.width;
		var uh= usr.bounds.height-(usrPadding.height*2);
		Pen.translate(usrPadding.width, uh+usrPadding.height);
		switch(freqStack.index,
			4, {  //lines
				Pen.strokeColor= palette.highlight;
				Pen.moveTo(Point(freqLinesCursor*uw, 0));
				Pen.lineTo(Point(freqLinesCursor*uw, 0-uh));
				Pen.stroke;
			},
			{
				Pen.font= fnt2;
				Pen.fillColor= palette.buttonText;
				freqs= drone.getFrequencies.last;  //read from control bus
				freqWidth= uw/freqs.size*0.4;
				freqs.do{|freq, i|
					var x= freqTargets[i].position.x*uw;
					var y= freq.explin(
						freqRangeSpec.map(freqRangeElement.value[0]),
						freqRangeSpec.map(freqRangeElement.value[1]),
						0,
						0-uh
					);
					var str= SGUI.fixDec(freq, 2);
					Pen.addRect(Rect(x-freqWidth, y-0.5, freqWidth*2, 1));
					Pen.stringCenteredIn(str, Rect.aboutPoint(Point(x, y+15), 25, 10));
				};
				Pen.fill;
			}
		);
	};

	freqUserView= SGUIfreqUserView(freqUsr, usrPadding, minFreq, maxFreq);
	freqUsr.drawFunc= {|usr|
		Pen.translate(usrPadding.width, usrPadding.height+freqUserView.uh);
		Pen.font= fnt2;
		freqUserView.drawMarkings(
			10,
			freqRangeSpec.map(freqRangeElement.value[0]),
			freqRangeSpec.map(freqRangeElement.value[1])
		);
		switch(freqStack.index,
			0, {  //targets
				Pen.fillColor= palette.highlight;
				drone.numChannels.do{|i|
					var target= freqTargets[i];
					var freq= target.frequency.linexp(
						0,
						1,
						freqRangeSpec.map(freqRangeElement.value[0]),
						freqRangeSpec.map(freqRangeElement.value[1])
					);
					freq= scalesTunings.tune(freq, transposition.value);
					freq= masterTuning.tune(freq).clip(minFreq, maxFreq);
					target.position.y= freq.explin(
						freqRangeSpec.map(freqRangeElement.value[0]),
						freqRangeSpec.map(freqRangeElement.value[1]),
						0,
						1
					);
					//target.frequency= target.position.y;
					freqUserView.drawTarget(target, freq);
				};
			},
			4, {  //lines
				Pen.strokeColor= palette.buttonText;
				drone.numChannels.do{|i|
					var ndex= i/(drone.numChannels-1).max(1);
					freqUserView.uw.asInteger.do{|x|
						var y= 0-freqLinesFunc.value(x/freqUserView.uw, ndex)*freqUserView.uh;
						if(x==0, {
							Pen.moveTo(Point(0, y));
						}, {
							Pen.lineTo(Point(x, y));
						});
					};
				};
				Pen.stroke;
			}
		);
	};
	freqUsr.mouseDownAction= {|view, x, y, mod|
		var nx= x.linlin(usrPadding.width, view.bounds.width, 0, 1);
		var ny;
		var minDist;
		switch(freqStack.index,
			0, {  //targets
				minDist= inf;
				drone.numChannels.do{|i|
					var target= freqTargets[i];
					var dst= (target.position.x-nx).abs;
					if(dst<minDist, {
						minDist= dst;
						freqClosestTarget= target;
					});
				};
			},
			4, {  //lines
				ny= y.linlin(usrPadding.height, view.bounds.height-usrPadding.height, 1, 0);
				if(abs(ny-freqLinesAY.value(nx))<abs(ny-freqLinesBY.value(nx)), {
					freqClosestLine= freqLinesA;
				}, {
					freqClosestLine= freqLinesB;
				});
			}
		);
		freqUsr.mouseMoveAction.value(view, x, y, mod);
	};
	freqUsr.mouseMoveAction= {|view, x, y, mod|
		var nx;
		var ny= y.linlin(usrPadding.height, view.bounds.height-usrPadding.height, 1, 0);
		var index, diff;
		switch(freqStack.index,
			0, {  //targets
				freqClosestTarget.frequency= ny;
				if(freqGlissButton.value==1, {
					freqUpdate.value;
				}, {
					freqClosestTarget.position.y= ny;
					freqUsr.refresh;
				});
			},
			4, {  //lines
				if(freqClosestLine.notNil, {
					nx= x.linlin(usrPadding.width, view.bounds.width, 0, 1);
					index= (nx*(freqLinesA.size-1)).round;
					if(mod.isShift, {
						if(freqLinesA==freqClosestLine, {
							diff= freqLinesB[index]+(ny-freqLinesA[index]);
							freqLinesB.put(index, diff.clip(0, 1));
						}, {
							diff= freqLinesA[index]+(ny-freqLinesB[index]);
							freqLinesA.put(index, diff.clip(0, 1));
						});
					});
					freqClosestLine.put(index, ny);
				});
				freqUpdate.value;
			}
		);
	};
	freqUsr.parent.acceptsMouseOver= true;
	freqUsr.mouseOverAction= {|view, x, y|
		switch(freqStack.index,
			4, {  //lines
				switch(freqLinesPopup.value,
					6, {  //scratch
						freqLinesCursor= x.linlin(usrPadding.width, view.bounds.width-1, 0, 1);
					}
				);
			}
		);
	};

	freqLfoDepthElement.action= {|val|
		drone.set(\famp, freqLfoDepthSpec.map(val)-freqLfoDepthSpec.minval);
	};
	freqLfoSpreadElement.action= {|val|
		drone.set(\fmul, freqLfoSpreadSpec.map(val));
	};
	freqLfoRateElement.action= {|val|
		drone.set(\fmod, freqLfoRateSpec.map(val));
	};

	freqLinesAY= {|nx|
		freqLinesA.blendAt(nx*(freqLinesA.size-1));
	};
	freqLinesBY= {|nx|
		freqLinesB.blendAt(nx*(freqLinesB.size-1));
	};
	freqLinesFunc= {|nx, ny|
		var a= freqLinesAY.value(nx);
		var b= freqLinesBY.value(nx);
		a.blend(b, ny);
	};

	freqUpdate= {|xfade= false|
		var freqs, syn;
		switch(freqStack.index,
			0, {  //targets
				if(xfade or:{freqGlissButton.value==1}, {
					freqs= Array.fill(drone.numChannels, {|i|
						var target= freqTargets[i];
						var freq= target.frequency.linexp(
							0,
							1,
							freqRangeSpec.map(freqRangeElement.value[0]),
							freqRangeSpec.map(freqRangeElement.value[1])
						);
						freq= scalesTunings.tune(freq, transposition.value);
						freq= masterTuning.tune(freq).clip(minFreq, maxFreq);
						target.position.y= freq.explin(
							freqRangeSpec.map(freqRangeElement.value[0]),
							freqRangeSpec.map(freqRangeElement.value[1]),
							0,
							1
						);
						//target.frequency= target.position.y;
						freq;
					});
					if(xfade, {
						drone.xsetFrequencies(freqs);
					}, {
						drone.setFrequencies(freqs);
					});
				});
			},
			4, {  //lines
				syn= drone.controllers.last.frequencies.syn;
				freqs= Array.fill(drone.numChannels, {|i|
					var ndex= i/(drone.numChannels-1).max(1);
					var nf= freqLinesFunc.value(freqLinesCursor, ndex);
					var freq= nf.linexp(
						0,
						1,
						freqRangeSpec.map(freqRangeElement.value[0]),
						freqRangeSpec.map(freqRangeElement.value[1])
					);
					freq= scalesTunings.tune(freq, transposition.value);
					freq= masterTuning.tune(freq).clip(minFreq, maxFreq);
				});
				syn.set(\flag, 0.1);  //override gliss time slider
				syn.seti(\frequencies, 0, freqs);
			}
		);
		freqUsr.refresh;
	};

	scalesTunings.action= {
		freqUpdate.value;
	};

	curvature.action= {|key, val|
		drone.set(key, val);
	};

	masterTuning.action= {
		freqUpdate.value;
	};

	glissTime.action= {|val|
		drone.set(\flag, val);
	};


	numVoicesNumber.value= defaultNumVoices;
	numVoicesNumber.action= {|view|
		view.value= view.value.clip(1, maxNumVoices).asInteger;
		if(drone.numChannels!=view.value, {
			createDrone.value;
		});
	};

	droneButton.action= {|view|
		drone.set(\on, view.value);
	};

	attackNumber.value= defaultAttack;
	attackNumber.action= {|view|
		view.value= view.value.clip(0, 999);
		drone.set(\atk, view.value);
	};
	releaseNumber.value= defaultRelease;
	releaseNumber.action= {|view|
		view.value= view.value.clip(0, 999);
		drone.set(\rel, view.value);
	};

	typePopup.items= [SDrone.type];
	SDrone.allSubclasses.collect{|class|
		if(class.type!=\File and:{class.type!=\Folder}, {
			typePopup.items= typePopup.items++class.type
		});
	};
	soundfiles.do{|f|
		typePopup.items= typePopup.items++("File_"++(f.path.basename.split($.)[0])).asSymbol;
	};
	soundfolders.do{|f, i|
		typePopup.items= typePopup.items++("Fold_"++f.path.basename).asSymbol;
	};
	typePopup.action= {|view|
		createDrone.value;
	};
	typeFromPopup= {
		var item= typePopup.items[typePopup.value];
		var type;
		if(item.asString.beginsWith("File_"), {
			type= \File;
		}, {
			if(item.asString.beginsWith("Fold_"), {
				type= \Folder;
			}, {
				type= item;
			});
		});
		type;
	};
	itemFromPopup= {
		var str= typePopup.items[typePopup.value].asString;
		str.copyToEnd(str.indexOf($_)?(-1)+1);  //remove File_ or Fold_
	};
	filePathFromPopup= {
		var str= itemFromPopup.value;
		var index= soundfiles.detectIndex{|f| f.path.basename.split($.)[0]==str};
		soundfiles[index].path;
	};
	filePathInFolderFromPopup= {
		var str= itemFromPopup.value;
		var index= soundfolders.detectIndex{|f| f.path.basename==str};
		soundfolders[index].soundfiles.wrapAt(fileIndex).path;
	};
	loadBuffer= {|path|
		buffer= Buffer.readChannel(s, path, channels:[0]);
		s.sync;
		buffer.normalize;
		s.sync;
	};
	fileIndex= 0;

	nextButton.action= {|view, mod|
		if(drone.class.type==\File, {
			drone.set(\pos, 0!drone.numChannels, \trig, 1);
		}, {
			if(drone.class.type==\Folder, {
				if(mod.isShift, {  //shift click step backwards
					fileIndex= fileIndex-1;
				}, {  //no shift one step forward
					fileIndex= fileIndex+1;
				});
				Routine({
					var oldBuffer= buffer;
					loadBuffer.value(filePathInFolderFromPopup.value);
					drone.set(\buf, buffer, \trig, 1);
					oldBuffer.free;
				}).play(AppClock);
			});
		});
	};
	randButton.action= {|view, mod|
		if(drone.class.type==\File, {
			drone.set(\loop, 1-view.value);  //wait a random time and then retrigger
		}, {
			if(drone.class.type==\Folder, {
				if(mod.isShift, {  //shift click jump back or forth a few steps
					fileIndex= fileIndex+(5.linrand+1*[1, -1].choose);
				}, {  //no shift random selection
					fileIndex= 9999.rand;
				});
				Routine({
					var oldBuffer= buffer;
					loadBuffer.value(filePathInFolderFromPopup.value);
					drone.set(\buf, buffer, \trig, 1);
					oldBuffer.free;
				}).play(AppClock);
			});
		});
	};
	lockButton.action= {|view, mod|
		if(drone.class.type==\File or:{drone.class.type==\Folder}, {
			drone.set(\rateBlend, 1-view.value*2-1);
		});
	};

	distortionSlider.action= {|view|
		drone.set(\dist, view.value);
	};

	efxHPSpec= ControlSpec(5, 15000, 'exp', 0, 5, "Hz");
	efxHPSlider.action= {|view|
		efxHPNumber.valueAction= efxHPSpec.map(view.value);
	};
	efxHPNumber.action= {|view|
		view.value= efxHPSpec.constrain(view.value);
		drone.set(\hp, view.value);
		efxHPSlider.value= efxHPSpec.unmap(view.value);
	};

	efxLPSpec= ControlSpec(5, 15000, 'exp', 0, 15000, "Hz");
	efxLPSlider.action= {|view|
		efxLPNumber.valueAction= efxLPSpec.map(view.value);
	};
	efxLPNumber.action= {|view|
		view.value= efxLPSpec.constrain(view.value);
		drone.set(\lp, view.value);
		efxLPSlider.value= efxLPSpec.unmap(view.value);
	};

	efxDelSpec= ControlSpec(0, 1, 'lin', 0, 0.5, "s");
	efxDelSlider.action= {|view|
		view.lo= efxDelSpec.constrain(view.lo);
		view.hi= efxDelSpec.constrain(view.hi);
		drone.set(\dmin, view.lo);
		drone.set(\dmax, view.hi);
	};

	efxDecSpec= ControlSpec(0, 25, 'lin', 0, 10);
	efxDecSlider.action= {|view|
		efxDecNumber.valueAction= efxDecSpec.map(view.value);
	};
	efxDecNumber.action= {|view|
		view.value= efxDecSpec.constrain(view.value);
		drone.set(\dec, view.value);
		efxDecSlider.value= efxDecSpec.unmap(view.value);
	};

	transposition.action= {|value, diff|
		freqUpdate.value;
	};
	transposition.scalesTunings= scalesTunings;

	snapshots.recallFunctions= (
		snapshotInstrument: {},
		snapshotVersion: {},
		ampSelect: {|val| ampSelectFunc.value(val)},
		ampTargets: {|val| ampTargets= val.deepCopy},
		ampLinesA: {|val| ampLinesA= val},
		ampLinesB: {|val| ampLinesB= val},
		ampLinesCursor: {|val| ampLinesCursor= val},
		freqSelect: {|val| freqSelectFunc.value(val)},
		freqTargets: {|val| freqTargets= val.deepCopy},
		freqLinesA: {|val| freqLinesA= val},
		freqLinesB: {|val| freqLinesB= val},
		freqLinesCursor: {|val| freqLinesCursor= val},
		efxDelSlider: {|val| efxDelSlider.setSpanActive(*val)},
		type: {|val|
			var item= val.typePopup;
			var type= typeFromPopup.value(item);
			var num= val.numVoicesNumber;
			var index= val.fileIndex;
			if(typePopup.items[typePopup.value]!=item or:{fileIndex!= index}, {
				numVoicesNumber.value= num;
				fileIndex= index;
				typePopup.valueAction= typePopup.items.indexOf(item)
				??{"sDrone: typePopup stored item not found".warn; 0};
			}, {
				fileIndex= index;
				if(num!=numVoicesNumber.value, {
					numVoicesNumber.valueAction= num;
				});
			});
		}
		//any other key will default to view.valueAction= assoc.value
	);
	snapshots.include= [  //order is important
		snapshotInstrument: \sDrone,
		snapshotVersion: 1.1,
		masterTuning: masterTuning,
		scalesTunings: scalesTunings,
		ampSelect: {ampStack.index},
		ampRandProbElement: ampRandProbElement,
		ampRandRateElement: ampRandRateElement,
		ampRampFreqElement: ampRampFreqElement,
		ampRampRateElement: ampRampRateElement,
		ampRampCurvElement: ampRampCurvElement,
		ampWaveFreqElement: ampWaveFreqElement,
		ampWaveRateElement: ampWaveRateElement,
		ampWaveCurvElement: ampWaveCurvElement,
		ampTargets: {ampTargets.deepCopy},
		ampLinesPopup: ampLinesPopup,
		ampLinesA: {ampLinesA.copy},
		ampLinesB: {ampLinesB.copy},
		ampLinesCursor: {ampLinesCursor},
		ampLinesButtonLeft: ampLinesButtonLeft,
		ampLinesButtonRight: ampLinesButtonRight,
		ampRangeElement: ampRangeElement,
		ampLfoDepthElement: ampLfoDepthElement,
		ampLfoRateElement: ampLfoRateElement,
		freqSelect: {freqStack.index},
		freqRandProbElement: freqRandProbElement,
		freqRandRateElement: freqRandRateElement,
		freqRampFreqElement: freqRampFreqElement,
		freqRampRateElement: freqRampRateElement,
		freqRampCurvElement: freqRampCurvElement,
		freqWaveFreqElement: freqWaveFreqElement,
		freqWaveRateElement: freqWaveRateElement,
		freqWaveCurvElement: freqWaveCurvElement,
		freqGlissButton: freqGlissButton,
		freqTargets: {freqTargets.deepCopy},
		freqLinesPopup: freqLinesPopup,
		freqLinesA: {freqLinesA.copy},
		freqLinesB: {freqLinesB.copy},
		freqLinesCursor: {freqLinesCursor},
		freqLinesButtonLeft: freqLinesButtonLeft,
		freqLinesButtonRight: freqLinesButtonRight,
		freqRangeElement: freqRangeElement,
		freqLfoDepthElement: freqLfoDepthElement,
		freqLfoSpreadElement: freqLfoSpreadElement,
		freqLfoRateElement: freqLfoRateElement,
		curvature: curvature,
		glissTime: glissTime,
		droneButton: droneButton,
		attackNumber: attackNumber,
		releaseNumber: releaseNumber,
		distortionSlider: distortionSlider,
		efxHPNumber: efxHPNumber,
		efxLPNumber: efxLPNumber,
		efxDelSlider: {[efxDelSlider.lo, efxDelSlider.hi]},
		efxDecNumber: efxDecNumber,
		mainBalanceElement: mainBalanceElement,
		mainVolume: mainVolume,
		mainReverbElement: mainReverbElement,
		type: {(
			typePopup: typePopup.items[typePopup.value],
			numVoicesNumber: numVoicesNumber.value.asInteger,
			fileIndex: fileIndex
		)}
	];

	mainBalanceElement.value= 0.5;
	mainBalanceElement.action= {|val|
		mainOutSyn.set(\pan, val*2-1);
	};

	mainVolume.action= {|val|
		drone.set(\vol, val);
	};

	mainReverbElement.action= {|val|
		mainOutSyn.set(\verbMix, val*2-1);
	};


	//--network
	efxDecA= efxDecSpec.unmap(efxDecSpec.default);
	efxDecB= 0;
	distortionA= 0;
	distortionB= 0;
	setupOscResponders= {
		oscResponders= [

			//--from sKeyBpad
			OSCFunc({|msg|
				{win.view.keyDownAction.value(win.view, msg[1].asAscii, 0)}.defer;
			}, \keyBpad, recvPort:oscPort),

			//--from sKeyCpad
			OSCFunc({|msg|
				{droneButton.valueAction= 1-droneButton.value}.defer;
			}, \on, recvPort:oscPort),

			//--from sNanokontrol
			OSCFunc({|msg| ampLfoDepthElement.value= msg[1]}, \ampLfoDepth, recvPort:oscPort),
			OSCFunc({|msg| ampLfoRateElement.value= msg[1]}, \ampLfoRate, recvPort:oscPort),
			OSCFunc({|msg|
				{freqSelectFunc.value(freqStack.index+msg[1]%freqSelectButtons.size)}.defer;
			}, \freqSelect, recvPort:oscPort),
			OSCFunc({|msg|
				{freqLinesButtonRight.valueAction= 1-freqLinesButtonRight.value}.defer;
			}, \freqLinesPlay, recvPort:oscPort),
			OSCFunc({|msg| freqRangeElement.value= [msg[1], msg[2]]}, \freqRangeMinMax, recvPort:oscPort),
			OSCFunc({|msg|  //val(float 0-1)
				var span= (freqRangeElement.value[1]-freqRangeElement.value[0])*0.5;
				var val= msg[1].clip(span, 1-span);
				freqRangeElement.value= [val-span, val+span];
			}, \freqRange, recvPort:oscPort),
			OSCFunc({|msg| freqLfoDepthElement.value= msg[1]}, \freqLfoDepth, recvPort:oscPort),
			OSCFunc({|msg| freqLfoSpreadElement.value= msg[1]}, \freqLfoSpread, recvPort:oscPort),
			OSCFunc({|msg| freqLfoRateElement.value= msg[1]}, \freqLfoRate, recvPort:oscPort),
			OSCFunc({|msg|
				{curvature.valueActionNorm= [msg[1], 0]}.defer;
			}, \curvature, recvPort:oscPort),
			OSCFunc({|msg|
				{glissTime.valueActionNorm= msg[1]}.defer;
			}, \glissTime, recvPort:oscPort),
			OSCFunc({|msg|
				{
					if(msg.size>2, {distortionB= msg[2]}, {distortionA= msg[1]});
					distortionSlider.valueAction= distortionA+distortionB;
				}.defer;
			}, \distortion, recvPort:oscPort),
			OSCFunc({|msg|
				{efxHPSlider.valueAction= msg[1]}.defer;
			}, \efxHP, recvPort:oscPort),
			OSCFunc({|msg|
				{efxLPSlider.valueAction= msg[1]}.defer;
			}, \efxLP, recvPort:oscPort),
			OSCFunc({|msg|
				{
					efxDelSlider.setSpanActive(msg[1], msg[2]);
				}.defer;
			}, \efxDelMinMax, recvPort:oscPort),
			OSCFunc({|msg|
				{
					efxDelSlider.setSpanActive(msg[1], msg[1]+efxDelSlider.range);
				}.defer;
			}, \efxDel, recvPort:oscPort),
			OSCFunc({|msg|
				{
					if(msg.size>2, {efxDecB= msg[2]}, {efxDecA= msg[1]});
					efxDecSlider.valueAction= efxDecA+efxDecB;
				}.defer;
			}, \efxDec, recvPort:oscPort),
			OSCFunc({|msg|
				{mainVolume.valueAction= msg[1]}.defer;
			}, \mainVolume, recvPort:oscPort),
			OSCFunc({|msg|
				{mainRecord.valueAction= 1-mainRecord.value}.defer;
			}, \mainRecord, recvPort:oscPort),

			//--from sSentograph
			OSCFunc({|msg|
				drone.set(\amp, msg[1]);
			}, \amp, recvPort:oscPort),
			OSCFunc({|msg|
				mainBalanceElement.value= msg[1]+1/2;
			}, \mainBalance, recvPort:oscPort),

			//--from sText/sKeyboard
			OSCFunc({|msg|
				{
					msg[1..drone.numChannels].do{|a, i|
						ampTargets[i].amplitude= a;
					};
					ampUpdate.value;
				}.defer
			}, \amplitudes, recvPort:oscPort),
			OSCFunc({|msg|
				{
					msg[1..drone.numChannels].do{|f, i|
						freqTargets[i].frequency= f.explin(minFreq, maxFreq, 0, 1);
					};
					freqUpdate.value;
				}.defer
			}, \frequencies, recvPort:oscPort),

			//--other/unused
			OSCFunc({|msg|
				ampRandRateElement.value= msg[1];
				ampRampRateElement.value= msg[1];
				ampWaveRateElement.value= msg[1];
				freqRandRateElement.value= msg[1];
				freqRampRateElement.value= msg[1];
				freqWaveRateElement.value= msg[1];
			}, \rate, recvPort:oscPort),
			OSCFunc({|msg|  //index(int), val(float 0-1)
				{
					freqTargets.clipAt(msg[1]).frequency= msg[2];
					freqUpdate.value;
				}.defer;
			}, \freqTargets, recvPort:oscPort),
			OSCFunc({|msg|  //index(int), val(float 0-1)
				{
					ampTargets.clipAt(msg[1]).amplitude= msg[2];
					ampUpdate.value;
				}.defer;
			}, \ampTargets, recvPort:oscPort),
			OSCFunc({|msg|
				{attackNumber.valueAction= msg[1]}.defer;
			}, \attack, recvPort:oscPort),
			OSCFunc({|msg|
				{releaseNumber.valueAction= msg[1]}.defer;
			}, \release, recvPort:oscPort),
			OSCFunc({|msg|
				mainReverbElement.value= msg[1];
			}, \mainReverb, recvPort:oscPort)
		];
	};


	//--drone
	createDrone= {
		var newNumChannels= numVoicesNumber.value.asInteger;
		var args;
		var oldBuffer;
		var type= typeFromPopup.value;
		var class= ([SDrone]++SDrone.allSubclasses).detect{|c| c.type==type};

		if(drone.isNil, {  //only at startup
			args= [
				\on, droneButton.value,
				\lag, glag,
				\atk, attackNumber.value,
				\rel, releaseNumber.value,
				\dist, distortionSlider.value
			];
		}, {  //when changing typePopup or numVoices
			ampUsrAnim.animate= false;
			freqUsrAnim.animate= false;
			if(drone.class.type==\File or:{drone.class.type==\Folder}, {
				oldBuffer= buffer;
				drone.release(nil, {oldBuffer.free});
			}, {
				drone.release(nil);
			});
			args= drone.arguments;
			args.put(\buf, nil);
			args.put(\amplitudes, {|i|
				ampTargets[i].amplitude.linlin(0, 1, ampRangeElement.value[0], ampRangeElement.value[1]);
			}!newNumChannels);
			args= args.asKeyValuePairs;
		});

		Routine({
			switch(type,
				\File, {
					loadBuffer.value(filePathFromPopup.value);
					args= args++[\buf, buffer];
					nextButton.states_([["trig"]]);
					nextButton.visible= true;
					randButton.states_([
						["rand", palette.buttonText, palette.button],
						["rand", palette.buttonText, palette.highlight]
					]);
					randButton.visible= true;
					lockButton.visible= true;
				},
				\Folder, {
					loadBuffer.value(filePathInFolderFromPopup.value);
					args= args++[\buf, buffer];
					nextButton.states_([["next"]]);
					nextButton.visible= true;
					randButton.states_([["rand"]]);
					randButton.visible= true;
					lockButton.visible= true;
				},
				{
					nextButton.visible= false;
					randButton.visible= false;
					lockButton.visible= false;
				}
			);
			//"_________".postln; args.pairsDo{|a, b| [a, b].postln};  //debug
			drone= class.new(newNumChannels, outbus: sDrone_bus, args: args);
			~drone= drone;
			s.sync;
			newNumChannels.do{|i|
				ampTargets[i].position.x= i.linlin(-0.5, newNumChannels-0.5, 0, 1);
				freqTargets[i].position.x= i.linlin(-0.5, newNumChannels-0.5, 0, 1);
			};
			ampUsrAnim.animate= true;
			freqUsrAnim.animate= true;
			freqUpdate.value;
			ampUsr.refresh;
		}).play(AppClock);
	};
	sDrone_bus= Bus.audio(s, 2);
	mainOutSyn= SynthDef(\droneMainOut, {|out= 0, pan= 0, verbMix= -1|
		var snd= In.ar(\sDrone_bus.ir, 2);
		snd= Balance2.ar(snd[0], snd[1], pan.lag(0.03));
		snd= XFade2.ar(snd, GVerb.ar(snd, 90, 4)*0.75, verbMix.lag);
		Out.ar(out, Limiter.ar(snd));
	}).play(args: [\sDrone_bus, sDrone_bus], addAction: \addToTail);
	createDrone.value;

	{
		ampRandProbElement.value= 0.1;
		ampRandRateElement.value= ampRandRateSpec.unmap(ampRandRateSpec.default);
		ampRampFreqElement.value= ampRampFreqSpec.unmap(ampRampFreqSpec.default);
		ampRampRateElement.value= ampRampRateSpec.unmap(ampRampRateSpec.default);
		ampRampCurvElement.value= ampRampCurvSpec.unmap(ampRampCurvSpec.default);
		ampWaveFreqElement.value= ampWaveFreqSpec.unmap(ampWaveFreqSpec.default);
		ampWaveRateElement.value= ampWaveRateSpec.unmap(ampWaveRateSpec.default);
		ampWaveCurvElement.value= ampWaveCurvSpec.unmap(ampWaveCurvSpec.default);

		ampLinesPopup.value= ampLinesPopup.items.detectIndex{|x| x.asSymbol==\scratch};
		ampLfoDepthElement.value= ampLfoDepthSpec.unmap(ampLfoDepthSpec.default);
		ampLfoRateElement.value= ampLfoRateSpec.unmap(ampLfoRateSpec.default);
		ampRangeElement.value= defaultAmpRange;

		freqRandProbElement.value= 0.1;
		freqRandRateElement.value= freqRandRateSpec.unmap(freqRandRateSpec.default);
		freqRampFreqElement.value= freqRampFreqSpec.unmap(freqRampFreqSpec.default);
		freqRampRateElement.value= freqRampRateSpec.unmap(freqRampRateSpec.default);
		freqRampCurvElement.value= freqRampCurvSpec.unmap(freqRampCurvSpec.default);
		freqWaveFreqElement.value= freqWaveFreqSpec.unmap(freqWaveFreqSpec.default);
		freqWaveRateElement.value= freqWaveRateSpec.unmap(freqWaveRateSpec.default);
		freqWaveCurvElement.value= freqWaveCurvSpec.unmap(freqWaveCurvSpec.default);

		freqLinesPopup.value= freqLinesPopup.items.detectIndex{|x| x.asSymbol==\scratch};
		freqGlissButton.valueAction= 1;
		freqLfoDepthElement.value= freqLfoDepthSpec.unmap(freqLfoDepthSpec.default);
		freqLfoSpreadElement.value= freqLfoSpreadSpec.unmap(freqLfoSpreadSpec.default);
		freqLfoRateElement.value= freqLfoRateSpec.unmap(freqLfoRateSpec.default);
		freqRangeElement.value= defaultFreqRange;

		curvature.valueAction= #[-4, 0];
		glissTime.valueAction= defaultFreqGlissTime;
		efxHPNumber.valueAction= efxHPSpec.default;
		efxLPNumber.valueAction= efxLPSpec.default;
		efxDelSlider.activeLo= 0.25;
		efxDelSlider.activeHi= 0.75;
		efxDecNumber.valueAction= efxDecSpec.default;
		mainVolume.valueAction= defaultMainVolume;
		setupOscResponders.value;
		ampUsrAnim.animate= true;
		freqUsrAnim.animate= true;
		{ampRangeElement.doAction}.defer(0.1);
		routineGui= Routine({
			inf.do{
				ampRandProbElement.update;
				ampRandRateElement.update;
				ampRampFreqElement.update;
				ampRampRateElement.update;
				ampRampCurvElement.update;
				ampWaveFreqElement.update;
				ampWaveRateElement.update;
				ampWaveCurvElement.update;

				ampRangeElement.update;
				ampLfoDepthElement.update;
				ampLfoRateElement.update;

				freqRandProbElement.update;
				freqRandRateElement.update;
				freqRampFreqElement.update;
				freqRampRateElement.update;
				freqRampCurvElement.update;
				freqWaveFreqElement.update;
				freqWaveRateElement.update;
				freqWaveCurvElement.update;

				freqRangeElement.update;
				freqLfoDepthElement.update;
				freqLfoSpreadElement.update;
				freqLfoRateElement.update;

				mainBalanceElement.update;
				mainReverbElement.update;
				fps.reciprocal.wait;
			};
		}).play(AppClock);
		win.front;
	}.defer(0.5);
};
)
