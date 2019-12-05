//f.olofsson & t.ungvary 2019
//port of fIGMA

(
//--settings
var maxSustain= 4;  //seconds
var maxNumSteps= 999;  //patterns
var maxNumVoices= 16;  //additional voices
var maxChordPitch= 24;  //range in semitones +/-
var maxEntryDelay= 1;  //seconds
var winRect= Rect(242, 242, 1150, 750);  //x, y, w, h
var palette= SGUI.palette((highlight: Color.green(2/3, 0.5)));
var fnt= SGUI.font;
var fnt2= SGUI.font.copy.size_(10);
var fps= 25;
var scales= [  //more can be added. see Scale.directory
	Scale.bartok,
	Scale.chinese,
	Scale.chromatic,
	Scale.diminished,
	Scale.dorian,
	Scale.harmonicMinor,
	Scale.ionian,
	Scale.lydian,
	Scale.majorPentatonic,
	Scale.minorPentatonic
];
var lvProgramSelectKeys= #[$Q, $W, $E, $R, $T];
var avProgramSelectKeys= #[$Y, $U, $I, $O, $P];
var snapshotKeys= #[  //more can be added
	[$A, $S, $D, $F, $G, $H, $J, $K],
	[$Z, $X, $C, $V, $B, $N, $M, $,]
];
var bankKeys= #[  //more can be added
	$1, $2, $3, $4, $5, $6, $7, $8, $9
];
var snapshotFiles= [  //name and file (both can be changed)
	\Bank1 -> "sStream_snapshots_Bank1.scd",
	\Bank2 -> "sStream_snapshots_Bank2.scd",
	\Bank3 -> "sStream_snapshots_Bank3.scd",
	\Bank4 -> "sStream_snapshots_Bank4.scd",
	\Bank5 -> "sStream_snapshots_Bank5.scd",
	\Bank6 -> "sStream_snapshots_Bank6.scd",
	\Bank7 -> "sStream_snapshots_Bank7.scd",
	\Bank8 -> "sStream_snapshots_Bank8.scd",
	\Bank9 -> "sStream_snapshots_Bank9.scd"
];

//--defaults
var defaultAttack= 0.1;
var defaultRelease= 1;
var defaultPlug= "Pianoteq*STAGE";  //wildcard
var defaultScale= Scale.chromatic;
var defaultOctave= 5;
var defaultSustain= 0.5;  //seconds
var defaultAVFalloutVoices= 5;  //percent
var defaultAVFalloutChords= 0;  //percent
var defaultMainVolume= 0.0;  //dB
var defaultMidiOut= 0;  //index in MIDIClient.destinations

var patterns, readPatternsFromDisk, writeUserPatternsToDisk;
var chords, readChordsFromDisk, writeUserChordsToDisk;

s.options.numWireBufs= s.options.numWireBufs.max(128);
s.options.memSize= s.options.memSize.max(2**16);
s.latency= 0.08;
s.waitForBoot{

	//--functions and objects
	var usrPadding= Size(20, 6);  //left, top+bottom
	var strWidth= "127".bounds(fnt2).width;
	var strHeight= "127".bounds(fnt2).height;

	var lvPitchesArray, lvPitchesIndex, lvPitchesSelection;
	var lvPitchesUpdate, lvPitchesClosestIndex;
	var lvPitchesUsrAnimRedraw= false;
	var lvVelocitiesArray, lvVelocitiesIndex, lvVelocitiesSelection;
	var lvVelocitiesUpdate, lvVelocitiesClosestIndex;
	var lvVelocitiesUsrAnimRedraw= false;

	var avPitchesArray, avPitchesBuffer= 0!maxNumVoices;
	var avDelaysArray, avDelaysBuffer= (1..maxNumVoices).normalize*maxEntryDelay;
	var avVelocitiesArray, avVelocitiesBuffer= 0.7!maxNumVoices;
	var avIndex;
	var avPitchesClickPoint;
	var avPitchesClosestIndex, avPitchesSetClosestIndex;
	var avPitchesUsrAnimRedraw= false;
	var avVelocitiesClosestIndex;
	var avVelocitiesUsrAnimRedraw= false;

	var createStream;
	var clock;
	var midiOut;
	var oscPort= SInputs.destinations.sStream.port;
	var setupOscResponders, oscResponders;
	var routineGui;
	var lvVst, avVst;
	var mainOutSyn;
	var sStream_bus;

	//--gui
	var onElement= SGUIelement();
	var attackElement= SGUIelement();
	var attackSpec= ControlSpec(0, 99, 'lin', 0.1, defaultAttack, "s");
	var releaseElement= SGUIelement();
	var releaseSpec= ControlSpec(0, 99, 'lin', 0.1, defaultRelease, "s");
	var pitchElement= SGUIelement();  //x
	var rateElement= SGUIelement();  //y
	var velocityElement= SGUIelement();  //z

	var metronomeOnElement= SGUIelement();
	var metronomeElement= SGUIelement();
	var metronomeSpec= ControlSpec(30, 300, 'lin', 0, 120, "bpm");
	var rateScaleElement= SGUIelement();
	var rateScaleSpec= ControlSpec(1, 0, 'lin', 0, 0.5);
	var rateMultiplierElement= SGUIelement();
	var rateMultiplierSpec= ControlSpec(0, 3, 'lin', 1, 0);

	var lvOnElement= SGUIelement();
	var lvVstEditorButton, lvVstProgramPopup;
	var lvProgramSelectButtons= List.new;
	var lvProgramSelectPopups= List.new;
	var lvScaleList;
	var lvPitchBendElement= SGUIelement();
	var lvPitchBendSpec= ControlSpec(0, 1200, 'lin', 1, 200, "cents");
	var lvPitchBendOnElement= SGUIelement();
	var lvSustainElement= SGUIelement();
	var lvSustainSpec= ControlSpec(0.01, maxSustain, 1, 0, defaultSustain);
	var lvSustainOnElement= SGUIelement();
	var lvScaleButtonElement= SGUIelement();
	var lvChromTranspElement= SGUIelement();
	var lvChromTranspSpec= ControlSpec(-63, 63, 'lin', 1, 0, "semitones");
	var lvOctaveElement= SGUIelement();
	var lvOctaveSpec= ControlSpec(0, 10, 'lin', 1, defaultOctave, "octaves");
	var lvPatternsPopup;
	var lvPatternSettings, pswin;
	var lvSyncButton;
	var lvPitchesOnButtonElement= SGUIelement();
	var lvPitchesOnButtonSpec= ControlSpec(0, 3, 'lin', 1, 0);
	var lvPitchesNumber;
	var lvPitchesLoopPopup;
	var lvPitchMinMaxRangeElement= SGUIelementRange();
	var lvPitchesUsrBack, lvPitchesUsrAnim;
	var lvPitchesRangeElement= SGUIelementRange();
	var lvVelocitiesOnButtonElement= SGUIelement();
	var lvVelocitiesOnButtonSpec= ControlSpec(0, 3, 'lin', 1, 0);
	var lvVelocitiesNumber;
	var lvVelocitiesLoopPopup;
	var lvVolumeElement= SGUIelement();
	var lvVelocitiesUsrBack, lvVelocitiesUsrAnim;
	var lvVelocitiesRangeElement= SGUIelementRange();

	var avOnElement= SGUIelement();
	var avVstEditorButton, avVstProgramPopup;
	var avProgramSelectButtons= List.new;
	var avProgramSelectPopups= List.new;
	var avScaleList;
	var avPitchBendElement= SGUIelement();
	var avPitchBendSpec= ControlSpec(0, 2400, 'lin', 1, 0, "cents");
	var avPitchBendOnElement= SGUIelement();
	var avSustainElement= SGUIelement();
	var avSustainSpec= ControlSpec(0.01, maxSustain, 1, 0, defaultSustain);
	var avSustainOnElement= SGUIelement();
	var avPitchesOnButtonElement= SGUIelement();
	var avPitchesOnButtonSpec= ControlSpec(0, 3, 'lin', 1, 0);
	var avChromTranspElement= SGUIelement();
	var avChromTranspSpec= ControlSpec(-63, 63, 'lin', 1, 0, "semitones");
	var avOctaveElement= SGUIelement();
	var avOctaveSpec= ControlSpec(0, 10, 'lin', 1, defaultOctave, "octaves");
	var avChordsPopup;
	var avChordSettings, cswin;
	var avReorderButton;
	var avVoicesNumberElement= SGUIelement();
	var avVoicesNumberSpec= ControlSpec(0, maxNumVoices, 'lin', 1, 0);
	var avFollowStepText;
	var avFollowStepNumberElement= SGUIelement();
	var avFollowStepNumberSpec= ControlSpec(0, 24, 'lin', 0, 1);
	var avFollowPopupElement= SGUIelement();
	var avFollowPopupSpec= ControlSpec(0, 4, 'lin', 0, 0);
	var avPitchMinMaxRangeElement= SGUIelementRange();
	var avPitchesUsrBack, avPitchesUsrAnim;
	var avVolumeElement= SGUIelement();
	var avVelocitiesUsrBack, avVelocitiesUsrAnim;
	var avEntryDelayElement= SGUIelement();
	var avDisplacementElement= SGUIelement();
	var avFalloutVoicesElement= SGUIelement();
	var avFalloutVoicesSpec= ControlSpec(0, 100, 'lin', 1, defaultAVFalloutVoices, "%");
	var avFalloutChordsElement= SGUIelement();
	var avFalloutChordsSpec= ControlSpec(0, 100, 'lin', 1, defaultAVFalloutChords, "%");

	var snapshots;
	var masterTuning;
	var mainVolume;
	var mainRecord;
	var backgroundImage;
	var win= Window("sStream", winRect);
	win.layout= GridLayout.rows(
		[
			VLayout(

				//--sentograph (3d sensor)
				HLayout(
					StaticText().string_("Pitch (X)").fixedWidth_(70),
					pitchElement.addView(Slider().orientation_(\horizontal))  //Sentro X-axis (c_2), Sento-PitchBend (c_2)
				),
				HLayout(
					StaticText().string_("Rate (Y)").fixedWidth_(70),  //aka entry delay
					rateElement.addView(Slider().orientation_(\horizontal))  //Sento Y-axis (c_1)
				),
				HLayout(
					StaticText().string_("Velocity (Z)").fixedWidth_(70),
					velocityElement.addView(Slider().orientation_(\horizontal))  //Sento Z-axis (c_3)
				)
			),

			VLayout(
				HLayout(
					onElement.addView(Button().states_([
						["Stream Off", palette.buttonText, palette.button],
						["Stream On", palette.buttonText, palette.highlight]
					])),
					SGUI.shrink(StaticText().string_("Attack")),
					attackElement.addView(NumberBox().scroll_step_(0.1), attackSpec).fixedWidth_(55),
					SGUI.shrink(StaticText().string_("Release")),
					releaseElement.addView(NumberBox().scroll_step_(0.1), releaseSpec).fixedWidth_(55)
				),
				HLayout(
					StaticText().string_("Metronome").fixedWidth_(70),
					metronomeElement.addView(Slider().orientation_(\horizontal)),  //Metronome Speed (c_11)
					metronomeElement.addView(NumberBox().fixedWidth_(55), metronomeSpec),
					metronomeOnElement.addView(Button().states_([  //metro on/off (b_174)
						["  Metro", palette.buttonText, palette.button],
						["•Metro", palette.buttonText, palette.highlight]
					]))
				),
				HLayout(
					StaticText().string_("Rate Scale").fixedWidth_(70),
					rateScaleElement.addView(Slider().orientation_(\horizontal)),  //minimum entry-delay (c_11)
					rateScaleElement.addView(NumberBox().fixedWidth_(55), rateScaleSpec),
					rateMultiplierElement.addView(Button().states_([  //e-del maximum (bgr_6)
						["* 0.50", palette.buttonText, palette.button],
						["* 0.75", palette.buttonText, palette.button],
						["* 1.00", palette.buttonText, palette.button],
						["* 0.75", palette.buttonText, palette.button]
					]), rateMultiplierSpec)
				)
			)
		],
		[
			//--LV
			VLayout(
				HLayout(
					lvOnElement.addView(Button().states_([  //LV on/off (b_73)
						["  Leading Voice", palette.buttonText, palette.button],
						["•Leading Voice", palette.buttonText, palette.highlight]
					])),
					lvVstEditorButton= Button().states_([
						["LVVst:", palette.buttonText, palette.button]
					]),
					lvVstProgramPopup= PopUpMenu().background_(palette.highlight.complementary)  //sound LV (bgr_1)
				),
				HLayout(
					*(lvProgramSelectKeys.collect{|chr|
						var but= Button().states_([
							[chr.asString, palette.buttonText, palette.button],
							[chr.asString, palette.buttonText, palette.highlight.complementary]
						]).fixedWidth_(25);
						var pop= PopUpMenu();
						lvProgramSelectButtons.add(but);
						lvProgramSelectPopups.add(pop);
						[but, pop];
					}.flat)
				),
				HLayout(
					VLayout(
						HLayout(
							lvScaleList= ListView().maxSize_(Size(125, 115)).background_(Color.clear),
							VLayout(
								HLayout(
									lvPitchBendElement.addView(Slider().orientation_(\horizontal)),  //Pitchbend range (c_17)
									lvPitchBendElement.addView(NumberBox().decimals_(0).fixedWidth_(55), lvPitchBendSpec),
									lvPitchBendOnElement.addView(Button().states_([  //LV PB on/off (b_32)
										["  LV Bend", palette.buttonText, palette.button],
										["•LV Bend", palette.buttonText, palette.highlight]
									]))
								),
								HLayout(
									lvSustainElement.addView(Slider().orientation_(\horizontal)),  //Duration (c_10)
									lvSustainElement.addView(NumberBox().fixedWidth_(55), lvSustainSpec),  //Duration (c_10)
									lvSustainOnElement.addView(Button().states_([  //sustain on/off (b_175)
										["  LV Sustain", palette.buttonText, palette.button],
										["•LV Sustain", palette.buttonText, palette.highlight]
									]))
								),
								HLayout(
									lvScaleButtonElement.addView(Button().states_([
										["  LV Scale Pattern", palette.buttonText, palette.button],
										["•LV Scale Pattern", palette.buttonText, palette.highlight]
									])),
									SGUI.shrink(StaticText().string_("LV Transposition")),
									lvChromTranspElement.addView(NumberBox().decimals_(0).fixedWidth_(55), lvChromTranspSpec),  //LV-Transposition (bgr_3)
									SGUI.shrink(StaticText().string_("LV Octave")),
									lvOctaveElement.addView(NumberBox().decimals_(0).fixedWidth_(55), lvOctaveSpec)
								)
							)
						)
					)
				),

				//--LV pattern
				HLayout(
					SGUI.shrink(StaticText().string_("LV Patterns")),
					lvPatternsPopup= PopUpMenu(),
					(lvPatternSettings= SGUIsettings()).view,
					lvSyncButton= Button().states_([
						["LV Sync Patterns", palette.buttonText, palette.button]
					])
				),
				HLayout(
					StaticText().string_("LV Range").fixedWidth_(60),
					lvPitchesOnButtonElement.addView(Button().states_([  //PitchShiftButton-rhy (bgr_34)
						["LV Pitch Pattern Off", palette.buttonText, palette.button],
						["LV Pitch Pattern On ", palette.buttonText, palette.highlight],
						["LV Pitch Pattern Mix", palette.buttonText, Color.green(1, 1/3)],
						["LV Pitch Pattern Add", palette.buttonText, Color.green(1, 1/3)]
					]), lvPitchesOnButtonSpec).fixedWidth_(145),
					StaticText().string_("LV # Pitches").fixedWidth_(83),
					lvPitchesNumber= NumberBox().fixedWidth_(55),
					lvPitchesLoopPopup= PopUpMenu().items_(
						#["Loop forward", "Loop backward", "Loop palindrome", "Stutter", "Scramble"]
					)
				),
				HLayout(
					lvPitchMinMaxRangeElement.addView(RangeSlider().orientation_(\vertical).maxWidth_(22)),  //minimum Pitch, maximum Pitch (c_9, c_12)
					[StackLayout(
						lvPitchesUsrBack= UserView().minSize_(Size(500, 100)),
						lvPitchesUsrAnim= UserView().minSize_(Size(500, 100))
					).mode_(\stackAll), stretch:1]
				),
				HLayout(
					View().fixedWidth_(usrPadding.width*2),
					lvPitchesRangeElement.addView(RangeSlider().orientation_(\horizontal))
				),

				HLayout(
					StaticText().string_("LV Volume").fixedWidth_(60),
					lvVelocitiesOnButtonElement.addView(Button().states_([  //AutoBeat Velocity Modulation (b_33)
						["LV Velocity Pattern Off", palette.buttonText, palette.button],
						["LV Velocity Pattern On ", palette.buttonText, palette.highlight],
						["LV Velocity Pattern Mix", palette.buttonText, Color.green(1, 1/3)],
						["LV Velocity Pattern Add", palette.buttonText, Color.green(1, 1/3)]
					]), lvVelocitiesOnButtonSpec).fixedWidth_(145),
					StaticText().string_("LV # Velocities").fixedWidth_(83),
					lvVelocitiesNumber= NumberBox().fixedWidth_(55),
					lvVelocitiesLoopPopup= PopUpMenu().items_(
						#["Loop forward", "Loop backward", "Loop palindrome", "Stutter", "Scramble"]
					)
				),
				HLayout(
					lvVolumeElement.addView(Slider().orientation_(\vertical).maxWidth_(22)),  //LV Loudness (c_14)
					[StackLayout(
						lvVelocitiesUsrBack= UserView().minSize_(Size(500, 100)),
						lvVelocitiesUsrAnim= UserView().minSize_(Size(500, 100))
					).mode_(\stackAll), stretch:1]
				),
				HLayout(
					View().fixedWidth_(usrPadding.width*2),
					lvVelocitiesRangeElement.addView(RangeSlider().orientation_(\horizontal))
				)
			),

			//--AV
			VLayout(
				HLayout(
					avOnElement.addView(Button().states_([  //AV on/off (b_72)
						["  Additional Voices", palette.buttonText, palette.button],
						["•Additional Voices", palette.buttonText, palette.highlight]
					])),
					avVstEditorButton= Button().states_([
						["AVVst:", palette.buttonText, palette.button]
					]),
					avVstProgramPopup= PopUpMenu().background_(palette.highlight.complementary)  //sound AV (bgr_7)
				),
				HLayout(
					*(avProgramSelectKeys.collect{|chr|
						var but= Button().states_([
							[chr.asString, palette.buttonText, palette.button],
							[chr.asString, palette.buttonText, palette.highlight.complementary]
						]).fixedWidth_(25);
						var pop= PopUpMenu();
						avProgramSelectButtons.add(but);
						avProgramSelectPopups.add(pop);
						[but, pop];
					}.flat)
				),
				HLayout(
					VLayout(
						HLayout(
							avScaleList= ListView().maxSize_(Size(125, 115)).background_(Color.clear),
							VLayout(
								HLayout(
									avPitchBendElement.addView(Slider().orientation_(\horizontal)),  //Pitchbend range (c_17)
									avPitchBendElement.addView(NumberBox().decimals_(0).fixedWidth_(55), avPitchBendSpec),
									avPitchBendOnElement.addView(Button().states_([  //LV PB on/off (b_176)
										["  AV Bend", palette.buttonText, palette.button],
										["•AV Bend", palette.buttonText, palette.highlight]
									]))
								),
								HLayout(
									avSustainElement.addView(Slider().orientation_(\horizontal)),  //Duration (c_10)
									avSustainElement.addView(NumberBox().fixedWidth_(55), avSustainSpec),  //Duration (c_10)
									avSustainOnElement.addView(Button().states_([  //sustain on/off (b_175)
										["  AV Sustain", palette.buttonText, palette.button],
										["•AV Sustain", palette.buttonText, palette.highlight]
									]))
								),
								HLayout(
									avPitchesOnButtonElement.addView(Button().states_([
										["AV Pitch Pattern Off", palette.buttonText, palette.button],
										["AV Pitch Pattern On ", palette.buttonText, palette.highlight],
										["AV Pitch Pattern Mix", palette.buttonText, Color.green(1, 1/3)],
										["AV Pitch Pattern Add", palette.buttonText, Color.green(1, 1/3)]
									]), avPitchesOnButtonSpec),
									SGUI.shrink(StaticText().string_("AV Transposition")),
									avChromTranspElement.addView(NumberBox().decimals_(0).fixedWidth_(55), avChromTranspSpec),  //AV-Transposition (bgr_29)
									SGUI.shrink(StaticText().string_("AV Octave").fixedWidth_(55)),
									avOctaveElement.addView(NumberBox().decimals_(0).fixedWidth_(55), avOctaveSpec)
								)
							)
						)
					)
				),
				VLayout(
					HLayout(
						SGUI.shrink(StaticText().string_("AV Chords")),
						avChordsPopup= PopUpMenu(),
						(avChordSettings= SGUIsettings()).view,
						avReorderButton= Button().states_([
							["AV Reorder Chord", palette.buttonText, palette.button]
						])
					),
					HLayout(
						StaticText().string_("AV Range").fixedWidth_(60),
						SGUI.shrink(StaticText().string_("AV # Voices")),
						avVoicesNumberElement.addView(NumberBox().fixedWidth_(55), avVoicesNumberSpec),
						View(),
						avFollowStepText= SGUI.shrink(StaticText().string_("AV Step amount")),
						avFollowStepNumberElement.addView(NumberBox().fixedWidth_(55), avFollowStepNumberSpec),
						avFollowPopupElement.addView(PopUpMenu().items_(#[
							"= Follow Parallel", "X Follow Opposite", "• Follow Fixed", "^ Follow Up", "v Follow Down"
						]).fixedWidth_(161), avFollowPopupSpec)
					),
					HLayout(
						avPitchMinMaxRangeElement.addView(RangeSlider().orientation_(\vertical)),
						[StackLayout(
							avPitchesUsrBack= UserView().minSize_(Size(250, 100)),
							avPitchesUsrAnim= UserView().minSize_(Size(250, 100))
						).mode_(\stackAll), stretch:1],
						avVolumeElement.addView(Slider().orientation_(\vertical).maxWidth_(22)),  //AV Loudness (c_13)
						[StackLayout(
							avVelocitiesUsrBack= UserView().minSize_(Size(250, 100)),
							avVelocitiesUsrAnim= UserView().minSize_(Size(250, 100))
						).mode_(\stackAll), stretch:1]
					),
					HLayout(
						VLayout(
							HLayout(
								StaticText().string_("AV Entry Delay").fixedWidth_(103),
								avEntryDelayElement.addView(Slider().orientation_(\horizontal))
							),
							HLayout(
								StaticText().string_("AV Displacement").fixedWidth_(103),
								avDisplacementElement.addView(Slider().orientation_(\horizontal))
							)
						),
						VLayout(
							HLayout(
								StaticText().string_("AV Fallout Voices").fixedWidth_(103),
								avFalloutVoicesElement.addView(Slider().orientation_(\horizontal)),
								avFalloutVoicesElement.addView(NumberBox().fixedWidth_(55), avFalloutVoicesSpec),
								SGUI.shrink(StaticText().string_("%"))
							),
							HLayout(
								StaticText().string_("AV Fallout Chords").fixedWidth_(103),
								avFalloutChordsElement.addView(Slider().orientation_(\horizontal)),
								avFalloutChordsElement.addView(NumberBox().fixedWidth_(55), avFalloutChordsSpec),
								SGUI.shrink(StaticText().string_("%"))
							)
						)
					)
				),

				//--preset section
				(
					snapshots= SGUIsnapshots(SInstruments.snapshotsDir, snapshotFiles, bankKeys, snapshotKeys, \sStream)
				).view,

				//--output section
				HLayout(
					StaticText().string_("Output"),
					(masterTuning= SGUImasterTuning(220, 880)).view
				),
				HLayout(
					(mainVolume= SGUIvolume()).view,
					SGUIcpu(s).view,
					(mainRecord= SGUIrecord(s, SInstruments.recordingsDir, "sStream_")).view
				)
			)
		]
	);
	SGUI.report(win);
	SGUI.adapt(win);

	backgroundImage= Image(winRect.width, winRect.height).draw({|img|
		Pen.width= 6;
		Pen.fillColor= palette.highlight;
		Pen.strokeColor= palette.button;
		50.do{|i|
			Pen.moveTo(Point(img.width*0.86+i, i/20*img.height));
			Pen.quadCurveTo(
				Point(img.width*0.9-(i*25), img.height/2+(i*9)),
				Point(img.width/5+i, i/25*img.height).rotate(0-i/19)
			);
			Pen.draw(4);
		};
	});
	win.view.setBackgroundImage(backgroundImage, 1, 0.1);
	win.view.keyDownAction= {|view, chr, mod, unicode, keycode, key|
		case
		{unicode==13} {win.view.focus}
		{chr==Char.space} {onElement.valueAction= 1-onElement.value}
		{lvProgramSelectKeys.includes(chr.toUpper)} {
			lvProgramSelectButtons[lvProgramSelectKeys.indexOf(chr.toUpper)].valueAction= 1;
			{lvProgramSelectButtons[lvProgramSelectKeys.indexOf(chr.toUpper)].value= 0}.defer(0.2);
		}
		{avProgramSelectKeys.includes(chr.toUpper)} {
			avProgramSelectButtons[avProgramSelectKeys.indexOf(chr.toUpper)].valueAction= 1;
			{avProgramSelectButtons[avProgramSelectKeys.indexOf(chr.toUpper)].value= 0}.defer(0.2);
		}
		{keycode==124} {lvOctaveElement.value= lvOctaveSpec.unmap(lvOctaveSpec.map(lvOctaveElement.value)+1)}  //right
		{keycode==123} {lvOctaveElement.value= lvOctaveSpec.unmap(lvOctaveSpec.map(lvOctaveElement.value)-1)}  //left
		{keycode==125} {lvChromTranspElement.value= lvChromTranspSpec.unmap(lvChromTranspSpec.map(lvChromTranspElement.value)-1)}  //down
		{keycode==126} {lvChromTranspElement.value= lvChromTranspSpec.unmap(lvChromTranspSpec.map(lvChromTranspElement.value)+1)}  //up
		{snapshots.keyDownAction(chr, mod)};
	};
	win.view.minSize= Size(winRect.width, 678);
	win.onClose= {
		NetAddr.localAddr.sendMsg(\closed, \sStream);
		if(pswin.notNil, {pswin.close});
		if(cswin.notNil, {cswin.close});
		routineGui.stop;
		Pdef(\sStream).stop;
		oscResponders.do{|x| x.free};
		//stream.stop;
		mainOutSyn.release(1);
		backgroundImage.free;
		{
			sStream_bus.free;
			mainOutSyn.free;
		}.defer(1);
	};
	CmdPeriod.doOnce({
		backgroundImage.free;
		sStream_bus.free;
		sStream_bus= nil;
		mainOutSyn= nil;
	});


	onElement.action= {|val|
		mainOutSyn.set(\on, val);
		if(val==1, {
			Pdef(\sStream).play(clock, quant:1);
		}, {
			Pdef(\sStream).stop;
		});
	};
	attackElement.value= attackSpec.unmap(defaultAttack);
	attackElement.action= {|val|
		mainOutSyn.set(\atk, attackSpec.map(val));
	};
	releaseElement.value= releaseSpec.unmap(defaultRelease);
	releaseElement.action= {|val|
		mainOutSyn.set(\rel, releaseSpec.map(val));
	};

	pitchElement.value= 0.5;
	pitchElement.action= {|val|
		var lvLo= lvPitchMinMaxRangeElement.value[0].linlin(0, 1, -63.5, 63.5);
		var lvHi= lvPitchMinMaxRangeElement.value[1].linlin(0, 1, -63.5, 63.5);
		var lvVal= val.linlin(0, 1, lvLo, lvHi);
		var lb, ab;
		Pdefn(\sStream_note, lvVal);
		if(lvPitchBendOnElement.value>0, {
			lb= val-0.5*lvPitchBendElement.value*(lvPitchBendSpec.maxval/2400)+0.5;
			lvVst.set('Pitch Bend', lb);
			if(midiOut.notNil, {
				midiOut.bend(0, lb*16383);
			});
		});
		if(avPitchBendOnElement.value>0, {
			ab= val-0.5*avPitchBendElement.value*(avPitchBendSpec.maxval/2400)+0.5;
			avVst.set('Pitch Bend', ab);
			if(midiOut.notNil, {
				midiOut.bend(1, ab*16383);
			});
		});
	};

	rateElement.value= 0.5;
	rateElement.action= {|val|
		var max= #[0.5, 0.75, 1, 0.75][rateMultiplierSpec.map(rateMultiplierElement.value)];
		val= val.linlin(0, 1, 0, rateScaleSpec.map(rateScaleElement.value)*max);
		val= val.lincurve(0, 1, 0.032, 1.744, 2);
		Pdefn(\sStream_dur, val);
	};

	velocityElement.value= 0;
	velocityElement.action= {|val|
		Pdefn(\sStream_velocity, val);
	};

	metronomeOnElement.action= {|val|
		Pdefn(\sStream_metronomeOn, val);
		SInputs.destinations[\sGreybox].sendMsg(\led, \metroOn, val);
	};
	metronomeElement.value= metronomeSpec.unmap(metronomeSpec.default);
	metronomeElement.action= {|val|
		Pdefn(\sStream_bpm, metronomeSpec.map(val));
	};

	rateScaleElement.action= {|val|
		rateElement.valueAction= rateElement.value;
	};
	rateMultiplierElement.action= {|val|
		rateElement.valueAction= rateElement.value;
	};


	//--LV
	lvOnElement.action= {|val|
		SInputs.destinations[\sGreybox].sendMsg(\led, \lvOn, val);
	};

	lvVstEditorButton.action= {|view|
		lvVst.gui;
	};
	lvVstProgramPopup.action= {|view|
		lvVst.program= view.value;
	};

	lvProgramSelectButtons.do{|but, i|
		but.action= {|view|
			lvVstProgramPopup.valueAction= lvProgramSelectPopups[i].value;
		};
	};

	lvScaleList.items= scales.collect{|x| x.name.asSymbol};
	lvScaleList.value= lvScaleList.items.indexOf(defaultScale.name.asSymbol);
	lvScaleList.action= {|view|
		Pdefn(\sStream_lvScale, scales[view.value]);
		lvPitchesUpdate.value;
	};

	lvPitchBendOnElement.action= {|val|
		SInputs.destinations[\sGreybox].sendMsg(\led, \lvBendOn, val);
	};

	lvSustainElement.action= {|val|
		Pdefn(\sStream_lvSustain, lvSustainSpec.map(val));
		lvPitchesUsrAnimRedraw= true;
	};
	lvSustainOnElement.action= {|val|
		lvVst.set('Sustain Pedal', val);
		SInputs.destinations[\sGreybox].sendMsg(\led, \sustain, val);
	};

	lvScaleButtonElement.action= {|val|
		lvPitchesUpdate.value;
	};
	lvChromTranspElement.action= {|val|
		Pdefn(\sStream_lvCstranspose, lvChromTranspSpec.map(val).asInteger);
	};
	lvOctaveElement.action= {|val|
		Pdefn(\sStream_lvOctave, lvOctaveSpec.map(val).asInteger);
	};

	lvPatternsPopup.action= {|view|
		var o= patterns[view.value];
		var pitches= o["pitches"].collect{|x| x.asFloat};
		var pstart= o["prange"][0].asInteger;
		var pend= o["prange"][1].asInteger;
		var psize= pitches.size;
		var velocities= o["velocities"].collect{|x| x.asFloat};
		var vstart= o["vrange"][0].asInteger;
		var vend= o["vrange"][1].asInteger;
		var vsize= velocities.size;

		lvPitchesNumber.value= psize;
		lvPitchesArray= pitches;
		lvPitchesSelection= [pstart, pend];
		lvPitchesRangeElement.value= lvPitchesSelection/psize;
		lvPitchesUpdate.value;

		lvVelocitiesNumber.value= vsize;
		lvVelocitiesArray= velocities;
		lvVelocitiesSelection= [vstart, vend];
		lvVelocitiesRangeElement.value= lvVelocitiesSelection/vsize;
		lvVelocitiesUpdate.value;
	};
	readPatternsFromDisk= {
		var path1= SInstruments.dataDir+/+"sStream_patterns.json";
		var path2= SInstruments.dataDir+/+"sStream_patternsUSER.json";
		var p= [];
		if(File.exists(path1), {
			try{p= p++path1.parseYAMLFile};
		});
		if(File.exists(path2), {
			try{p= p++path2.parseYAMLFile};
		});
		if(p.isEmpty, {
			p= [Dictionary.newFrom([  //at least one pattern
				"name", \random,
				"range", #[0, 32],
				"pitches", {40.rrand(80)}!32,
				"velocities", {1.0.linrand}!32
			])];
		});
		p;
	};
	writeUserPatternsToDisk= {  //(re)write all user patterns to disk
		File.use(SInstruments.dataDir+/+"sStream_patternsUSER.json", "w", {|file|
			file.write("[");
			patterns.do{|p|
				if(p["user"]=="1", {
					file.write("\n{");
					file.write("\n'name': '%',".format(p["name"]));
					file.write("\n'pitches': %,".format(p["pitches"]));
					file.write("\n'prange': %,".format(p["prange"]));
					file.write("\n'velocities': %,".format(p["velocities"]));
					file.write("\n'vrange': %,".format(p["vrange"]));
					file.write("\n'user': 1");
					file.write("\n},");
				});
			};
			file.write("\n]");
		});
	};
	patterns= readPatternsFromDisk.value;
	lvPatternsPopup.items= patterns.collect{|p| p["name"]};

	lvPatternSettings.action= {
		var storeText, storeButton, clearPopup, clearButton;
		var infoText, doneButton;
		var pos, name= "pattern settings";
		pswin= Window.allWindows.detect{|x| x.name==name};
		if(pswin.isNil, {
			pos= Window.screenBounds.extent*0.6;
			pswin= Window(name, Rect.aboutPoint(pos, 200, 100));
			pswin.view.layout_(VLayout(
				StaticText().string_("Store - write current pitch and velocity patterns to disk"),
				HLayout(
					storeText= TextField().string_("name"),
					storeButton= Button().states_([
						["Store", palette.buttonText, palette.button]
					])
				),
				StaticText().string_("Clear - erase user defined pattern from disk"),
				HLayout(
					clearPopup= PopUpMenu(),
					clearButton= Button().states_([
						["Clear", palette.buttonText, palette.button]
					])
				),
				View(),
				infoText= StaticText(),
				HLayout(
					[View(), stretch:1],
					doneButton= Button().states_([
						["Done", palette.buttonText, palette.button]
					])
				)
			));
			SGUI.adapt(pswin);
			infoText.minHeight_(44);
			pswin.view.keyDownAction= {|view, chr, mod, unicode, keycode, key|
				if(unicode==27, {pswin.close});  //esc
			};
			storeButton.action= {
				infoText.string= "";
				infoText.stringColor= palette.buttonText;
				if(storeText.string.isEmpty, {
					infoText.stringColor= Color.red;
					infoText.string= "Error: provide a name in the textfield";
				}, {
					if(patterns.any{|p| p["name"]==storeText.string}, {
						infoText.stringColor= Color.red;
						infoText.string= "Error: name already exist (clear it first)";
					}, {
						patterns= patterns++[Dictionary.newFrom([
							"name", storeText.string,
							"pitches", lvPitchesArray,
							"prange", lvPitchesSelection+#[0, 1],
							"velocities", lvVelocitiesArray,
							"vrange", lvVelocitiesSelection+#[0, 1],
							"user", "1"
						])];
						writeUserPatternsToDisk.value;
						clearPopup.items= patterns.select{|p| p["user"]=="1"}.collect{|p| p["name"]};
						lvPatternsPopup.items= patterns.collect{|p| p["name"]};
						lvPatternsPopup.value= lvPatternsPopup.items.size-1;
						infoText.string= "wrote pattern '%' to disk".format(storeText.string);
					});
				});
			};
			clearPopup.items= patterns.select{|p| p["user"]=="1"}.collect{|p| p["name"]};
			clearButton.action= {
				if(clearPopup.items.notEmpty, {
					SGUIdialogWindow({
						var name= clearPopup.items[clearPopup.value];
						patterns= patterns.reject{|p| p["name"]==name and:{p["user"]=="1"}};
						writeUserPatternsToDisk.value;
						clearPopup.items= patterns.select{|p| p["user"]=="1"}.collect{|p| p["name"]};
						lvPatternsPopup.items= patterns.collect{|p| p["name"]};
						infoText.string= "erased pattern '%' from disk".format(name);
					});
				});
			};
			doneButton.action= {
				pswin.close;
			};
		});
		pswin.front;
	};

	lvSyncButton.action= {|view|
		Pdefn(\sStream_lvPitches_index).reset;
		Pdefn(\sStream_pitches).reset;
		Pdefn(\sStream_lvVelocities_index).reset;
		Pdefn(\sStream_velocities).reset;
		if(lvPitchesLoopPopup.items[lvPitchesLoopPopup.value].asSymbol==\Scramble, {
			lvPitchesUpdate.value;
		});
		if(lvVelocitiesLoopPopup.items[lvVelocitiesLoopPopup.value].asSymbol==\Scramble, {
			lvVelocitiesUpdate.value;
		});
	};

	lvPitchesOnButtonElement.action= {|val|
		if(val>0, {
			lvPitchesUpdate.value;
		}, {
			lvPitchesIndex= nil;
		});
		switch(lvPitchesOnButtonSpec.map(val).asInteger,
			0, {
				SInputs.destinations[\sGreybox].sendMsg(\led, \pitchState, 0);
			},
			1, {
				SInputs.destinations[\sGreybox].sendMsg(\led, \pitchState, 1);
			},
			2, {
				SInputs.destinations[\sGreybox].sendMsg(\led, \pitchState, 2);
			},
			3, {
				SInputs.destinations[\sGreybox].sendMsg(\led, \pitchState, 3);
			}
		);
	};
	lvPitchesNumber.action= {|view|
		view.value= view.value.clip(1, maxNumSteps);
		if(view.value!=lvPitchesArray.size, {
			lvPitchesArray= lvPitchesArray.extend(view.value.asInteger, lvPitchesArray.last);
			lvPitchesRangeElement.doAction;
		});
	};
	lvPitchesLoopPopup.action= {|view|
		lvPitchesUpdate.value;
	};

	lvPitchMinMaxRangeElement.action= {|val|
		pitchElement.valueAction= pitchElement.value;
	};

	lvPitchesUsrAnim.background= Color.clear;
	lvPitchesUsrAnim.clearOnRefresh= true;
	lvPitchesUsrAnim.acceptsMouse= false;
	lvPitchesUsrAnim.drawFunc= {|usr|
		var uw= usr.bounds.width-usrPadding.width;
		var uh= usr.bounds.height-(usrPadding.height*2);
		var stepWidth= uw/lvPitchesArray.size;
		var xLastStr= -999;
		var scale= scales[lvScaleList.value];
		Pen.translate(usrPadding.width+(stepWidth*0.5), uh+usrPadding.height);
		Pen.font= fnt2;
		Pen.strokeColor= palette.buttonText;
		Pen.fillColor= palette.highlight;
		lvPitchesArray.do{|val, i|
			var x, y, str;
			if(lvScaleButtonElement.value==1, {
				val= val.nearestInScale(scale);
			});
			x= i.linlin(0, lvPitchesArray.size, 0, uw);
			y= val.linlin(0, 127, 0, 0-uh);
			Pen.addRect(Rect.aboutPoint(Point(x, y), 1, 1));
			if(i>=lvPitchesSelection[0] and:{i<=lvPitchesSelection[1]}, {
				Pen.addRect(Rect.aboutPoint(Point(x, y), 3, 3));
				Pen.moveTo(Point(x, y));
				Pen.lineTo(Point(x+(lvSustainSpec.map(lvSustainElement.value)*stepWidth), y));
			});
			if(i==lvPitchesIndex, {
				Pen.addRect(Rect.aboutPoint(Point(x, y), 2, 2));
				Pen.addRect(Rect.aboutPoint(Point(x, y), 4, 4));
			});
			if(i==lvPitchesClosestIndex, {
				Pen.addOval(Rect.aboutPoint(Point(x, y), 5, 5));
			});
			if(lvPitchesArray.size>30, {
				if(x-xLastStr>(strHeight*0.75), {
					xLastStr= x;
					Pen.push;
					Pen.rotate(-0.5pi, x, y);
					str= val.asInteger.asString;
					if(val>112, {
						Pen.stringRightJustIn(str, Rect.aboutPoint(Point(x-(strWidth*1.5), y), strWidth, strHeight));
					}, {
						Pen.stringLeftJustIn(str, Rect.aboutPoint(Point(x+(strWidth*1.5), y), strWidth, strHeight));
					});
					Pen.pop;
				});
			}, {
				str= val.asInteger.asString;
				if(val>112, {
					Pen.stringCenteredIn(str, Rect.aboutPoint(Point(x, y+strHeight), strWidth, strHeight));
				}, {
					Pen.stringCenteredIn(str, Rect.aboutPoint(Point(x, y-strHeight), strWidth, strHeight));
				});
			});
		};
		Pen.stroke;
	};

	lvPitchesUsrBack.drawFunc= {|usr|
		var uw= usr.bounds.width-usrPadding.width;
		var uh= usr.bounds.height-(usrPadding.height*2);
		var numMarkings= 7;
		Pen.translate(usrPadding.width, uh+usrPadding.height);
		Pen.font= fnt2;
		Pen.fillColor= palette.buttonText;
		Pen.strokeColor= Color.grey(0.5, 0.5);
		numMarkings.do{|i|
			var freq= i.linlin(0, numMarkings-1, 0, 127).round.asInteger;
			var x= 0-usrPadding.width+1;
			var y= i.linlin(0, numMarkings-1, 0, 0-uh);
			Pen.moveTo(Point(0, y));
			Pen.lineTo(Point(uw, y));
			Pen.stringRightJustIn(freq.asString, Rect.aboutPoint(Point(x, y), strWidth, strHeight));
		};
		Pen.stroke;
	};

	lvPitchesUsrBack.mouseDownAction= {|view, x, y, mod|
		lvPitchesUsrBack.mouseMoveAction.value(view, x, y, mod);
	};
	lvPitchesUsrBack.mouseMoveAction= {|view, x, y, mod|
		var val= y.linlin(usrPadding.height, view.bounds.height-usrPadding.height, 127, 0).round;
		lvPitchesClosestIndex= x.linlin(usrPadding.width, view.bounds.width, 0, lvPitchesNumber.value-1).round.asInteger;
		if(lvPitchesArray[lvPitchesClosestIndex]!=val, {
			lvPitchesArray[lvPitchesClosestIndex]= val;
			lvPitchesUsrAnimRedraw= true;
		});
	};
	lvPitchesUsrBack.mouseUpAction= {|view, x, y, mod|
		lvPitchesUpdate.value;
	};
	lvPitchesUsrBack.parent.acceptsMouseOver= true;
	lvPitchesUsrBack.mouseOverAction= {|view, x, y|
		lvPitchesClosestIndex= x.linlin(usrPadding.width, view.bounds.width, 0, lvPitchesNumber.value-1).round.asInteger;
		lvPitchesUsrAnimRedraw= true;
	};
	lvPitchesUsrBack.mouseLeaveAction= {
		lvPitchesClosestIndex= nil;
		lvPitchesUsrAnimRedraw= true;
	};

	lvPitchesRangeElement.action= {|val|
		var start= (val[0]*(lvPitchesNumber.value-1)).round.asInteger;
		var end= (val[1]*(lvPitchesNumber.value-1)).round.asInteger;
		if(lvPitchesSelection[0]!=start or:{lvPitchesSelection[1]!=end}, {
			lvPitchesSelection= [start, end];
			lvPitchesUpdate.value;
		});
	};

	lvPitchesUpdate= {
		var indices= (lvPitchesSelection[0]..lvPitchesSelection[1]);
		var pitches;
		switch(lvPitchesLoopPopup.value,
			1, {indices= indices.reverse},
			2, {indices= indices.mirror1},
			3, {indices= indices.stutter},
			4, {indices= indices.scramble}
		);
		Pdefn(\sStream_lvPitches_index, Pseq(indices, inf));
		pitches= lvPitchesArray.wrapAt(indices);
		if(lvScaleButtonElement.value==1, {
			pitches= pitches.collect{|x| x.nearestInScale(scales[lvScaleList.value])};
		});
		Pdefn(\sStream_pitches, Pseq(pitches, inf));
		lvPitchesUsrAnimRedraw= true;
	};


	lvVelocitiesOnButtonElement.action= {|val|
		Pdefn(\sStream_velocitiesSelect, lvVelocitiesOnButtonSpec.map(val).asInteger);
		if(val>0, {
			lvVelocitiesUpdate.value;
		}, {
			lvVelocitiesIndex= nil;
		});
	};
	lvVelocitiesNumber.action= {|view|
		view.value= view.value.clip(1, maxNumSteps);
		if(view.value!=lvVelocitiesArray.size, {
			lvVelocitiesArray= lvVelocitiesArray.extend(view.value.asInteger, lvVelocitiesArray.last);
			lvVelocitiesRangeElement.doAction;
		});
	};
	lvVelocitiesLoopPopup.action= {|view|
		lvVelocitiesUpdate.value;
	};

	lvVolumeElement.action= {|val|
		lvVst.set('Volume', val);
	};

	lvVelocitiesUsrAnim.background= Color.clear;
	lvVelocitiesUsrAnim.clearOnRefresh= true;
	lvVelocitiesUsrAnim.acceptsMouse= false;
	lvVelocitiesUsrAnim.drawFunc= {|usr|
		var uw= usr.bounds.width-usrPadding.width;
		var uh= usr.bounds.height-(usrPadding.height*2);
		var stepWidth= uw/lvVelocitiesArray.size;
		var xLastStr= -999;
		var str;
		Pen.translate(usrPadding.width+(stepWidth*0.5), uh+usrPadding.height);
		Pen.font= fnt2;
		Pen.strokeColor= palette.buttonText;
		Pen.fillColor= palette.highlight;
		lvVelocitiesArray.do{|val, i|
			var x= i.linlin(0, lvVelocitiesArray.size, 0, uw);
			var y= val*(0-uh);
			Pen.addRect(Rect.aboutPoint(Point(x, y), 1, 1));
			if(i>=lvVelocitiesSelection[0] and:{i<=lvVelocitiesSelection[1] and:{val>0}}, {
				Pen.addRect(Rect.aboutPoint(Point(x, y), 3, 3));
				Pen.moveTo(Point(x, y));
				Pen.lineTo(Point(x, 0));
			});
			if(i==lvVelocitiesIndex, {
				if(val>0, {
					Pen.addRect(Rect.aboutPoint(Point(x, y), 2, 2));
					Pen.addRect(Rect.aboutPoint(Point(x, y), 4, 4));
				});
			});
			if(i==lvVelocitiesClosestIndex, {
				Pen.addOval(Rect.aboutPoint(Point(x, y), 5, 5));
			});
			if(lvVelocitiesArray.size>30, {
				if(x-xLastStr>(strHeight*0.75), {
					xLastStr= x;
					str= SGUI.fixDec(val, 1);
					Pen.push;
					Pen.rotate(-0.5pi, x, y);
					if(val<0.85, {
						Pen.stringLeftJustIn(str, Rect.aboutPoint(Point(x+(strWidth*1.5), y), strWidth, strHeight));
					}, {
						Pen.stringRightJustIn(str, Rect.aboutPoint(Point(x-(strWidth*1.5), y), strWidth, strHeight));
					});
					Pen.pop;
				});
			}, {
				str= SGUI.fixDec(val, 1);
				if(val<0.93, {
					Pen.stringCenteredIn(str, Rect.aboutPoint(Point(x, y-strHeight), strWidth, strHeight));
				}, {
					Pen.stringCenteredIn(str, Rect.aboutPoint(Point(x, y+strHeight), strWidth, strHeight));
				});
			});
		};
		Pen.stroke;
	};

	lvVelocitiesUsrBack.drawFunc= {|usr|
		var uw= usr.bounds.width-usrPadding.width;
		var uh= usr.bounds.height-(usrPadding.height*2);
		var numMarkings= 6;
		Pen.translate(usrPadding.width, uh+usrPadding.height);
		Pen.font= fnt2;
		Pen.fillColor= palette.buttonText;
		Pen.strokeColor= Color.grey(0.5, 0.5);
		numMarkings.do{|i|
			var amp= i.linlin(0, numMarkings-1, 0, 1);
			var x= 0-usrPadding.width+1;
			var y= i.linlin(0, numMarkings-1, 0, 0-uh);
			Pen.moveTo(Point(0, y));
			Pen.lineTo(Point(uw, y));
			Pen.stringRightJustIn(SGUI.fixDec(amp, 1), Rect.aboutPoint(Point(x, y), strWidth, strHeight));
		};
		Pen.stroke;
	};

	lvVelocitiesUsrBack.mouseDownAction= {|view, x, y, mod|
		lvVelocitiesUsrBack.mouseMoveAction.value(view, x, y, mod);
	};
	lvVelocitiesUsrBack.mouseMoveAction= {|view, x, y, mod|
		var val= y.linlin(usrPadding.height, view.bounds.height-usrPadding.height, 1, 0).round(1/128);
		lvVelocitiesClosestIndex= x.linlin(usrPadding.width, view.bounds.width, 0, lvVelocitiesNumber.value-1).round.asInteger;
		if(lvVelocitiesArray[lvVelocitiesClosestIndex]!=val, {
			lvVelocitiesArray[lvVelocitiesClosestIndex]= val;
			lvVelocitiesUsrAnimRedraw= true;
		});
	};
	lvVelocitiesUsrBack.mouseUpAction= {|view, x, y, mod|
		lvVelocitiesUpdate.value;
	};
	lvVelocitiesUsrBack.parent.acceptsMouseOver= true;
	lvVelocitiesUsrBack.mouseOverAction= {|view, x, y|
		lvVelocitiesClosestIndex= x.linlin(usrPadding.width, view.bounds.width, 0, lvVelocitiesNumber.value-1).round.asInteger;
		lvVelocitiesUsrAnimRedraw= true;
	};
	lvVelocitiesUsrBack.mouseLeaveAction= {
		lvVelocitiesClosestIndex= nil;
		lvVelocitiesUsrAnimRedraw= true;
	};

	lvVelocitiesRangeElement.action= {|val|
		var start= (val[0]*(lvVelocitiesNumber.value-1)).round.asInteger;
		var end= (val[1]*(lvVelocitiesNumber.value-1)).round.asInteger;
		if(lvVelocitiesSelection[0]!=start or:{lvVelocitiesSelection[1]!=end}, {
			lvVelocitiesSelection= [start, end];
			lvVelocitiesUpdate.value;

		});
	};

	lvVelocitiesUpdate= {
		var indices= (lvVelocitiesSelection[0]..lvVelocitiesSelection[1]);
		switch(lvVelocitiesLoopPopup.value,
			1, {indices= indices.reverse},
			2, {indices= indices.mirror1},
			3, {indices= indices.stutter},
			4, {indices= indices.scramble}
		);
		Pdefn(\sStream_lvVelocities_index, Pseq(indices, inf));
		Pdefn(\sStream_velocities, Pseq(lvVelocitiesArray.at(indices), inf));
		lvVelocitiesUsrAnimRedraw= true;
	};


	//--AV
	avOnElement.action= {|val|
		SInputs.destinations[\sGreybox].sendMsg(\led, \avOn, val);
	};

	avVstEditorButton.action= {|view|
		avVst.gui;
	};
	avVstProgramPopup.action= {|view|
		avVst.program= view.value;
	};

	avProgramSelectButtons.do{|but, i|
		but.action= {|view|
			avVstProgramPopup.valueAction= avProgramSelectPopups[i].value;
		};
	};

	avScaleList.items= scales.collect{|x| x.name.asSymbol};
	avScaleList.value= avScaleList.items.indexOf(defaultScale.name.asSymbol);
	avScaleList.action= {|view|
		Pdefn(\sStream_avScale, scales[view.value]);
		//avFreqUpdate.value;  //TODO!
		avPitchesUsrAnim.refresh;
	};

	avPitchBendOnElement.action= {|val|
		SInputs.destinations[\sGreybox].sendMsg(\led, \avBendOn, val);
	};

	avSustainElement.action= {|val|
		Pdefn(\sStream_avSustain, avSustainSpec.map(val));
		avPitchesUsrAnimRedraw= true;
	};
	avSustainOnElement.action= {|val|
		avVst.set('Sustain Pedal', val);
		SInputs.destinations[\sGreybox].sendMsg(\led, \avSustainOn, val);
	};

	avChromTranspElement.action= {|val|
		Pdefn(\sStream_avCstranspose, avChromTranspSpec.map(val).asInteger);
	};
	avOctaveElement.action= {|val|
		Pdefn(\sStream_avOctave, avOctaveSpec.map(val).asInteger);
	};

	avChordsPopup.action= {|view|
		var o= chords[view.value];
		var semitones= o["semitones"].collect{|x| x.asFloat};
		var delays= o["delays"].collect{|x| x.asFloat};
		var amps= o["amps"].collect{|x| x.asFloat};
		var size= semitones.size;

		avPitchesBuffer= semitones.extend(maxNumVoices, 0);
		avDelaysBuffer= delays.extend(maxNumVoices, (delays.last+0.01).min(maxEntryDelay));
		avVelocitiesBuffer= amps.extend(maxNumVoices, 0.7);
		avVoicesNumberElement.valueAction= avVoicesNumberSpec.unmap(size);
	};
	readChordsFromDisk= {
		var path1= SInstruments.dataDir+/+"sStream_chords.json";
		var path2= SInstruments.dataDir+/+"sStream_chordsUSER.json";
		var c= [];
		if(File.exists(path1), {
			try{c= c++path1.parseYAMLFile};
		});
		if(File.exists(path2), {
			try{c= c++path2.parseYAMLFile};
		});
		if(c.isEmpty, {
			c= [Dictionary.newFrom([  //at least one chord
				"name", \random,
				"semitones", {12.rand2}!5,
				"delays", {1.0.linrand}!5,
				"amps", {1.0.linrand}!5
			])];
		});
		c;
	};
	writeUserChordsToDisk= {  //(re)write all user chords to disk
		File.use(SInstruments.dataDir+/+"sStream_chordsUSER.json", "w", {|file|
			file.write("[");
			chords.do{|c|
				if(c["user"]=="1", {
					file.write("\n{");
					file.write("\n'name': '%',".format(c["name"]));
					file.write("\n'semitones': %,".format(c["semitones"]));
					file.write("\n'delays': %,".format(c["delays"]));
					file.write("\n'amps': %,".format(c["amps"]));
					file.write("\n'user': 1");
					file.write("\n},");
				});
			};
			file.write("\n]");
		});
	};
	chords= readChordsFromDisk.value;
	avChordsPopup.items= chords.collect{|c| c["name"]};

	avChordSettings.action= {
		var storeText, storeButton, clearPopup, clearButton;
		var infoText, doneButton;
		var pos, name= "chord settings";
		cswin= Window.allWindows.detect{|x| x.name==name};
		if(cswin.isNil, {
			pos= Window.screenBounds.extent*0.6;
			cswin= Window(name, Rect.aboutPoint(pos, 200, 100));
			cswin.view.layout_(VLayout(
				StaticText().string_("Store - write current chord to disk"),
				HLayout(
					storeText= TextField().string_("name"),
					storeButton= Button().states_([
						["Store", palette.buttonText, palette.button]
					])
				),
				StaticText().string_("Clear - erase user defined chord from disk"),
				HLayout(
					clearPopup= PopUpMenu(),
					clearButton= Button().states_([
						["Clear", palette.buttonText, palette.button]
					])
				),
				View(),
				infoText= StaticText(),
				HLayout(
					[View(), stretch:1],
					doneButton= Button().states_([
						["Done", palette.buttonText, palette.button]
					])
				)
			));
			SGUI.adapt(cswin);
			infoText.minHeight_(44);
			cswin.view.keyDownAction= {|view, chr, mod, unicode, keycode, key|
				if(unicode==27, {cswin.close});  //esc
			};
			storeButton.action= {
				infoText.string= "";
				infoText.stringColor= palette.buttonText;
				if(storeText.string.isEmpty, {
					infoText.stringColor= Color.red;
					infoText.string= "Error: provide a name in the textfield";
				}, {
					if(chords.any{|c| c["name"]==storeText.string}, {
						infoText.stringColor= Color.red;
						infoText.string= "Error: name already exist (clear it first)";
					}, {
						chords= chords++[Dictionary.newFrom([
							"name", storeText.string,
							"semitones", avPitchesArray,
							"delays", avDelaysArray,
							"amps", avVelocitiesArray,
							"user", "1"
						])];
						writeUserChordsToDisk.value;
						clearPopup.items= chords.select{|c| c["user"]=="1"}.collect{|c| c["name"]};
						avChordsPopup.items= chords.collect{|c| c["name"]};
						avChordsPopup.value= avChordsPopup.items.size-1;
						infoText.string= "wrote chord '%' to disk".format(storeText.string);
					});
				});
			};
			clearPopup.items= chords.select{|c| c["user"]=="1"}.collect{|c| c["name"]};
			clearButton.action= {
				if(clearPopup.items.notEmpty, {
					SGUIdialogWindow({
						var name= clearPopup.items[clearPopup.value];
						chords= chords.reject{|c| c["name"]==name and:{c["user"]=="1"}};
						writeUserChordsToDisk.value;
						clearPopup.items= chords.select{|c| c["user"]=="1"}.collect{|c| c["name"]};
						avChordsPopup.items= chords.collect{|c| c["name"]};
						infoText.string= "erased chord '%' from disk".format(name);
					});
				});
			};
			doneButton.action= {
				cswin.close;
			};
		});
		cswin.front;
	};

	avReorderButton.action= {|view|
		avDelaysArray= avDelaysArray.scramble;
		avPitchesArray= avPitchesArray.at(avDelaysArray.order);
		avVelocitiesArray= avVelocitiesArray.at(avDelaysArray.order);
		avPitchesUsrAnimRedraw= true;
		avVelocitiesUsrAnimRedraw= true;
	};

	avVoicesNumberElement.action= {|val|
		var numVoices= avVoicesNumberSpec.map(val).asInteger;
		avPitchesArray= avPitchesBuffer.copyRange(0, numVoices-1);
		avDelaysArray= avDelaysBuffer.copyRange(0, numVoices-1);
		avVelocitiesArray= avVelocitiesBuffer.copyRange(0, numVoices-1);
		createStream.value(numVoices);
		avPitchesUsrBack.refresh;
		avVelocitiesUsrBack.refresh;
		avPitchesUsrAnimRedraw= true;
		avVelocitiesUsrAnimRedraw= true;
	};

	avFollowPopupElement.action= {|val|
		var mode= avFollowPopupSpec.map(val).asInteger;
		/*switch(view.value,
		0, {},  //parallel
		1, {},  //opposite
		2, {},  //fixed
		3, {},  //up
		4, {}  //down
		);*/
		avFollowStepText.visible= mode>=3;
		avFollowStepNumberElement.views.do{|view| view.visible= mode>=3};
	};

	avPitchesUsrAnim.background= Color.clear;
	avPitchesUsrAnim.clearOnRefresh= true;
	avPitchesUsrAnim.acceptsMouse= false;
	avPitchesUsrAnim.drawFunc= {|usr|
		var uw= usr.bounds.width-usrPadding.width;
		var uh= usr.bounds.height-(usrPadding.height*2)-strHeight;
		var stepWidth= uw/avPitchesArray.size;
		var dur= avSustainSpec.map(avSustainElement.value).linlin(0, maxEntryDelay, 0, uw-(strWidth*2), nil);
		var scale= scales[avScaleList.value];
		Pen.translate(usrPadding.width, uh+usrPadding.height);
		Pen.font= fnt2;
		Pen.strokeColor= palette.buttonText;
		Pen.fillColor= palette.highlight;
		avPitchesArray.do{|val, i|
			var x, y, str;
			val= (val+60).nearestInScale(scale)-60;
			x= (avDelaysArray[i]*avEntryDelayElement.value).linlin(0, maxEntryDelay, strWidth, uw-strWidth);
			y= val.linlin(0-maxChordPitch, maxChordPitch, 0, 0-uh);
			Pen.addRect(Rect.aboutPoint(Point(x, y), 1, 1));
			if(avVelocitiesArray[i]>0, {
				Pen.addRect(Rect.aboutPoint(Point(x, y), 3, 3));
				Pen.moveTo(Point(x, y));
				Pen.lineTo(Point(x+dur, y));
			});
			if(i==avIndex, {
				Pen.addRect(Rect.aboutPoint(Point(x, y), 2, 2));
				Pen.addRect(Rect.aboutPoint(Point(x, y), 4, 4));
			});
			if(i==avPitchesClosestIndex or:{i==avVelocitiesClosestIndex}, {
				Pen.addOval(Rect.aboutPoint(Point(x, y), 5, 5));
			});
			str= val.asInteger.asString;
			Pen.stringCenteredIn(str, Rect.aboutPoint(Point(x-(strWidth*0.75), y), strWidth, strHeight));
		};
		Pen.stroke;
	};

	avPitchesUsrBack.drawFunc= {|usr|
		var uw= usr.bounds.width-usrPadding.width;
		var uh= usr.bounds.height-(usrPadding.height*2)-strHeight;
		var numMarkingsFreq= 9;
		var numMarkingsTime= 5;
		Pen.translate(usrPadding.width, uh+usrPadding.height);
		Pen.font= fnt2;
		Pen.fillColor= palette.buttonText;
		Pen.strokeColor= Color.grey(0.5, 0.5);
		numMarkingsFreq.do{|i|
			var freq= i.linlin(0, numMarkingsFreq-1, 0-maxChordPitch, maxChordPitch).asInteger;
			var x= 0-usrPadding.width+1;
			var y= i.linlin(0, numMarkingsFreq-1, 0, 0-uh);
			Pen.stringRightJustIn(freq.asString, Rect.aboutPoint(Point(x, y), strWidth, strHeight));
		};
		Pen.moveTo(Point(0, 0-uh*0.5));
		Pen.lineTo(Point(uw, 0-uh*0.5));
		numMarkingsTime.do{|i|
			var time= i.linlin(0, numMarkingsTime-1, 0, maxEntryDelay);
			var x= i.linlin(0, numMarkingsTime-1, strWidth, uw-strWidth);
			var str= SGUI.fixDec(time, 1);
			if(i==(numMarkingsTime-1), {str= " "++str++"s"});
			Pen.stringCenteredIn(str, Rect.aboutPoint(Point(x, strHeight), strWidth, strHeight));
			if(i==0, {
				Pen.moveTo(Point(x, 0));
				Pen.lineTo(Point(x, 0-uh));
			});
		};
		Pen.stroke;
	};

	avPitchesUsrBack.mouseDownAction= {|view, x, y, mod|
		avPitchesClickPoint= Point(x, y);
		avPitchesSetClosestIndex.value(x, y);
		avPitchesUsrBack.mouseMoveAction.value(view, x, y, mod);
	};
	avPitchesUsrBack.mouseMoveAction= {|view, x, y, mod|
		var vx, vy, xLock, yLock, angle;
		if(avPitchesClosestIndex.notNil, {
			vx= x.linlin(usrPadding.width+strWidth, view.bounds.width-strWidth, 0, maxEntryDelay)/avEntryDelayElement.value;
			vy= y.linlin(usrPadding.height, view.bounds.height-usrPadding.height-strHeight, maxChordPitch, 0-maxChordPitch);
			vy= vy.round;
			xLock= false;
			yLock= false;
			if(mod.isShift, {
				angle= atan2(avPitchesClickPoint.y-y, avPitchesClickPoint.x-x);
				xLock= sin(angle).abs>0.9;
				yLock= cos(angle).abs>0.9;
			});
			if(xLock.not and:{avDelaysArray[avPitchesClosestIndex]!=vx}, {
				avDelaysArray[avPitchesClosestIndex]= vx;
				avPitchesUsrAnimRedraw= true;
				if(avDelaysArray.order.differentiate.any{|x| x<0}, {  //keep amplitudes order in sync
					avPitchesArray= avPitchesArray.at(avDelaysArray.order);
					avVelocitiesArray= avVelocitiesArray.at(avDelaysArray.order);
					avDelaysArray= avDelaysArray.sort;
					avPitchesSetClosestIndex.value(x, y);
					avVelocitiesUsrAnimRedraw= true;
				});
			});
			if(yLock.not and:{avPitchesArray[avPitchesClosestIndex]!=vy}, {
				avPitchesArray[avPitchesClosestIndex]= vy;
				avPitchesUsrAnimRedraw= true;
			});
		});
	};
	avPitchesUsrBack.parent.acceptsMouseOver= true;
	avPitchesUsrBack.mouseOverAction= {|view, x, y|
		avPitchesSetClosestIndex.value(x, y);
	};
	avPitchesUsrBack.mouseLeaveAction= {
		avPitchesClosestIndex= nil;
		avPitchesUsrAnimRedraw= true;
		avVelocitiesUsrAnimRedraw= true;
	};
	avPitchesSetClosestIndex= {|x, y|
		var uw= avPitchesUsrBack.bounds.width-usrPadding.width;
		var uh= avPitchesUsrBack.bounds.height-(usrPadding.height*2)-strHeight;
		var minDist= inf;
		x= x-usrPadding.width;
		y= y-(uh+usrPadding.height);
		avPitchesArray.do{|val, i|
			var ox= (avDelaysArray[i]*avEntryDelayElement.value).linlin(0, maxEntryDelay, strWidth, uw-strWidth);
			var oy= val.linlin(0-maxChordPitch, maxChordPitch, 0, 0-uh);
			var dist= (ox-x).abs+(oy-y).abs;  //manhattan
			if(dist<minDist, {
				minDist= dist;
				avPitchesClosestIndex= i;
			});
		};
		if(minDist>25, {  //reset if no voice close enough
			avPitchesClosestIndex= nil;
		});
		avPitchesUsrAnimRedraw= true;
		avVelocitiesUsrAnimRedraw= true;
	};

	avVolumeElement.action= {|val|
		avVst.set('Volume', val);
	};

	avVelocitiesUsrAnim.background= Color.clear;
	avVelocitiesUsrAnim.clearOnRefresh= true;
	avVelocitiesUsrAnim.acceptsMouse= false;
	avVelocitiesUsrAnim.drawFunc= {|usr|
		var uw= usr.bounds.width-usrPadding.width;
		var uh= usr.bounds.height-(usrPadding.height*2)-strHeight;
		Pen.translate(usrPadding.width, uh+usrPadding.height);
		Pen.strokeColor= palette.buttonText;
		avVelocitiesArray.do{|val, i|
			var x= i.linlin(-0.5, avVelocitiesArray.size-0.5, 0, uw);
			var y= val*(0-uh);
			Pen.addRect(Rect.aboutPoint(Point(x, y), 1, 1));
			if(val>0, {
				Pen.addRect(Rect.aboutPoint(Point(x, y), 3, 3));
				Pen.moveTo(Point(x, y));
				Pen.lineTo(Point(x, 0));
			});
			if(i==avIndex, {
				if(val>0, {
					Pen.addRect(Rect.aboutPoint(Point(x, y), 2, 2));
					Pen.addRect(Rect.aboutPoint(Point(x, y), 4, 4));
				});
			});
			if(i==avVelocitiesClosestIndex or:{i==avPitchesClosestIndex}, {
				Pen.addOval(Rect.aboutPoint(Point(x, y), 5, 5));
			});
		};
		Pen.stroke;
	};

	avVelocitiesUsrBack.drawFunc= {|usr|
		var uw= usr.bounds.width-usrPadding.width;
		var uh= usr.bounds.height-(usrPadding.height*2)-strHeight;
		var numMarkings= 6;
		Pen.translate(usrPadding.width, uh+usrPadding.height);
		Pen.font= fnt2;
		Pen.fillColor= palette.buttonText;
		Pen.strokeColor= Color.grey(0.5, 0.5);
		numMarkings.do{|i|
			var amp= i.linlin(0, numMarkings-1, 0, 1);
			var x= 0-usrPadding.width+1;
			var y= i.linlin(0, numMarkings-1, 0, 0-uh);
			Pen.moveTo(Point(0, y));
			Pen.lineTo(Point(uw, y));
			Pen.stringRightJustIn(SGUI.fixDec(amp, 1), Rect.aboutPoint(Point(x, y), strWidth, strHeight));
		};
		Pen.stroke;
		avVelocitiesArray.size.do{|i|
			var x= i.linlin(-0.5, avVelocitiesArray.size-0.5, 0, uw);
			Pen.stringCenteredIn((i+1).asString, Rect.aboutPoint(Point(x, strHeight), strWidth, strHeight));
		};
	};

	avVelocitiesUsrBack.mouseDownAction= {|view, x, y, mod|
		avVelocitiesUsrBack.mouseMoveAction.value(view, x, y, mod);
	};
	avVelocitiesUsrBack.mouseMoveAction= {|view, x, y, mod|
		var val= y.linlin(usrPadding.height, view.bounds.height-usrPadding.height-strHeight, 1, 0).round(1/128);
		avVelocitiesClosestIndex= x.linlin(usrPadding.width, view.bounds.width, 0, avVelocitiesArray.size-1).round.asInteger;
		if(avVelocitiesArray[avVelocitiesClosestIndex]!=val, {
			avVelocitiesArray[avVelocitiesClosestIndex]= val;
			avVelocitiesUsrAnimRedraw= true;
			avPitchesUsrAnimRedraw= true;
		});
	};
	avVelocitiesUsrBack.parent.acceptsMouseOver= true;
	avVelocitiesUsrBack.mouseOverAction= {|view, x, y|
		avVelocitiesClosestIndex= x.linlin(usrPadding.width, view.bounds.width, 0, avVelocitiesArray.size-1).round.asInteger;
		avPitchesUsrAnimRedraw= true;
		avVelocitiesUsrAnimRedraw= true;
	};
	avVelocitiesUsrBack.mouseLeaveAction= {
		avVelocitiesClosestIndex= nil;
		avPitchesUsrAnimRedraw= true;
		avVelocitiesUsrAnimRedraw= true;
	};

	avEntryDelayElement.action= {|val|
		avPitchesUsrAnimRedraw= true;
	};

	snapshots.recallFunctions= (
		snapshotInstrument: {},
		snapshotVersion: {},
		lvVst: {|val| lvVst.setProgramData(val)},
		avVst: {|val| avVst.setProgramData(val)},
		lvProgramSelectPopups: {|val| val.do{|x, i| lvProgramSelectPopups[i].value= x}},
		lvPitchesArray: {|val| lvPitchesArray= val},
		lvVelocitiesArray: {|val| lvVelocitiesArray= val},
		avProgramSelectPopups: {|val| val.do{|x, i| avProgramSelectPopups[i].value= x}},
		avPitchesArray: {|val| avPitchesArray= val},
		avDelaysArray: {|val| avDelaysArray= val},
		avVelocitiesArray: {|val| avVelocitiesArray= val}
		//any other key will default to view.valueAction= assoc.value
	);
	snapshots.include= [  //order is important
		snapshotInstrument: \sStream,
		snapshotVersion: 1.2,
		lvVst: {|cond| var data; lvVst.getProgramData({|d| data= d; cond.unhang}); cond.hang; data},
		avVst: {|cond| var data; avVst.getProgramData({|d| data= d; cond.unhang}); cond.hang; data},
		onElement: onElement,
		attackElement: attackElement,
		releaseElement: releaseElement,

		metronomeOnElement: metronomeOnElement,
		metronomeElement: metronomeElement,
		rateScaleElement: rateScaleElement,
		rateMultiplierElement: rateMultiplierElement,

		lvOnElement: lvOnElement,
		lvProgramSelectPopups: {lvProgramSelectPopups.collect{|x| x.value}},  //TODO should use name instead
		lvScaleList: lvScaleList,
		lvPitchBendElement: lvPitchBendElement,
		lvPitchBendOnElement: lvPitchBendOnElement,
		lvSustainElement: lvSustainElement,
		lvSustainOnElement: lvSustainOnElement,
		lvScaleButtonElement: lvScaleButtonElement,
		lvChromTranspElement: lvChromTranspElement,
		lvOctaveElement: lvOctaveElement,
		lvPitchesOnButtonElement: lvPitchesOnButtonElement,
		lvPitchesNumber: lvPitchesNumber,
		lvPitchesLoopPopup: lvPitchesLoopPopup,
		lvPitchMinMaxRangeElement: lvPitchMinMaxRangeElement,
		lvPitchesArray: {lvPitchesArray.copy},
		lvPitchesRangeElement: lvPitchesRangeElement,
		lvVelocitiesOnButtonElement: lvVelocitiesOnButtonElement,
		lvVelocitiesNumber: lvVelocitiesNumber,
		lvVelocitiesLoopPopup: lvVelocitiesLoopPopup,
		lvVolumeElement: lvVolumeElement,
		lvVelocitiesArray: {lvVelocitiesArray.copy},
		lvVelocitiesRangeElement: lvVelocitiesRangeElement,

		avOnElement: avOnElement,
		avProgramSelectPopups: {avProgramSelectPopups.collect{|x| x.value}},  //TODO should use name instead
		avScaleList: avScaleList,
		avPitchBendElement: avPitchBendElement,
		avPitchBendOnElement: avPitchBendOnElement,
		avSustainElement: avSustainElement,
		avSustainOnElement: avSustainOnElement,
		avPitchesOnButtonElement: avPitchesOnButtonElement,
		avChromTranspElement: avChromTranspElement,
		avOctaveElement: avOctaveElement,
		avFollowStepNumberElement: avFollowStepNumberElement,
		avPitchMinMaxRangeElement: avPitchMinMaxRangeElement,
		avVolumeElement: avVolumeElement,
		avPitchesArray: {avPitchesArray.copy},
		avDelaysArray: {avDelaysArray.copy},
		avVelocitiesArray: {avVelocitiesArray.copy},
		avEntryDelayElement: avEntryDelayElement,
		avDisplacementElement: avDisplacementElement,
		avFalloutVoicesElement: avFalloutVoicesElement,
		avFalloutChordsElement: avFalloutChordsElement,
		avVoicesNumberElement: avVoicesNumberElement,

		masterTuning: masterTuning,
		mainVolume: mainVolume,
	];

	masterTuning.action= {|value|
		lvVst.set('Diapason', value.linlin(220, 880, 0, 1));
		avVst.set('Diapason', value.linlin(220, 880, 0, 1));
	};

	mainVolume.action= {|val|
		mainOutSyn.set(\vol, val);
	};


	//--network
	setupOscResponders= {
		oscResponders= [

			//--from sGreybox
			OSCFunc({|msg| metronomeOnElement.valueAction= 1-metronomeOnElement.value}, \metronomeOn, recvPort:oscPort),
			OSCFunc({|msg|
				metronomeElement.value= 1-msg[1];
				rateScaleElement.value= rateScaleSpec.unmap(msg[1])
			}, \rateScale, recvPort:oscPort),
			OSCFunc({|msg|
				rateMultiplierElement.value= rateMultiplierSpec.unmap(rateMultiplierSpec.map(rateMultiplierElement.value)+1%4);
			}, \rateMultiplier, recvPort:oscPort),

			OSCFunc({|msg| lvOnElement.valueAction= 1-lvOnElement.value}, \lvOn, recvPort:oscPort),
			OSCFunc({|msg| lvPitchBendElement.value= msg[1]}, \lvPitchBend, recvPort:oscPort),
			OSCFunc({|msg| lvPitchBendOnElement.valueAction= 1-lvPitchBendOnElement.value}, \lvPitchBendOn, recvPort:oscPort),
			OSCFunc({|msg| lvSustainElement.value= msg[1]}, \lvSustain, recvPort:oscPort),
			OSCFunc({|msg| lvSustainOnElement.valueAction= 1-lvSustainOnElement.value}, \lvSustainOn, recvPort:oscPort),

			OSCFunc({|msg|
				lvPitchMinMaxRangeElement.value= [msg[1], lvPitchMinMaxRangeElement.value[1]];
				//lvPitchMinMaxRangeElement.softSetValue(0, msg[1]);
			}, \lvPitchMinMaxRangeLo, recvPort:oscPort),
			OSCFunc({|msg|
				lvPitchMinMaxRangeElement.value= [lvPitchMinMaxRangeElement.value[0], msg[1]];
				//lvPitchMinMaxRangeElement.softSetValue(1, msg[1]);
			}, \lvPitchMinMaxRangeHi, recvPort:oscPort),
			OSCFunc({|msg|
				{
					var val= lvPitchesOnButtonElement.value;
					if(msg[1]==\toggle, {
						lvPitchesOnButtonElement.valueAction= lvPitchesOnButtonSpec.unmap(1-(val>0).binaryValue);
					}, {
						if(msg[1]==\mix, {
							if(lvPitchesOnButtonSpec.map(val)==2, {
								lvPitchesOnButtonElement.valueAction= 0;
							}, {
								lvPitchesOnButtonElement.valueAction= lvPitchesOnButtonSpec.unmap(2);
							});
						});
					});
				}.defer;
			}, \lvPitchesPattern, recvPort:oscPort),
			OSCFunc({|msg|
				{
					lvPitchesLoopPopup.valueAction= msg[1];
					if(msg[1]==4, {  //scramble also syncs
						lvSyncButton.doAction;
					});
				}.defer;
			}, \lvPitchLoopMode, recvPort:oscPort),

			OSCFunc({|msg| lvVolumeElement.value= msg[1]}, \lvVolume, recvPort:oscPort),
			OSCFunc({|msg|
				{
					var val= lvVelocitiesOnButtonElement.value;
					if(msg[1]==\toggle, {
						lvVelocitiesOnButtonElement.valueAction= lvVelocitiesOnButtonSpec.unmap(1-(val>0).binaryValue);
					}, {
						if(msg[1]==\mix, {
							if(lvVelocitiesOnButtonSpec.map(val)==2, {
								lvVelocitiesOnButtonElement.valueAction= 0;
							}, {
								lvVelocitiesOnButtonElement.valueAction= lvVelocitiesOnButtonSpec.unmap(2);
							});
						});
					});
				}.defer;
			}, \lvVelocitiesPattern, recvPort:oscPort),

			OSCFunc({|msg| avOnElement.valueAction= 1-avOnElement.value}, \avOn, recvPort:oscPort),
			OSCFunc({|msg| avVolumeElement.value= msg[1]}, \avVolume, recvPort:oscPort),
			OSCFunc({|msg|
				var mod= if(msg[2]==1, {131072}, {0});
				{snapshots.keyDownAction(msg[1].asString[0], mod)}.defer;
			}, \snapshots, recvPort:oscPort),

			//--from sKeyBpad
			OSCFunc({|msg|
				{win.view.keyDownAction.value(win.view, msg[1].asAscii, 0)}.defer;
			}, \keyBpad, recvPort:oscPort),

			//--from sKeyCpad
			OSCFunc({|msg| onElement.valueAction= 1-onElement.value}, \on, recvPort:oscPort),

			//--from sNanokontrol
			OSCFunc({|msg| metronomeElement.value= msg[1]}, \metronome, recvPort:oscPort),
			OSCFunc({|msg|
				{
					if(msg[1]+0.0125<lvPitchesRangeElement.value[1], {
						lvPitchesRangeElement.value= [msg[1], lvPitchesRangeElement.value[1]];

					}, {
						lvPitchesRangeElement.value= [msg[1], lvPitchesRangeElement.value[1]+0.0125].min(1);
					});
				}.defer;
			}, \lvPitchesArrayPatternRangeLo, recvPort:oscPort),
			OSCFunc({|msg|
				{
					if(msg[1]-0.0125>lvPitchesRangeElement.value[0], {
						lvPitchesRangeElement.value= [lvPitchesRangeElement.value[0], msg[1]];
					}, {
						lvPitchesRangeElement.value= [lvPitchesRangeElement.value[0]-0.0125, msg[1]].max(0);
					});
				}.defer;
			}, \lvPitchesArrayPatternRangeHi, recvPort:oscPort),
			OSCFunc({|msg|
				{
					if(msg[1]+0.0125<lvVelocitiesRangeElement.value[1], {
						lvVelocitiesRangeElement.value= [msg[1], lvVelocitiesRangeElement.value[1]];

					}, {
						lvVelocitiesRangeElement.value= [msg[1], lvVelocitiesRangeElement.value[1]+0.0125].min(1);
					});
				}.defer;
			}, \lvVelocitiesPatternRangeLo, recvPort:oscPort),
			OSCFunc({|msg|
				{
					if(msg[1]-0.0125>lvVelocitiesRangeElement.value[0], {
						lvVelocitiesRangeElement.value= [lvVelocitiesRangeElement.value[0], msg[1]];
					}, {
						lvVelocitiesRangeElement.value= [lvVelocitiesRangeElement.value[0]-0.0125, msg[1]].max(0);
					});
				}.defer;
			}, \lvVelocitiesPatternRangeHi, recvPort:oscPort),

			OSCFunc({|msg| avPitchBendElement.value= msg[1]}, \avPitchBend, recvPort:oscPort),
			OSCFunc({|msg| avPitchBendOnElement.valueAction= 1-avPitchBendOnElement.value}, \avPitchBendOn, recvPort:oscPort),
			OSCFunc({|msg| avSustainElement.value= msg[1]}, \avSustain, recvPort:oscPort),
			OSCFunc({|msg| avSustainOnElement.valueAction= 1-avSustainOnElement.value}, \avSustainOn, recvPort:oscPort),
			OSCFunc({|msg| avEntryDelayElement.value= msg[1]}, \avEntryDelayElement, recvPort:oscPort),
			OSCFunc({|msg| avDisplacementElement.value= msg[1]}, \avDisplacementElement, recvPort:oscPort),
			OSCFunc({|msg| avFalloutVoicesElement.value= msg[1]}, \avFalloutVoices, recvPort:oscPort),
			OSCFunc({|msg| avFalloutChordsElement.value= msg[1]}, \avFalloutChords, recvPort:oscPort),

			OSCFunc({|msg|
				{mainRecord.valueAction= 1-mainRecord.value}.defer;
			}, \mainRecord, recvPort:oscPort),

			//--from sSentograph
			OSCFunc({|msg| pitchElement.value= msg[1]}, \x, recvPort:oscPort),
			OSCFunc({|msg| rateElement.value= msg[1]}, \y, recvPort:oscPort),
			OSCFunc({|msg| velocityElement.value= msg[1]}, \z, recvPort:oscPort),

			//--from sText/sKeyboard
			OSCFunc({|msg|
				{
					lvPitchesArray= msg.copyRange(1, maxNumSteps).cpsmidi;
					lvPitchesNumber.value= lvPitchesArray.size;
					lvPitchesRangeElement.valueAction= [0, 1];
				}.defer;
			}, \patternFrequencies, recvPort:oscPort),
			OSCFunc({|msg|
				{
					lvVelocitiesArray= msg.copyRange(1, maxNumSteps);
					lvVelocitiesNumber.value= lvVelocitiesArray.size;
					lvVelocitiesRangeElement.valueAction= [0, 1];
				}.defer;
			}, \patternAmplitudes, recvPort:oscPort),
			OSCFunc({|msg|
				{
					avPitchesArray= msg.copyRange(1, maxNumVoices).cpsmidi.round.asInteger-60;
					avVoicesNumberElement.valueAction= avVoicesNumberSpec.unmap(avPitchesArray.size);
				}.defer;
			}, \frequencies, recvPort:oscPort),
			OSCFunc({|msg|
				{
					avVelocitiesArray= msg.copyRange(1, maxNumVoices);
					avVoicesNumberElement.valueAction= avVoicesNumberSpec.unmap(avVelocitiesArray.size);
				}.defer;
			}, \amplitudes, recvPort:oscPort),

			//--other/unused
			OSCFunc({|msg| attackElement.value= msg[1]}, \attack, recvPort:oscPort),
			OSCFunc({|msg| releaseElement.value= msg[1]}, \release, recvPort:oscPort),
			OSCFunc({|msg|
				{mainVolume.valueAction= msg[1]}.defer;
			}, \mainVolume, recvPort:oscPort)
		];
	};

	//--stream
	Pdefn(\sStream_dur, 0.125);  //rate slider (y)
	Pdefn(\sStream_bpm, 120);  //metronome slider
	Pdefn(\sStream_metronomeOn, 0);  //metronome button
	Pdefn(\sStream_note, 0);  //pitch slider (x)
	Pdefn(\sStream_pitches, 0);  //frequency pattern sequencer
	Pdefn(\sStream_velocity, 0);  //velocity slider (z)
	Pdefn(\sStream_velocities, 1);  //velocity pattern sequencer
	Pdefn(\sStream_velocitiesSelect, 0);
	Pdefn(\sStream_lvVelocities_index, 0);  //step in velocity pattern sequencer
	Pdefn(\sStream_lvPitches_index, 0);  //step in frequency pattern sequencer
	Pdefn(\sStream_lvScale, defaultScale);
	Pdefn(\sStream_avScale, defaultScale);
	Pdefn(\sStream_lvSustain, 1);  //lv sustain slider
	Pdefn(\sStream_avSustain, 1);  //av sustain slider
	Pdefn(\sStream_lvCstranspose, 0);
	Pdefn(\sStream_avCstranspose, 0);
	Pdefn(\sStream_lvOctave, defaultOctave);
	Pdefn(\sStream_avOctave, defaultOctave);
	createStream= {|numVoices|
		var pbind= Pbind(
			\type, \midi,
			\dur, Pswitch1([
				Pdefn(\sStream_dur),
				60/Pdefn(\sStream_bpm)*0.25  //semiquavers
			], Pdefn(\sStream_metronomeOn)).max(0.005),
			//TODO legato?
			\note, Pdefn(\sStream_note),  //x axis
			\pitches, Pdefn(\sStream_pitches)-60,  //pitch pattern sequencer
			\amp, Pswitch1([
				Pdefn(\sStream_velocity),  //off
				Pdefn(\sStream_velocities)*0.75,  //on
				Pdefn(\sStream_velocity)*Pdefn(\sStream_velocities)*1.25,  //mix
				Pdefn(\sStream_velocity)+Pdefn(\sStream_velocities)*0.5  //add
			], Pdefn(\sStream_velocitiesSelect)).min(1),
			\finish, {|ev|
				var m;
				if(ev.amp==0, {
					ev.type= \rest;
				}, {
					m= ev.midinote.value+ev.ctranspose;
					if(m.isArray, {
						if(m.any{|x| x>127} or:{m.any{|x| x<0}}, {
							ev.type= \rest;
						});
					}, {
						if(m>127 or:{m<0}, {
							ev.type= \rest;
						});
					});
				});
			}
		);
		Pdef(\sStream, Ppar(
			[
				Pbindf(pbind,  //lv
					\midiout, lvVst.midi,
					\chan, 0,
					\lag, 0,
					\sustain, Pdefn(\sStream_lvSustain),
					\scale, Pdefn(\sStream_lvScale),
					\note, Pfunc({|ev|
						switch(lvPitchesOnButtonSpec.map(lvPitchesOnButtonElement.value).asInteger,
							0, {ev.note.nearestInScale(ev.scale)},  //off
							1, {ev.pitches},  //on
							2, {[ev.pitches, ev.note.nearestInScale(ev.scale)]},  //mix
							3, {ev.pitches+ev.note.nearestInScale(ev.scale)}  //add
						);
					}),
					\ctranspose, Pdefn(\sStream_lvCstranspose),
					\octave, Pdefn(\sStream_lvOctave),
					\amp, Pfunc({|ev| ev.amp*lvOnElement.value}),
					\pitches_index, Pdefn(\sStream_lvPitches_index),
					\velocities_index, Pdefn(\sStream_lvVelocities_index),
					\callback, {|ev|
						if(ev.amp>0, {
							if(midiOut.notNil, {
								ev.midinote.asCollection.do{|m|
									midiOut.noteOn(ev.chan, m, ev.amp*127);
									if(lvSustainOnElement.value==0, {
										clock.sched(ev.sustain, {
											midiOut.noteOff(ev.chan, m, ev.amp*127);
											nil;
										});
									});
								};
							});
						});

						if(lvPitchesOnButtonElement.value>0, {
							lvPitchesIndex= ev.pitches_index;
							lvPitchesUsrAnimRedraw= true;
						});
						if(lvVelocitiesOnButtonElement.value>0, {
							lvVelocitiesIndex= ev.velocities_index;
							lvVelocitiesUsrAnimRedraw= true;
						});
					}
				)
			]++({|i|
				var avFollowInit= 60, avFollowLast= 0, avFollowCnt= 0;  //TODO hack
				Pbindf(pbind,  //av
					\midiout, avVst.midi,
					\chan, i+1,
					\lag, Pfunc({avDelaysArray[i]})*Pfunc({avEntryDelayElement.value}),
					\sustain, Pdefn(\sStream_avSustain),
					\scale, Pdefn(\sStream_avScale),
					\note, Pfunc({|ev|
						var range= (avPitchMinMaxRangeElement.value*2-1*maxChordPitch).round;
						var pseq= 0, note= ev.note;
						var res;
						if(lvPitchesOnButtonElement.value>0, {
							pseq= ev.pitches;
						});
						note= switch(avPitchesOnButtonSpec.map(avPitchesOnButtonElement.value).asInteger,
							0, {(note+avPitchesArray[i]).nearestInScale(ev.scale)},  //off
							1, {(pseq+avPitchesArray[i]).nearestInScale(ev.scale)},  //on
							2, {[pseq, note].collect{|x| (x+avPitchesArray[i]).nearestInScale(ev.scale)}},  //mix
							3, {(pseq+note+avPitchesArray[i]).nearestInScale(ev.scale)}  //add
						);
						note= switch(avFollowPopupSpec.map(avFollowPopupElement.value).asInteger,
							0, {note.wrap(*range)},  //parallel
							1, {  //opposite
								res= (avFollowInit= avFollowInit+(note-avFollowLast* -1)).wrap(*range);
								avFollowLast= note;
								res;
							},
							2, {  //fixed
								(note+avFollowCnt).wrap(*range);  //TODO
							},
							3, {  //up
								avFollowCnt= avFollowCnt+avFollowStepNumberSpec.map(avFollowStepNumberElement.value);
								(note+avFollowCnt).wrap(*range);
							},
							4, {  //down
								avFollowCnt= avFollowCnt-avFollowStepNumberSpec.map(avFollowStepNumberElement.value);
								(note+avFollowCnt).wrap(*range);
							}
						);
						note;
					}),
					\ctranspose, Pdefn(\sStream_avCstranspose),
					\octave, Pdefn(\sStream_avOctave)+Pfunc({if(avDisplacementElement.value.coin, {2.rand2}, {0})}),
					\amp, Pfunc({|ev|
						if(i==0, {
							ev.parent.falloutChords= (1-avFalloutChordsElement.value).coin.binaryValue;
						});
						ev.amp*avVelocitiesArray[i]*avOnElement.value
						*((1-avFalloutVoicesElement.value).coin).binaryValue*ev.parent.falloutChords;
					}),
					\callback, {|ev|
						if(ev.amp>0 and:{avOnElement.value==1}, {

							if(midiOut.notNil, {
								ev.midinote.asCollection.do{|m|
									if(ev.lag==0, {
										midiOut.noteOn(ev.chan, m, ev.amp*127);
									}, {
										clock.sched(ev.lag, {
											midiOut.noteOn(ev.chan, m, ev.amp*127);
											nil;
										});
									});
									if(avSustainOnElement.value==0, {
										clock.sched(ev.sustain+ev.lag, {
											midiOut.noteOff(ev.chan, m, ev.amp*127);
											nil;
										});
									});
								};
							});

							if(ev.lag==0, {
								avIndex= i;
								avPitchesUsrAnimRedraw= true;
								avVelocitiesUsrAnimRedraw= true;
							}, {
								clock.sched(ev.lag, {
									avIndex= i;
									avPitchesUsrAnimRedraw= true;
									avVelocitiesUsrAnimRedraw= true;
									nil;
								});
							});
						});
					}
				)
			}!numVoices)
		));
	};
	clock= TempoClock(1, queueSize:8192);

	//--midi
	MIDIClient.init;
	Platform.case(
		\osx, {
			if(MIDIClient.destinations.size<1 or:{MIDIClient.destinations[0].device.beginsWith("IAC").not}, {
				"Activate IAC in Audio MIDI Setup application".warn;
			});
		}
	);
	try{
		midiOut= MIDIOut(defaultMidiOut, MIDIClient.destinations[defaultMidiOut].uid);
		midiOut.latency= s.latency;
	};
	if(midiOut.isNil, {
		"could not initialize midiOut device % for recording".format(defaultMidiOut).warn;
	});

	//--audio
	SynthDef(\sStream, {|out= 0, atk= 0.1, rel= 1, on= 1, vol= 0|
		var onEnv= EnvGen.kr(Env.asr(atk, 1, rel), on);
		var lv= VSTPlugin.ar(nil, 2, id:\lv);
		var av= VSTPlugin.ar(nil, 2, id:\av);
		Out.ar(out, (lv+av)*vol.dbamp.lag*onEnv*0.7);
	}).add;
	sStream_bus= Bus.audio(s, 2);
	s.sync;
	Routine({
		mainOutSyn= Synth(\sStream, [
			\outBus, sStream_bus,
			\atk, attackSpec.map(attackElement.value),
			\rel, releaseSpec.map(releaseElement.value),
			\on, onElement.value
		]);
		lvVst= VSTPluginController(mainOutSyn, \lv);
		avVst= VSTPluginController(mainOutSyn, \av);
		VSTPlugin.search(s, action:{
			var terms= defaultPlug.split($*);
			var plug= VSTPlugin.plugins.detect{|p|
				var str= p.name.asString;
				terms.every{|t| str.contains(t)}
			};
			if(plug.isNil, {
				"sStream: default plugin not found".warn;
			}, {
				lvVst.open(plug.path);
				avVst.open(plug.path);
				s.sync;
				//lvVst.info.keysValuesDo{|k, v| [k, v].postln};  //debug
				//avVst.info.keysValuesDo{|k, v| [k, v].postln};  //debug
				lvVstEditorButton.states_([
					["LVVst:"++lvVst.info.name, palette.buttonText, palette.button]
				]);
				avVstEditorButton.states_([
					["AVVst:"++avVst.info.name, palette.buttonText, palette.button]
				]);
				lvVstProgramPopup.items= lvVst.programNames;
				avVstProgramPopup.items= avVst.programNames;
				lvProgramSelectPopups.do{|pop, i|
					pop.items= lvVst.programNames;
					pop.value= i+1;
				};
				avProgramSelectPopups.do{|pop, i|
					pop.items= avVst.programNames;
					pop.value= lvProgramSelectPopups.size+i+1;
				};

				Pdef(\sStream).clear;

				routineGui= Routine({
					inf.do{
						onElement.update;
						attackElement.update;
						releaseElement.update;
						pitchElement.update;
						rateElement.update;
						velocityElement.update;
						metronomeElement.update;
						metronomeOnElement.update;
						rateScaleElement.update;
						rateMultiplierElement.update;

						lvOnElement.update;
						lvPitchBendElement.update;
						lvPitchBendOnElement.update;
						lvSustainElement.update;
						lvSustainOnElement.update;
						lvScaleButtonElement.update;
						lvChromTranspElement.update;
						lvOctaveElement.update;
						lvPitchesOnButtonElement.update;
						lvPitchMinMaxRangeElement.update;
						if(lvPitchesUsrAnimRedraw, {
							lvPitchesUsrAnim.refresh;
							lvPitchesUsrAnimRedraw= false;
						});
						lvPitchesRangeElement.update;
						lvVelocitiesOnButtonElement.update;
						lvVolumeElement.update;
						if(lvVelocitiesUsrAnimRedraw, {
							lvVelocitiesUsrAnim.refresh;
							lvVelocitiesUsrAnimRedraw= false;
						});
						lvVelocitiesRangeElement.update;

						avOnElement.update;
						avPitchBendElement.update;
						avPitchBendOnElement.update;
						avSustainElement.update;
						avSustainOnElement.update;
						avPitchesOnButtonElement.update;
						avChromTranspElement.update;
						avOctaveElement.update;
						avVoicesNumberElement.update;
						avFollowStepNumberElement.update;
						avFollowPopupElement.update;
						avPitchMinMaxRangeElement.update;
						if(avPitchesUsrAnimRedraw, {
							avPitchesUsrAnim.refresh;
							avPitchesUsrAnimRedraw= false;
						});
						avVolumeElement.update;
						if(avVelocitiesUsrAnimRedraw, {
							avVelocitiesUsrAnim.refresh;
							avVelocitiesUsrAnimRedraw= false;
						});
						avEntryDelayElement.update;
						avDisplacementElement.update;
						avFalloutVoicesElement.update;
						avFalloutChordsElement.update;

						fps.reciprocal.wait;
					};
				}).play(AppClock);

				rateScaleElement.value= 0.5;

				lvOnElement.valueAction= 1;
				lvPitchBendElement.value= lvPitchBendSpec.unmap(lvPitchBendSpec.default);
				lvSustainElement.value= lvSustainSpec.unmap(lvSustainSpec.default);
				lvChromTranspElement.value= 0.5;
				lvOctaveElement.value= lvOctaveSpec.unmap(lvOctaveSpec.default);
				lvPatternsPopup.valueAction= 0;  //default patterns
				lvVolumeElement.value= 92/127;

				avPitchBendElement.value= avPitchBendSpec.unmap(avPitchBendSpec.default);
				avSustainElement.value= avSustainSpec.unmap(avSustainSpec.default);
				avChromTranspElement.value= 0.5;
				avOctaveElement.value= avOctaveSpec.unmap(avOctaveSpec.default);
				avFollowStepNumberElement.value= avFollowStepNumberSpec.unmap(avFollowStepNumberSpec.default);
				avFollowPopupElement.value= 0;  //default follow mode
				avChordsPopup.valueAction= 0;  //default chord
				avVolumeElement.value= 92/127;
				avEntryDelayElement.value= 1;
				avFalloutVoicesElement.valueAction= avFalloutVoicesSpec.unmap(avFalloutVoicesSpec.default);
				avFalloutChordsElement.valueAction= avFalloutChordsSpec.unmap(avFalloutChordsSpec.default);

				mainVolume.valueAction= defaultMainVolume;
				setupOscResponders.value;
				win.front;
			});
		});
	}).play(AppClock);
};
)
