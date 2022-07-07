//f.olofsson & t.ungvary 2019

(
//--settings
var oscPort= 13060;
var maxNumVoices= 99;  //maximum number of voices each synth can play
var numGliss= 9;  //number of synths right hand side
var maxNumTargets= 50;  //maximum number of amp and freq targets
var winRect= Rect(242, 242, 1150, 780);  //x, y, w, h
var palette= SGUI.palette((highlight: Color.blue(2/3, 0.5)));
var fnt= SGUI.font;
var fnt2= SGUI.font.copy.size_(10);
var fps= 25;
var minFreq= 20, maxFreq= 12000;  //Hz
var ampLag= 0.1;  //seconds
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
	\Bank1 -> "sGliss_snapshots_Bank1.scd",
	\Bank2 -> "sGliss_snapshots_Bank2.scd",
	\Bank3 -> "sGliss_snapshots_Bank3.scd",
	\Bank4 -> "sGliss_snapshots_Bank4.scd",
	\Bank5 -> "sGliss_snapshots_Bank5.scd",
	\Bank6 -> "sGliss_snapshots_Bank6.scd",
	\Bank7 -> "sGliss_snapshots_Bank7.scd",
	\Bank8 -> "sGliss_snapshots_Bank8.scd",
	\Bank9 -> "sGliss_snapshots_Bank9.scd",
];

//--defaults
var defaultAmpNumTargets= 3;  //number of circles for controlling amplitudes
var defaultFreqNumTargets= 3;  //number of circles for controlling frequencies
var defaultAmpRange= #[0, 0.75];  //minmax percent
var defaultAmp= 0.25;
var defaultFreqRange= #[0.05, 0.95];  //minmax percent
var defaultFreq= 99;  //Hz
var defaultFreqLfoDepth= 0;  //percent
var defaultFreqLfoRate= 0.1;  //Hz
var defaultAmpLfoDepth= 0;  //percent
var defaultAmpLfoRate= 0.1;  //Hz
var defaultFreqGlissTime= 3;  //seconds
var defaultGlissTypes= #[\Sine, \SineFB, \Saw, \Pulse, \Noise, \Pink];
var defaultGlissAtk= 0.1, defaultGlissRel= 1;
var defaultMainVolume= 0.0;  //dB

s.options.numWireBufs= s.options.numWireBufs.max(128);
s.options.memSize= s.options.memSize.max(2**16);
s.latency= 0.08;
s.waitForBoot{

	//--functions and objects
	var soundfiles= SoundFile.collect(SInstruments.soundfilesDir+/+"*");
	var soundfolders= (SInstruments.soundfilesDir+/+"*").pathMatch.select{|x|
		PathName(x).isFolder;
	}.collect{|f|
		(path: f, soundfiles: SoundFile.collect(f+/+"*"));
	};
	var lookup, createLookup;
	var glissandoTypes, loadBuffer, findFile, findFileInFolder;
	var glissandi= {|i| (type: defaultGlissTypes.wrapAt(i), fileIndex: 0)}!numGliss;
	var usrPadding= Size(25, 20);
	var ampSelectFunc;
	var ampTargets= List.new;
	var ampClosestTarget, ampUpdate, ampTask;
	var ampLinesA= {0.5+0.5.linrand}!20, ampLinesB= {0.5-0.5.linrand}!20, ampClosestLine;
	var ampLinesAY, ampLinesBY, ampLinesFunc, ampLinesCursor= 0;
	var ampLfoRateAdd= 0;
	var freqSelectFunc;
	var freqTargets= List.new;
	var freqClosestTarget, freqUpdate, freqTask;
	var freqLinesA= {0.5+0.5.linrand}!20, freqLinesB= {0.5-0.5.linrand}!20, freqClosestLine;
	var freqLinesAY, freqLinesBY, freqLinesFunc, freqLinesCursor= 0;
	var freqLfoRateAdd= 0;
	var setupOscResponders, oscResponders;
	var routineGui;
	var sGliss_bus;
	var mainOutSyn;

	//--gui
	var ampSelectButtons, ampStack;
	var ampRangeElement= SGUIelementRange();
	var ampNumTargetsNumber, ampNumTargetsSpec;
	var ampRandProbElement= SGUIelement();
	var ampRandRateElement= SGUIelement();
	var ampRandRateSpec= ControlSpec(0.05, 5, 'lin', 0, 1);
	var ampRampFreqElement= SGUIelement();
	var ampRampFreqSpec= ControlSpec(-1, 1, 'lin', 0, -0.01);
	var ampRampRateElement= SGUIelement();
	var ampRampRateSpec= ControlSpec(0.001, 1, 'lin', 0, 0.15);
	var ampRampCurvElement= SGUIelement();
	var ampRampCurvSpec= ControlSpec(-8, 8, 'lin', 0, 0);
	var ampWaveFreqElement= SGUIelement();
	var ampWaveFreqSpec= ControlSpec(0.01, 1, 'lin', 0, 0.1);
	var ampWaveRateElement= SGUIelement();
	var ampWaveRateSpec= ControlSpec(0.001, 1, 'lin', 0, 0.15);
	var ampWaveCurvElement= SGUIelement();
	var ampWaveCurvSpec= ControlSpec(-8, 8, 'lin', 0, 0);
	var ampLinesButtonLeft, ampLinesButtonRight, ampLinesPopup;
	var ampUsr, ampUsrAnim, ampUserView;
	var ampLfoDepthElement= SGUIelement();
	var ampLfoDepthSpec= ControlSpec(0, 100, 'lin', 1, defaultAmpLfoDepth, "%");
	var ampLfoRateElement= SGUIelement();
	var ampLfoRateSpec= ControlSpec(0.05, 50, 'exp', 0, defaultAmpLfoRate, "Hz");
	var freqSelectButtons, freqStack;
	var freqRangeElement= SGUIelementRange();
	var freqRangeSpec= ControlSpec(minFreq, maxFreq, 'exp', 0, 99, "Hz");
	var freqGlissButton;
	var freqNumTargetsNumber, freqNumTargetsSpec;
	var freqRandProbElement= SGUIelement();
	var freqRandRateElement= SGUIelement();
	var freqRandRateSpec= ControlSpec(0.05, 5, 'lin', 0, 1);
	var freqRampFreqElement= SGUIelement();
	var freqRampFreqSpec= ControlSpec(-1, 1, 'lin', 0, -0.01);
	var freqRampRateElement= SGUIelement();
	var freqRampRateSpec= ControlSpec(0.001, 1, 'lin', 0, 0.15);
	var freqRampCurvElement= SGUIelement();
	var freqRampCurvSpec= ControlSpec(-8, 8, 'lin', 0, 0);
	var freqWaveFreqElement= SGUIelement();
	var freqWaveFreqSpec= ControlSpec(0.01, 1, 'lin', 0, 0.1);
	var freqWaveRateElement= SGUIelement();
	var freqWaveRateSpec= ControlSpec(0.001, 1, 'lin', 0, 0.1);
	var freqWaveCurvElement= SGUIelement();
	var freqWaveCurvSpec= ControlSpec(-8, 8, 'lin', 0, 0);
	var freqLinesButtonLeft, freqLinesButtonRight, freqLinesPopup;
	var freqUsr, freqUsrAnim, freqUserView;
	var freqLfoDepthElement= SGUIelement();
	var freqLfoDepthSpec= ControlSpec(0, 100, 'lin', 1, defaultFreqLfoDepth, "%");
	var freqLfoRateElement= SGUIelement();
	var freqLfoRateSpec= ControlSpec(0.05, 50, 'exp', 0, defaultFreqLfoRate, "Hz");
	var scalesTunings;
	var masterTuning;
	var glissTime;
	var curvature;
	var onButton;
	var numSpec, addSpec, delSpec;
	var atkSpec, relSpec;
	var transposition;
	var snapshots;
	var mainBalanceElement= SGUIelement();
	var mainVolume;
	var mainReverbElement= SGUIelement();
	var mainRecord;
	var backgroundImage;
	var win= Window("sGliss", winRect);
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
						SGUI.shrink(StaticText().string_("Number of Targets")),
						ampNumTargetsNumber= NumberBox().step_(1)
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
				}
			),
			HLayout(
				freqStack= StackLayout(
					View().layout_(HLayout(  //targets
						freqGlissButton= Button().states_([
							["  Trig", palette.buttonText, palette.button],
							["•Trig", palette.buttonText, palette.highlight]
						]),
						SGUI.shrink(StaticText().string_("Number of Targets")),
						freqNumTargetsNumber= NumberBox().step_(1)
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
				freqLfoDepthElement.addView(NumberBox().step_(1).fixedWidth_(50), freqLfoDepthSpec),
				StaticText().string_("%").fixedWidth_(20)
			),
			HLayout(
				StaticText().string_("Fre.LFO Rate").fixedWidth_(100),
				freqLfoRateElement.addView(Slider().orientation_(\horizontal)),
				freqLfoRateElement.addView(NumberBox().decimals_(3).fixedWidth_(50), freqLfoRateSpec),
				StaticText().string_("Hz").fixedWidth_(20)
			),
			HLayout(
				(scalesTunings= SGUIscalesTunings().fixedHeight_(125)).view,
				(masterTuning= SGUImasterTuning()).view
			),
			(glissTime= SGUIglissTime(defaultFreqGlissTime)).view
		),

		VLayout(
			HLayout(
				(curvature= SGUIcurvature()).view,
				View()
			),

			//--synths section
			StaticText().string_("Voices"),
			onButton= Button().states_([
				["Gliss Off", palette.buttonText, palette.button],
				["Gliss On", palette.buttonText, palette.highlight]
			]),
			GridLayout.rows(
				[
					StaticText().string_("type"),
					StaticText().string_("vol"),
					StaticText().string_("num"),
					StaticText().string_("add"),
					StaticText().string_("del"),
					StaticText().string_("atk"),
					StaticText().string_("rel"),
					StaticText().string_("extra").minWidth_(30),
					View().minWidth_(30),
					View().minWidth_(30)
				],
				*glissandi.collect{|go|
					var arr= [
						\typePopup, PopUpMenu().minWidth_(125),
						\volSlider, Slider().orientation_(\horizontal),
						\numNumber, NumberBox().step_(1),
						\addNumber, NumberBox(),
						\delNumber, NumberBox().scroll_step_(0.1),
						\atkNumber, NumberBox().scroll_step_(0.1),
						\relNumber, NumberBox().scroll_step_(0.1),
						\nextButton, Button().states_([["next"]]).fixedWidth_(30),
						\randButton, Button().states_([["rand"]]).fixedWidth_(30),
						\lockButton, Button().states_([
							["lock", palette.buttonText, palette.button],
							["lock", palette.buttonText, palette.highlight]
						]).fixedWidth_(30),
						\folderText, StaticText().minHeight_(25),
					];
					go.putAll(arr);
					arr.select{|o, i| i.odd};
				};
			),

			(
				transposition= SGUItransposition(transposeKeys)
			).view,

			(
				snapshots= SGUIsnapshots(SInstruments.snapshotsDir, snapshotFiles, bankKeys, snapshotKeys, \sGliss)
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
				(mainRecord= SGUIrecord(s, SInstruments.recordingsDir, "sGliss_")).view
			)
		)
	);
	SGUI.report(win);
	SGUI.adapt(win);
	backgroundImage= Image(500, 500).draw({|img|
		Pen.width= 0.25;
		Pen.strokeColor= palette.highlight;
		60.do{
			Pen.moveTo(Point(25.gauss(25), 25.gauss(25)+img.height));
			Pen.curveTo(
				Point(25.gauss(25)+img.width, 25.gauss(25)),
				Point(img.width*0.6, img.height*0.6),
				Point(img.width*0.7, img.height*0.7)
			);
		};
		Pen.stroke;
		Pen.width= 1;
		5.do{
			Pen.moveTo(Point(25.gauss(25), 25.gauss(25)+img.height));
			Pen.curveTo(
				Point(25.gauss(25)+img.width, 25.gauss(25)),
				Point(img.width*0.58, img.height*0.58),
				Point(img.width*0.65, img.height*0.65)
			);
		};
		Pen.stroke;
	});
	win.view.setBackgroundImage(backgroundImage, 10, 0.3);
	if(SGUI.currentTheme!=\dark, {
		(win.view.children++ampRandProbElement.views)
		.select{|v| v.isKindOf(Slider) or:{v.isKindOf(RangeSlider)}}.do{|v|
			v.background= Color.grey(0.7725, 0.5);
		};
	});
	win.view.keyDownAction= {|view, chr, mod, unicode, keycode, key|
		case
		{unicode==13} {
			win.view.focus;
		}
		{chr==Char.space} {
			onButton.valueAction= 1-onButton.value;
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
		NetAddr.localAddr.sendMsg(\closed, \sGliss);
		routineGui.stop;
		ampTask.stop;
		freqTask.stop;
		oscResponders.do{|x| x.free};
		mainOutSyn.set(\vol, -99, \verbMix, -1);
		{
			glissandi.do{|go| go.gliss.free; go.buffer.free};
			mainOutSyn.free;
			sGliss_bus.free;
		}.defer(1);
	};
	CmdPeriod.doOnce({
		glissandi= nil;
		mainOutSyn= nil;
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
						var syn= glissandi[0].gliss.controllers[0].amplitudes.syn;
						maxNumVoices.do{|i|
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
						var amps= Array.fill(maxNumVoices, {|j|
							(i+j*rfre%1).lincurve(0, 1, ampRangeElement.value[0], ampRangeElement.value[1], rcur);
						});
						glissandi[0].gliss.setAmplitudes(amps[lookup]);
						ampRampRateSpec.map(ampRampRateElement.value).wait;
					};
				}).play(AppClock);
			},
			3, {  //wave
				ampTask= Routine({
					inf.do{|i|
						var wfre= ampWaveFreqSpec.map(ampWaveFreqElement.value);
						var wcur= ampWaveCurvSpec.map(ampWaveCurvElement.value);
						var amps= Array.fill(maxNumVoices, {|j|
							sin(i+j*wfre).lincurve(-1, 1, ampRangeElement.value[0], ampRangeElement.value[1], wcur);
						});
						glissandi[0].gliss.setAmplitudes(amps[lookup]);
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
						if(ampLinesCursor!=lastCursor, {  //only when cursor moved
							lastCursor= ampLinesCursor;
							ampUpdate.value;
						});
						fps.reciprocal.wait;
					};
				}).play(AppClock);
			}
		);
		ampUsr.refresh;
	};

	ampNumTargetsSpec= ControlSpec(1, maxNumTargets, 'lin', 1, defaultAmpNumTargets);
	ampNumTargetsNumber.action= {|view|
		view.value= ampNumTargetsSpec.constrain(view.value);
		if(ampTargets.size<view.value, {
			while({ampTargets.size<view.value}, {
				ampTargets.add(
					(
						position: Point(0, 0),  //coordinates
						amplitude: defaultAmp.linlin(*[defaultAmpRange, 0, 1].flat)
					)
				);
			});
		}, {
			if(ampTargets.size>view.value, {
				while({ampTargets.size>view.value}, {
					ampTargets.pop;
				});
			});
		});
		ampTargets.do{|target, i|
			target.position.x= i.linlin(-0.5, ampTargets.size-0.5, 0, 1);
		};
		ampUpdate.value;
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
		var amps, maxNum;
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
				Pen.strokeColor= palette.buttonText;
				Pen.fillColor= palette.highlight;
				amps= glissandi[0].gliss.getAmplitudes[0];
				maxNum= glissandi.maxValue{|go| go.gliss.numVoices};
				amps.do{|amp, i|
					var x= lookup[i].linlin(0, maxNumVoices-1, 2, uw-2);
					var y= amp.linlin(ampRangeElement.value[0], ampRangeElement.value[1], 0, 0-uh);
					Pen.addRect(Rect.aboutPoint(Point(x, y), 1, 1));
					if(i<=32 and:{i<maxNum}, {
						Pen.stringCenteredIn(
							(i+1).asString,
							Rect.aboutPoint(Point(x.clip(3, uw-3), (y+15).min(5)), 10, 10)
						);
					});
				};
				Pen.stroke;
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
				ampTargets.do{|target|
					ampUserView.drawTarget(target, ampRangeElement.value[0], ampRangeElement.value[1]);
				};
			},
			4, {  //lines
				Pen.strokeColor= palette.buttonText;
				glissandi.maxValue{|go| go.gliss.numVoices}.do{|i|
					var ndex= lookup[i]/(maxNumVoices-1);
					if(i<=32, {
						ampUserView.uw.asInteger.do{|x|
							var y= 0-ampLinesFunc.value(x/ampUserView.uw, ndex)*ampUserView.uh;
							if(x==0, {
								Pen.moveTo(Point(0, y));
							}, {
								Pen.lineTo(Point(x, y));
							});
						};
					});
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
				ampTargets.do{|target|
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
		glissandi[0].gliss.controllers[0].amplitudes.syn.set(\lfoDepth, ampLfoDepthSpec.map(val)/100);
	};
	ampLfoRateElement.action= {|val|
		glissandi[0].gliss.controllers[0].amplitudes.syn.set(\lfoRate, ampLfoRateSpec.map(val+ampLfoRateAdd));
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
		var amps, newAmps, syn;
		switch(ampStack.index,
			0, {  //targets
				amps= ampTargets.collect{|target|
					var amp= target.amplitude.linlin(0, 1, ampRangeElement.value[0], ampRangeElement.value[1]);
					target.position.y= amp;
					amp;
				};
				newAmps= Array.fill(maxNumVoices, {|i|
					amps.blendAt(i.linlin(0, maxNumVoices-1, 0, ampTargets.size-1));
				})[lookup];
				glissandi[0].gliss.setAmplitudes(newAmps);
			},
			4, {  //lines
				syn= glissandi[0].gliss.controllers[0].amplitudes.syn;
				amps= Array.fill(glissandi.maxValue{|go| go.gliss.numVoices}, {|i|
					var j= lookup[i]/(maxNumVoices-1);
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
		glissTime.valueAction= glissTime.value;  //remove lag override from line
		switch(index,
			0, {  //targets
				freqUpdate.value;
			},
			1, {  //random
				freqTask= Routine({
					inf.do{|i|
						var syn= glissandi[0].gliss.controllers[0].frequencies.syn;
						maxNumVoices.do{|j|
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
						var freqs= Array.fill(maxNumVoices, {|j|
							var freq= (i+j*rfre%1).lincurve(0, 1, 0, 1, rcur);
							freq= freq.linexp(
								0,
								1,
								freqRangeSpec.map(freqRangeElement.value[0]),
								freqRangeSpec.map(freqRangeElement.value[1])
							);
							freq= scalesTunings.tune(freq, transposition.value);
							freq= masterTuning.tune(freq).clip(minFreq, maxFreq);
						});
						glissandi[0].gliss.setFrequencies(freqs[lookup]);
						freqRampRateSpec.map(freqRampRateElement.value).wait;
					};
				}).play(AppClock);
			},
			3, {  //wave
				freqTask= Routine({
					inf.do{|i|
						var wfre= freqWaveFreqSpec.map(freqWaveFreqElement.value);
						var wcur= freqWaveCurvSpec.map(freqWaveCurvElement.value);
						var freqs= Array.fill(maxNumVoices, {|j|
							var freq= sin(i+j*wfre).lincurve(-1, 1, -1, 1, wcur);
							freq= freq.linexp(
								-1,
								1,
								freqRangeSpec.map(freqRangeElement.value[0]),
								freqRangeSpec.map(freqRangeElement.value[1])
							);
							freq= scalesTunings.tune(freq, transposition.value);
							freq= masterTuning.tune(freq).clip(minFreq, maxFreq);
						});
						glissandi[0].gliss.setFrequencies(freqs[lookup]);
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
						if(freqLinesCursor!=lastCursor, {  //only when cursor moved
							lastCursor= freqLinesCursor;
							freqUpdate.value;
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

	freqNumTargetsSpec= ControlSpec(1, maxNumTargets, 'lin', 1, defaultFreqNumTargets);
	freqNumTargetsNumber.action= {|view|
		view.value= freqNumTargetsSpec.constrain(view.value);
		if(freqTargets.size<view.value, {
			while({freqTargets.size<view.value}, {
				freqTargets.add(
					(
						position: Point(0, 0),  //coordinates
						frequency: defaultFreq.explin(*[defaultFreqRange.linexp(0, 1, minFreq, maxFreq), 0, 1].flat)
					)
				);
			});
		}, {
			if(freqTargets.size>view.value, {
				while({freqTargets.size>view.value}, {
					freqTargets.pop;
				});
			});
		});
		freqTargets.do{|target, i|
			target.position.x= i.linlin(-0.5, freqTargets.size-0.5, 0, 1);
		};
		freqUpdate.value;
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
		var maxNum;  //the glissandi with the most number of voices
		var freqs;
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
				Pen.strokeColor= palette.buttonText;
				Pen.fillColor= palette.highlight;
				freqs= glissandi[0].gliss.getFrequencies[0];
				maxNum= glissandi.maxValue{|go| go.gliss.numVoices};
				freqs.do{|freq, i|
					var x= lookup[i].linlin(0, maxNumVoices-1, 2, uw-2);
					var y= freq.explin(
						freqRangeSpec.map(freqRangeElement.value[0]),
						freqRangeSpec.map(freqRangeElement.value[1]),
						0,
						0-uh
					);
					Pen.addRect(Rect.aboutPoint(Point(x, y), 1, 1));
					if(i<=32 and:{i<maxNum}, {
						Pen.stringCenteredIn(
							(i+1).asString,
							Rect.aboutPoint(Point(x.clip(3, uw-3), (y+15).min(5)), 10, 10)
						);
					});
				};
				Pen.stroke;
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
				freqTargets.do{|target|
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
				glissandi.maxValue{|go| go.gliss.numVoices}.do{|i|
					var ndex= lookup[i]/(maxNumVoices-1);
					if(i<=32, {
						freqUserView.uw.asInteger.do{|x|
							var y= 0-freqLinesFunc.value(x/freqUserView.uw, ndex)*freqUserView.uh;
							if(x==0, {
								Pen.moveTo(Point(0, y));
							}, {
								Pen.lineTo(Point(x, y));
							});
						};
					});
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
				freqTargets.do{|target|
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
		glissandi[0].gliss.controllers[0].frequencies.syn.set(\lfoDepth, freqLfoDepthSpec.map(val)/100);
	};
	freqLfoRateElement.action= {|val|
		glissandi[0].gliss.controllers[0].frequencies.syn.set(\lfoRate, freqLfoRateSpec.map(val+freqLfoRateAdd));
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

	freqUpdate= {
		var freqs, newFreqs, syn;
		switch(freqStack.index,
			0, {  //targets
				if(freqGlissButton.value==1, {
					freqs= freqTargets.collect{|target|
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
					};
					newFreqs= Array.fill(maxNumVoices, {|i|
						var freq= freqs.blendAt(i.linlin(0, maxNumVoices-1, 0, freqTargets.size-1));
						freq= scalesTunings.tune(freq, transposition.value);
						freq= masterTuning.tune(freq).clip(minFreq, maxFreq);
						freq
					})[lookup];
					glissandi[0].gliss.setFrequencies(newFreqs);
				});
			},
			4, {  //lines
				syn= glissandi[0].gliss.controllers[0].frequencies.syn;
				freqs= Array.fill(glissandi.maxValue{|go| go.gliss.numVoices}, {|i|
					var ndex= lookup[i]/(maxNumVoices-1);
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
				syn.set(\lag, 0.1);  //override gliss time slider
				syn.seti(\frequencies, 0, freqs);
			}
		);
		freqUsr.refresh;
	};

	createLookup= {
		var a= List.fill(maxNumVoices, {|i| i});
		var b= List.new;
		b.add(a.removeAt(maxNumVoices.div(2)));
		a.size.do{
			var maxDist= -inf;
			var index= -1;
			a.do{|vala, i|
				var minDist= inf;
				b.do{|valb|
					var dist= (vala-valb).abs;
					if(dist<minDist, {
						minDist= dist;
					});
				};
				if(minDist>maxDist, {
					maxDist= minDist;
					index= i;
				});
			};
			b.add(a.removeAt(index));
		};
		b.asArray;
	};
	lookup= createLookup.value;

	scalesTunings.action= {
		freqUpdate.value;
	};

	masterTuning.action= {
		freqUpdate.value;
	};

	glissTime.action= {|val|
		glissandi[0].gliss.controllers[0].frequencies.syn.set(\lag, val);
	};


	curvature.action= {|key, val|
		glissandi[0].gliss.set(key, val);
	};

	onButton.action= {|view|
		glissandi.do{|go| go.gliss.set(\on, view.value)};
	};

	glissandoTypes= {
		var list= List.new;
		list.addAll(defaultGlissTypes);
		AbstractSGlissVoice.allSubclasses.do{|class|
			if(class.type!=\File and:{class.type!=\Folder}, {
				if(list.includes(class.type).not, {
					list.add(class.type);
				});
			});
		};
		soundfiles.do{|f|
			list.add(("File_"++(f.path.basename.split($.)[0])).asSymbol);
		};
		soundfolders.do{|f, i|
			list.add(("Fold_"++f.path.basename).asSymbol);
		};
		list;
	}.value.asArray;

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
		glissandi: {|val|  //recall order below is important
			val.do{|list, i|
				var go= glissandi[i];
				var item= list.detect{|a| a.key==\typePopup}.value;
				go.fileIndex= list.detect{|a| a.key==\fileIndex}.value;
				go.addNumber.valueAction= list.detect{|a| a.key==\addNumber}.value;
				go.delNumber.valueAction= list.detect{|a| a.key==\delNumber}.value;
				go.atkNumber.valueAction= list.detect{|a| a.key==\atkNumber}.value;
				go.relNumber.valueAction= list.detect{|a| a.key==\relNumber}.value;
				go.numNumber.value= list.detect{|a| a.key==\numNumber}.value;
				go.typePopup.valueAction= go.typePopup.items.indexOf(item)
				??{("sGliss: typePopup"+item+"not found").warn; 0};
				go.volSlider.valueAction= list.detect{|a| a.key==\volSlider}.value;
			};
		}
		//any other key will default to view.valueAction= assoc.value
	);
	snapshots.include= [  //order is important
		snapshotInstrument: \sGliss,
		snapshotVersion: 1,
		masterTuning: masterTuning,
		scalesTunings: scalesTunings,
		ampSelect: {ampStack.index},
		ampNumTargetsNumber: ampNumTargetsNumber,
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
		freqNumTargetsNumber: freqNumTargetsNumber,
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
		freqLfoRateElement: freqLfoRateElement,
		curvature: curvature,
		glissTime: glissTime,
		onButton: onButton,
		glissandi: {
			glissandi.collect{|go|
				var list= List.new;
				go.select{|v| v.isKindOf(View)}.keysValuesDo{|k, v|
					if(k==\typePopup, {
						list.add((k->v.items[v.value]));
					}, {
						if(k!=\nextButton and:{k!=\randButton}, {
							list.add((k->v.value));
						});
					});
				};
				list.add((\fileIndex->go.fileIndex));
				list;
			};
		},
		mainBalanceElement: mainBalanceElement,
		mainVolume: mainVolume,
		mainReverbElement: mainReverbElement
	];

	mainBalanceElement.value= 0.5;
	mainBalanceElement.action= {|val|
		mainOutSyn.set(\pan, val*2-1);
	};

	mainVolume.action= {|val|
		mainOutSyn.set(\vol, val);
	};

	mainReverbElement.action= {|val|
		mainOutSyn.set(\verbMix, val*2-1);
	};

	//--network
	setupOscResponders= {
		oscResponders= [

			//--from sKeyBpad and sQWERTYKeyboard
			OSCFunc({|msg|
				{win.view.keyDownAction.value(win.view, msg[1].asAscii, 0)}.defer;
			}, \keyboard, recvPort:oscPort),

			//--from sKeyCpad
			OSCFunc({|msg| {onButton.valueAction= 1-onButton.value}.defer}, \on, recvPort:oscPort),

			//--from sNanokontrol
			OSCFunc({|msg|
				ampRandRateElement.value= msg[1];
				ampRampRateElement.value= msg[1];
				ampWaveRateElement.value= msg[1];
				freqRandRateElement.value= msg[1];
				freqRampRateElement.value= msg[1];
				freqWaveRateElement.value= msg[1];
			}, \rate, recvPort:oscPort),
			OSCFunc({|msg| ampRangeElement.value= [msg[1], msg[2]]}, \ampRangeMinMax, recvPort:oscPort),
			OSCFunc({|msg|  //val(float 0-1)
				var span= (ampRangeElement.value[1]-ampRangeElement.value[0])*0.5;
				var val= msg[1].clip(span, 1-span);
				ampRangeElement.value= [val-span, val+span];
			}, \ampRange, recvPort:oscPort),
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
			OSCFunc({|msg| freqLfoRateElement.value= msg[1]}, \freqLfoRate, recvPort:oscPort),
			OSCFunc({|msg| {glissTime.valueActionNorm= msg[1]}.defer}, \glissTime, recvPort:oscPort),
			OSCFunc({|msg| {curvature.valueActionNorm= [msg[1], 0]}.defer}, \curvature, recvPort:oscPort),
			OSCFunc({|msg| {mainVolume.valueAction= msg[1]}.defer}, \mainVolume, recvPort:oscPort),
			OSCFunc({|msg| mainReverbElement.value= msg[1]}, \mainReverb, recvPort:oscPort),
			OSCFunc({|msg| {mainRecord.valueAction= 1-mainRecord.value}.defer}, \mainRecord, recvPort:oscPort),

			//--from sSentograph
			OSCFunc({|msg| ampLfoRateAdd= msg[1]; ampLfoRateElement.doAction}, \ampLfoRateAdd, recvPort:oscPort),
			OSCFunc({|msg| freqLfoRateAdd= msg[1]; freqLfoRateElement.doAction}, \freqLfoRateAdd, recvPort:oscPort),
			OSCFunc({|msg| glissandi.do{|go| go.gliss.set(\amp, msg[1])}}, \amp, recvPort:oscPort),
			OSCFunc({|msg| mainBalanceElement.value= msg[1]+1/2}, \mainBalance, recvPort:oscPort),

			//--from sText/sKeyboard
			OSCFunc({|msg|
				{
					msg[1..ampTargets.size].do{|a, i|
						ampTargets[i].amplitude= a;
					};
					ampUpdate.value;
				}.defer
			}, \amplitudes, recvPort:oscPort),
			OSCFunc({|msg|
				{
					msg[1..freqTargets.size].do{|f, i|
						freqTargets[i].frequency= f.explin(minFreq, maxFreq, 0, 1);
					};
					freqUpdate.value;
				}.defer
			}, \frequencies, recvPort:oscPort),

			//--other/unused
			OSCFunc({|msg|  //index(int), val(float 0-1)
				{
					ampTargets.clipAt(msg[1]).amplitude= msg[2];
					ampUpdate.value;
				}.defer;
			}, \ampTargets, recvPort:oscPort),
			OSCFunc({|msg|  //index(int), val(float 0-1)
				{
					freqTargets.clipAt(msg[1]).frequency= msg[2];
					freqUpdate.value;
				}.defer;
			}, \freqTargets, recvPort:oscPort),
			OSCFunc({|msg|
				{glissandi[msg[1]].numNumber.valueAction= msg[2].linlin(0, 1, 0, maxNumVoices).asInteger}.defer;
			}, \numVoices, recvPort:oscPort)
		];
	};


	//--gliss
	numSpec= ControlSpec(0, maxNumVoices, 'lin', 1, 0);
	addSpec= ControlSpec(-9999, 9999, 'lin', 0, 0, "Hz");
	delSpec= ControlSpec(0, 10, 'lin', 0, 0, "s");
	atkSpec= ControlSpec(0, 30, 'lin', 0, defaultGlissAtk, "s");
	relSpec= ControlSpec(0, 60, 'lin', 0, defaultGlissRel, "s");

	findFile= {|go|
		var str= go.typePopup.items[go.typePopup.value].asString;
		var t= str.copyToEnd(str.indexOf($_)+1);  //remove File_
		var index= soundfiles.detectIndex{|f| f.path.basename.split($.)[0]==t};
		soundfiles[index].path;
	};
	findFileInFolder= {|go|
		var str= go.typePopup.items[go.typePopup.value].asString;
		var t= str.copyToEnd(str.indexOf($_)+1);  //remove Fold_
		var index= soundfolders.detectIndex{|f| f.path.basename==t};
		soundfolders[index].soundfiles.wrapAt(go.fileIndex).path;
	};
	loadBuffer= {|go, path|
		go.buffer= Buffer.readChannel(s, path, channels:[0]);
		go.folderText.string= path.basename;
		s.sync;
		go.buffer.normalize;
		s.sync;
	};

	sGliss_bus= Bus.audio(s, 2);
	glissandi.do{|go, i|
		go.put(\gliss, SGliss(maxNumVoices, outbus: sGliss_bus, args:[\on, onButton.value]));
		s.sync;
		if(i==0, {  //to save cpu only use one set of controllers
			go.gliss.controllers[0].amplitudes.syn.set(\lag, ampLag);
			go.gliss.setPannings((0..(maxNumVoices-1))[lookup].linlin(0, maxNumVoices-1, -0.9, 0.9));
			go.gliss.controllers[0].pannings.syn.set(\lfoDepth, 0.1);
		}, {
			go.gliss.controllers[0].frequencies.free;
			go.gliss.controllers[0].put(\frequencies, glissandi[0].gliss.controllers[0].frequencies);
			go.gliss.controllers[0].amplitudes.free;
			go.gliss.controllers[0].put(\amplitudes, glissandi[0].gliss.controllers[0].amplitudes);
			go.gliss.controllers[0].pannings.free;
			go.gliss.controllers[0].put(\pannings, glissandi[0].gliss.controllers[0].pannings);
		});

		go.typePopup.items_(glissandoTypes);
		go.typePopup.action= {|view|
			var bufferToFree;
			var type;
			if(go.type==\File or:{go.type==\Folder}, {
				bufferToFree= go.buffer;
				go.gliss.removeVoices(go.gliss.numVoices, {bufferToFree.free});
			}, {
				go.gliss.removeVoices(go.gliss.numVoices);
			});
			type= view.items[view.value];
			if(type.asString.beginsWith("File_"), {
				type= \File;
			}, {
				if(type.asString.beginsWith("Fold_"), {
					type= \Folder;
				});
			});
			go.type= type;
			Routine({
				switch(go.type,
					\File, {
						loadBuffer.value(go, findFile.value(go));
						go.nextButton.states_([["trig"]]);
						go.nextButton.visible= true;
						go.randButton.states_([
							["rand", palette.buttonText, palette.button],
							["rand", palette.buttonText, palette.highlight]
						]);
						go.randButton.visible= true;
						go.lockButton.visible= true;
						go.folderText.visible= true;
					},
					\Folder, {
						loadBuffer.value(go, findFileInFolder.value(go));
						go.nextButton.states_([["next"]]);
						go.nextButton.visible= true;
						go.randButton.states_([["rand"]]);
						go.randButton.visible= true;
						go.lockButton.visible= true;
						go.folderText.visible= true;
					},
					{
						go.nextButton.visible= false;
						go.randButton.visible= false;
						go.lockButton.visible= false;
						go.folderText.visible= false;
					}
				);
				go.numNumber.valueAction= go.numNumber.value.max(1);  //at least one voice
			}).play(AppClock);
		};
		go.typePopup.value= go.typePopup.items.indexOf(go.type);
		go.nextButton.visible= false;
		go.randButton.visible= false;
		go.lockButton.visible= false;
		go.folderText.visible= false;
		go.volSlider.action= {|view|
			go.gliss.set(\vol, (view.value*1.25).ampdb.max(-90));
		};
		go.numNumber.action= {|view|
			var diff;
			view.value= numSpec.constrain(view.value);
			diff= view.value-go.gliss.numVoices;
			if(diff!=0, {
				if(diff>0, {
					go.gliss.addVoices(diff, go.type, [\buf, go.buffer]);
				}, {
					go.gliss.removeVoices(diff.abs);
				});
				ampUsr.refresh;
				freqUsr.refresh;
			});
		};
		go.addNumber.action= {|view|
			view.value= addSpec.constrain(view.value);
			go.gliss.set(\add, view.value);
		};
		go.delNumber.action= {|view|
			view.value= delSpec.constrain(view.value);
			go.gliss.set(\del, view.value);
		};
		go.atkNumber.action= {|view|
			view.value= atkSpec.constrain(view.value);
			go.gliss.set(\atk, view.value);
		};
		go.relNumber.action= {|view|
			view.value= relSpec.constrain(view.value);
			go.gliss.set(\rel, view.value);
		};
		go.nextButton.action= {|view, mod|
			if(go.type==\File, {
				go.gliss.set(\trig, 1);
			}, {
				if(go.type==\Folder, {
					if(mod.isShift, {  //shift click step backwards
						go.fileIndex= go.fileIndex-1;
					}, {  //no shift one step forward
						go.fileIndex= go.fileIndex+1;
					});
					Routine({
						var oldBuffer= go.buffer;
						loadBuffer.value(go, findFileInFolder.value(go));
						go.gliss.set(\buf, go.buffer, \trig, 1);
						oldBuffer.free;
					}).play(AppClock);
				});
			});
		};
		go.randButton.action= {|view, mod|
			if(go.type==\File, {
				go.gliss.set(\loop, 1-view.value);  //wait a random time and then retrigger
			}, {
				if(go.type==\Folder, {
					if(mod.isShift, {  //shift click jump back or forth a few steps
						go.fileIndex= go.fileIndex+(5.linrand+1*[1, -1].choose);
					}, {  //no shift random selection
						go.fileIndex= 9999.rand;
					});
					Routine({
						var oldBuffer= go.buffer;
						loadBuffer.value(go, findFileInFolder.value(go));
						go.gliss.set(\buf, go.buffer, \trig, 1);
						oldBuffer.free;
					}).play(AppClock);
				});
			});
		};
		go.lockButton.action= {|view, mod|
			if(go.type==\File or:{go.type==\Folder}, {
				go.gliss.set(\rateBlend, 1-view.value*2-1);
			});
		};

		if(i==0, {
			go.numNumber.valueAction= 4;
			go.volSlider.valueAction= 0.8;
		}, {
			go.volSlider.valueAction= 0;
		});
		go.atkNumber.valueAction= atkSpec.default;
		go.relNumber.valueAction= relSpec.default;
	};
	~glissandi= glissandi;

	mainOutSyn= SynthDef(\glissMainOut, {|out= 0, pan= 0, vol= 0, verbMix= -1|
		var snd= In.ar(\sGliss_bus.ir, 2);
		snd= Balance2.ar(snd[0], snd[1], pan.lag(0.03));
		snd= snd*vol.dbamp.lag;
		snd= XFade2.ar(snd, GVerb.ar(snd, 90, 4)*0.75, verbMix.lag);
		Out.ar(out, Limiter.ar(snd));
	}).play(args: [\sGliss_bus, sGliss_bus], addAction: \addToTail);

	{
		ampRandProbElement.value= 0.1;
		ampRandRateElement.value= ampRandRateSpec.unmap(ampRandRateSpec.default);
		ampRampFreqElement.value= ampRampFreqSpec.unmap(ampRampFreqSpec.default);
		ampRampRateElement.value= ampRampRateSpec.unmap(ampRampRateSpec.default);
		ampRampCurvElement.value= ampRampCurvSpec.unmap(ampRampCurvSpec.default);
		ampWaveFreqElement.value= ampWaveFreqSpec.unmap(ampWaveFreqSpec.default);
		ampWaveRateElement.value= ampWaveRateSpec.unmap(ampWaveRateSpec.default);
		ampWaveCurvElement.value= ampWaveCurvSpec.unmap(ampWaveCurvSpec.default);

		ampLinesPopup.value= ampLinesPopup.items.detectIndex{|x| x.asSymbol=='loop on'};
		ampNumTargetsNumber.valueAction= ampNumTargetsSpec.default;
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

		freqLinesPopup.value= freqLinesPopup.items.detectIndex{|x| x.asSymbol=='sync amp'};
		freqNumTargetsNumber.valueAction= freqNumTargetsSpec.default;
		freqGlissButton.valueAction= 1;
		freqLfoDepthElement.value= freqLfoDepthSpec.unmap(freqLfoDepthSpec.default);
		freqLfoRateElement.value= freqLfoRateSpec.unmap(freqLfoRateSpec.default);
		freqRangeElement.value= defaultFreqRange;

		curvature.valueAction= #[-4, 0];
		glissTime.valueAction= defaultFreqGlissTime;
		mainVolume.valueAction= defaultMainVolume;
		setupOscResponders.value;
		ampUsrAnim.animate= true;
		freqUsrAnim.animate= true;
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
