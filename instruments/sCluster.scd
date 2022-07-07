//f.olofsson 2019

(
//--settings
var oscPort= 13064;
var maxNumVoices= 100;  //maximum number of voices for the synth
var winRect= Rect(242, 242, 900, 780);  //x, y, w, h
var palette= SGUI.palette((highlight: Color.yellow(2/3, 0.5)));
var fnt= SGUI.font;
var fnt2= SGUI.font.copy.size_(10);
var fps= 25;
var minFreq= 9, maxFreq= 9999;  //Hz
var transposeKeys= #[
	$Q, $W, $E, $R, $T, $Y, $U, $I, $O, $P, $Å, $^
];
var snapshotKeys= #[  //more can be added
	[$A, $S, $D, $F, $G, $H, $J, $K],
	[$Z, $X, $C, $V, $B, $N, $M, $,]
];
var bankKeys= #[  //more can be added
	$1, $2, $3, $4, $5, $6, $7, $8, $9
];
var snapshotFiles= [  //name and file (both can be changed)
	\Bank1 -> "sCluster_snapshots_Bank1.scd",
	\Bank2 -> "sCluster_snapshots_Bank2.scd",
	\Bank3 -> "sCluster_snapshots_Bank3.scd",
	\Bank4 -> "sCluster_snapshots_Bank4.scd",
	\Bank5 -> "sCluster_snapshots_Bank5.scd",
	\Bank6 -> "sCluster_snapshots_Bank6.scd",
	\Bank7 -> "sCluster_snapshots_Bank7.scd",
	\Bank8 -> "sCluster_snapshots_Bank8.scd",
	\Bank9 -> "sCluster_snapshots_Bank9.scd"
];

//--defaults
var defaultNumVoices= 15;
var defaultAttack= 2;
var defaultRelease= 4;
var defaultFrequencies= {|i| 50.exprand(2500)}!maxNumVoices;
var defaultAmplitudes= {|i| 90/defaultFrequencies[i]}!maxNumVoices;
var defaultFreqRange= #[0.05, 0.95];  //minmax percent
var defaultFreqLfoDepth= 0;  //percent
var defaultFreqLfoRate= 0.1;  //Hz
var defaultAmpRange= #[0, 0.9];  //minmax percent
var defaultAmpLfoDepth= 0;  //percent
var defaultAmpLfoRate= 0.1;  //Hz
var defaultFreqGlissTime= 1;  //seconds
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
	var buffer, fileIndex, loadBuffer;
	var typeFromPopup, itemFromPopup, filePathFromPopup, filePathInFolderFromPopup;
	var cluster, createCluster;
	var usrPadding= Size(25, 20);
	var usrRedraw= false;
	var voices= {|i| (
		position: Point(  //coordinates
			defaultAmplitudes[i]/2,
			defaultFrequencies[i].explin(minFreq, maxFreq, 0, 1)
		),
		amplitude: defaultAmplitudes[i],
		frequency: defaultFrequencies[i].explin(minFreq, maxFreq, 0, 1),
		distortion: 0,
		index: i,
		selected: false
	)}!maxNumVoices;
	var ampRangeOffset;  //-1.0 to 1.0
	var mouseClick, mouseDist;  //points
	var selectedRect, selectedRectTask;
	var normalizedX, normalizedY;  //functions
	var closestVoice;
	var updateAllVoices, updateSelectedVoice;
	var setupOscResponders, oscResponders;
	var routineGui;
	var sCluster_bus;
	var mainOutSyn;

	//--gui
	var glissButton, xFadeButton;
	var freqRangeElement= SGUIelementRange();
	var freqRangeSpec= ControlSpec(minFreq, maxFreq, 'exp', 0, 99, "Hz");
	var ampRangeElement= SGUIelementRange();
	var usr, usrAnim;
	var freqLfoDepthElement= SGUIelement();
	var freqLfoDepthSpec= ControlSpec(0, 100, 'lin', 1, defaultFreqLfoDepth, "%");
	var freqLfoRateElement= SGUIelement();
	var freqLfoRateSpec= ControlSpec(0.025, 25, 'exp', 0, defaultFreqLfoRate, "Hz");
	var ampLfoDepthElement= SGUIelement();
	var ampLfoDepthSpec= ControlSpec(0, 100, 'lin', 1, defaultAmpLfoDepth, "%");
	var ampLfoRateElement= SGUIelement();
	var ampLfoRateSpec= ControlSpec(0.025, 25, 'exp', 0, defaultAmpLfoRate, "Hz");
	var scalesTunings;
	var curvature;
	var masterTuning;
	var glissTime;
	var typePopup;
	var nextButton, randButton, lockButton, folderText;
	var numVoicesNumber, onButton, attackNumber, releaseNumber;
	var transposition;
	var snapshots;
	var mainBalanceElement= SGUIelement();
	var mainVolume;
	var mainReverbElement= SGUIelement();
	var mainRecord;
	var backgroundImage;
	var win= Window("sCluster", winRect);
	win.layout= HLayout(

		VLayout(
			HLayout(
				glissButton= Button().states_([
					["  Gliss", palette.buttonText, palette.button],
					["•Gliss", palette.buttonText, palette.highlight]
				]),
				xFadeButton= Button().states_([
					["XFade", palette.buttonText, palette.button]
				])
			),
			HLayout(
				VLayout(
					View().fixedSize_(15@5),
					freqRangeElement.addView(RangeSlider().orientation_(\vertical).minSize_(15@180)),
					View().fixedSize_(15@5)
				),
				[StackLayout(
					usr= UserView().minSize_(500@100),
					usrAnim= UserView().minSize_(500@100)
				).mode_(\stackAll), stretch:1]
			),
			HLayout(
				View().fixedSize_(usrPadding.width+15@15),
				ampRangeElement.addView(RangeSlider().orientation_(\horizontal).minWidth_(500).fixedHeight_(15))
			),

			StaticText().string_("LFOs"),
			HLayout(
				StaticText().string_("Fre").fixedWidth_(25),
				freqLfoDepthElement.addView(Slider().orientation_(\horizontal)),
				freqLfoDepthElement.addView(NumberBox().step_(1).fixedWidth_(50), freqLfoDepthSpec),
				SGUI.shrink(StaticText().string_("%")),
				freqLfoRateElement.addView(Slider().orientation_(\horizontal)),
				freqLfoRateElement.addView(NumberBox().decimals_(3).fixedWidth_(50), freqLfoRateSpec),
				SGUI.shrink(StaticText().string_("Hz"))
			),
			HLayout(
				StaticText().string_("Amp").fixedWidth_(25),
				ampLfoDepthElement.addView(Slider().orientation_(\horizontal)),
				ampLfoDepthElement.addView(NumberBox().step_(1).fixedWidth_(50), ampLfoDepthSpec),
				SGUI.shrink(StaticText().string_("%")),
				ampLfoRateElement.addView(Slider().orientation_(\horizontal)),
				ampLfoRateElement.addView(NumberBox().decimals_(3).fixedWidth_(50), ampLfoRateSpec),
				SGUI.shrink(StaticText().string_("Hz"))
			),

			HLayout(
				(scalesTunings= SGUIscalesTunings().fixedHeight_(200)).view,
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
				SGUI.shrink(StaticText().string_("Synth")),
				[typePopup= PopUpMenu(), align:\left],
				nextButton= Button().states_([["next"]]).fixedWidth_(30),
				randButton= Button().states_([["rand"]]).fixedWidth_(30),
				lockButton= Button().states_([
					["lock", palette.buttonText, palette.button],
					["lock", palette.buttonText, palette.highlight]
				]).fixedWidth_(30),
				folderText= StaticText().minHeight_(25),
				View()
			),
			HLayout(
				SGUI.shrink(StaticText().string_("Number of Voices")),
				numVoicesNumber= NumberBox().scroll_(false).step_(1)
			),
			onButton= Button().states_([
				["Cluster Off", palette.buttonText, palette.button],
				["Cluster On", palette.buttonText, palette.highlight]
			]),
			HLayout(
				SGUI.shrink(StaticText().string_("Attack")),
				[attackNumber= NumberBox().scroll_step_(0.1).decimals_(3), align:\left],
				SGUI.shrink(StaticText().string_("Release")),
				[releaseNumber= NumberBox().scroll_step_(0.1).decimals_(3), align:\left]
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
				(mainRecord= SGUIrecord(s, SInstruments.recordingsDir, "sCluster_")).view
			),
			View()
		)
	);
	SGUI.report(win);
	SGUI.adapt(win);
	backgroundImage= Image(200, 200).draw({|img|
		Pen.fillColor= palette.highlight.complementary;
		Pen.translate(img.width*0.5, img.height*0.5);
		500.do{Pen.addRect(Rect(20.gauss(20), 20.gauss(20), 1, 1))};
		Pen.fill;
		Pen.translate(img.width*0.25, img.height*0.25);
		200.do{Pen.addRect(Rect(20.gauss(20), 20.gauss(20), 2, 2))};
		Pen.fill;
	});
	win.view.setBackgroundImage(backgroundImage, 10, 0.25);
	if(SGUI.currentTheme!=\dark, {
		win.view.children.select{|v| v.isKindOf(Slider) or:{v.isKindOf(RangeSlider)}}.do{|v|
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
		{key==65 and:{mod.isCmd}} {  //cmd+a select all
			voices.do{|voice| voice.selected= true};
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
		NetAddr.localAddr.sendMsg(\closed, \sCluster);
		routineGui.stop;
		selectedRectTask.stop;
		oscResponders.do{|x| x.free};
		cluster.set(\rel, 1);
		cluster.release;
		{
			buffer.free;
			mainOutSyn.free;
			sCluster_bus.free;
		}.defer(1);
	};
	CmdPeriod.doOnce({
		cluster.free;
		cluster= nil;
		mainOutSyn= nil;
	});


	glissButton.action= {|view|
		updateAllVoices.value;
	};
	xFadeButton.action= {|view|
		updateAllVoices.value(true);
	};

	freqRangeElement.action= {|val|
		{
			updateAllVoices.value;
			usrRedraw= true;
		}.defer;
	};

	ampRangeElement.action= {|val|
		{
			ampRangeOffset= (val[1]-val[0])*0.5+val[0]-0.5*2;
			updateAllVoices.value;
			usrRedraw= true;
		}.defer;
	};
	ampRangeOffset= 0;

	usrAnim.background= Color.clear;
	usrAnim.clearOnRefresh= true;
	usrAnim.frameRate= fps;
	usrAnim.acceptsMouse= false;
	usrAnim.drawFunc= {|usr|
		var freqs, dists, amps;
		var uw= usr.bounds.width-usrPadding.width;
		var uw2= uw-5;  //right side margin
		var uh= usr.bounds.height-(usrPadding.height*2);
		Pen.translate(usrPadding.width, uh+usrPadding.height);
		Pen.font= fnt2;
		Pen.strokeColor= palette.buttonText;
		Pen.fillColor= palette.highlight;
		freqs= cluster.getFrequencies.last;
		dists= cluster.getDistortions.last;
		amps= cluster.getAmplitudes.last;
		cluster.numChannels.do{|i|
			var voice= voices[i];
			var str= SGUI.fixDec(freqs[i], 2);
			var qx= amps[i]+dists[i]*0.5*uw2;
			var qy= freqs[i].explin(
				freqRangeSpec.map(freqRangeElement.value[0]),
				freqRangeSpec.map(freqRangeElement.value[1]),
				0,
				0-uh
			);
			var px= voice.amplitude+voice.distortion*0.5*uw2;
			var py= voice.frequency*(0-uh);
			var q= Point(qx, qy);
			var p= Point(px, py);
			if((px-qx).abs+(py-qy).abs>3, {
				Pen.moveTo(p);
				Pen.lineTo(q);
			});
			Pen.addRect(Rect.aboutPoint(q, 1, 1));
			if(voice.selected, {
				Pen.addOval(Rect.aboutPoint(p, 3, 3));
			});
			qx= qx.min(uw-20);
			qy= qy+10;
			Pen.stringCenteredIn(str, Rect.aboutPoint(Point(qx, qy), 25, fnt2.size));
		};
		Pen.stroke;

		if(closestVoice.notNil, {
			Pen.addOval(
				Rect.aboutPoint(
					Point(
						closestVoice.amplitude+closestVoice.distortion*0.5*uw2,
						closestVoice.frequency*(0-uh)
					),
					5,
					5
				)
			);
			if(mouseClick.notNil, {
				Pen.addOval(Rect.aboutPoint(mouseClick*[uw, 0-uh], 5, 5));
			});
			Pen.stroke;
		}, {
			if(selectedRect.notNil, {
				Pen.strokeRect(
					Rect(
						selectedRect.left*uw,
						0-(selectedRect.top*uh),
						selectedRect.width*uw,
						0-(selectedRect.height*uh)
					)
				);
			});
		});
	};

	usr.background= Color.clear;
	usr.clearOnRefresh= true;
	usr.drawFunc= {|usr|
		var numFreqMarkings= 10;
		var numDistMarkings= 11;
		var numAmpMarkings= 11;
		var up= usrPadding.width;
		var uw= usr.bounds.width-up;
		var uh= usr.bounds.height-(usrPadding.height*2);
		var str, strWidth, y;
		Pen.font= fnt2;
		Pen.fillColor= palette.buttonText;

		Pen.push;
		Pen.translate(up, uh+usrPadding.height);
		Pen.strokeColor= Color.grey(0.5, 0.5);
		str= freqRangeSpec.map(freqRangeElement.value[0]).asInteger.asString++"Hz";
		y= freqRangeElement.value[0].linlin(0, 1, 0, 0-uh);
		Pen.stringLeftJustIn(str, Rect.aboutPoint(Point(0, 0), up, 10));
		str= freqRangeSpec.map(freqRangeElement.value[1]).asInteger.asString;
		y= freqRangeElement.value[1].linlin(0, 1, 0, 0-uh);
		Pen.stringLeftJustIn(str, Rect.aboutPoint(Point(0, 0-uh), up, 10));
		numFreqMarkings.do{|i|
			var freq= i.linexp(0, numFreqMarkings-1, minFreq, maxFreq);
			if(freq>=freqRangeSpec.map(freqRangeElement.value[0]) and:{
				freq<=freqRangeSpec.map(freqRangeElement.value[1])}, {
				y= freq.explin(
					freqRangeSpec.map(freqRangeElement.value[0]),
					freqRangeSpec.map(freqRangeElement.value[1]),
					0,
					0-uh
				);
				Pen.moveTo(Point(0, y));
				Pen.lineTo(Point(uw, y));
				if(y>(5-uh) and:{y<(-5)}, {
					str= freq.asInteger.asString;
					Pen.stringLeftJustIn(str, Rect.aboutPoint(Point(0, y), up, 10));
				});
			});
		};
		Pen.stroke;
		Pen.pop;

		Pen.push;
		Pen.translate(up, fnt2.size*0.5);
		str= "Distortion";
		strWidth= str.bounds.width(fnt2);
		Pen.stringCenteredIn(str, Rect.aboutPoint(Point(uw*0.5-strWidth, 0), strWidth*0.5, fnt2.size));
		numDistMarkings.do{|i|
			var dist= i.linlin(0, numDistMarkings-1, 0, 1);
			var x= i.linlin(0, numDistMarkings-1, 0.5, 1)*uw;
			str= SGUI.fixDec(dist, 1);
			Pen.stringCenteredIn(str, Rect.aboutPoint(Point(x, 0), 20, fnt2.size));
		};
		Pen.pop;

		Pen.push;
		Pen.translate(up, usr.bounds.height-(fnt2.size*0.5));
		str= "Amplitude";
		strWidth= str.bounds.width(fnt2);
		Pen.stringCenteredIn(str, Rect.aboutPoint(Point(uw*0.5+strWidth, 0), strWidth*0.5, fnt2.size));
		numAmpMarkings.do{|i|
			var amp= i.linlin(0, numAmpMarkings-1, 0, 1);
			var x= i.linlin(0, numAmpMarkings-1, 0, 0.5)*uw;
			str= SGUI.fixDec(amp, 1);
			Pen.stringCenteredIn(str, Rect.aboutPoint(Point(x, 0), 20, fnt2.size));
		};
		Pen.pop;
	};
	mouseDist= Point(0, 0);
	usr.mouseDownAction= {|view, x, y, mod|
		mouseClick= Point(normalizedX.value(x), normalizedY.value(y));
		if(closestVoice.isNil or:{closestVoice.selected.not}, {

			//--clicking an unselected voice or outside
			cluster.numChannels.do{|i|
				voices[i].selected= false;
			};
			if(closestVoice.isNil, {
				selectedRectTask.start;
			}, {
				closestVoice.selected= true;
				updateSelectedVoice.value(closestVoice);
			});
		});
	};
	usr.mouseMoveAction= {|view, x, y, mod|
		var mouseDrag, angle;
		mouseDrag= Point(normalizedX.value(x), normalizedY.value(y));
		if(mod.isShift, {  //lock axis
			angle= atan2(mouseClick.y-mouseDrag.y, mouseClick.x-mouseDrag.x);
			if(sin(angle).abs>0.9, {
				mouseDrag= Point(mouseClick.x, mouseDrag.y);
			}, {
				if(cos(angle).abs>0.9, {
					mouseDrag= Point(mouseDrag.x, mouseClick.y);
				});
			});
		});
		mouseDist= mouseDrag-mouseClick;

		if(closestVoice.isNil, {

			//--dragging selection rectangle
			selectedRect= Rect.fromPoints(mouseClick, mouseDrag);
		}, {

			//--dragging selected voices
			cluster.numChannels.do{|i|
				var voice= voices[i];
				if(voice.selected, {
					voice.frequency= voice.position.y+mouseDist.y;
					updateSelectedVoice.value(voice);
				});
			};
		});
	};
	usr.mouseUpAction= {|view, x, y, mod|
		if(selectedRect.isNil, {

			//--update positions after dragging
			cluster.numChannels.do{|i|
				var voice= voices[i];
				if(voice.selected, {
					voice.position= voice.position+mouseDist;
				});
			};
		});
		selectedRectTask.stop;
		selectedRect= nil;
		mouseClick= nil;
		mouseDist= Point(0, 0);
	};
	usr.parent.acceptsMouseOver= true;
	usr.mouseOverAction= {|view, x, y|
		var nx= normalizedX.value(x);
		var ny= normalizedY.value(y);
		var minDist= inf;
		cluster.numChannels.do{|i|
			var voice= voices[i];
			var rx= voice.position.x+ampRangeOffset;
			var dist= (rx.clip(0, 1)-nx).abs+(voice.frequency-ny).abs;  //manhattan
			if(dist<minDist, {
				minDist= dist;
				closestVoice= voice;
			});
		};
		if(minDist>0.05, {  //reset if no voice close enough
			closestVoice= nil;
		});
	};

	selectedRectTask= Task({
		inf.do{
			if(selectedRect.notNil, {
				cluster.numChannels.do{|i|
					var voice= voices[i];
					var rx= (voice.position.x+ampRangeOffset).clip(0, 1);
					voice.selected= rx>=selectedRect.left and:{
						rx<=selectedRect.right and:{
							voice.frequency>=selectedRect.top and:{
								voice.frequency<=selectedRect.bottom
							}
						}
					};
				};
			});
			0.1.wait;
		};
	}, AppClock);

	normalizedX= {|x|
		x.linlin(usrPadding.width, usr.bounds.width, 0, 1);
	};
	normalizedY= {|y|
		y.linlin(usrPadding.height, usr.bounds.height-usrPadding.height, 1, 0);
	};

	updateAllVoices= {|xfade= false|
		var freqs, dists, amps;
		if(xfade or:{glissButton.value==1}, {
			freqs= List.new;
			dists= List.new;
			amps= List.new;
			cluster.numChannels.do{|i|
				var voice= voices[i];
				var x= (voice.position.x+ampRangeOffset).clip(0, 1);
				var freq= voice.frequency.linexp(
					0,
					1,
					freqRangeSpec.map(freqRangeElement.value[0]),
					freqRangeSpec.map(freqRangeElement.value[1])
				);
				if(voice.selected, {
					freq= scalesTunings.tune(freq, transposition.value);
				}, {
					freq= scalesTunings.tune(freq, 0);
				});
				freq= masterTuning.tune(freq).clip(minFreq, maxFreq);
				voice.position.y= freq.explin(
					freqRangeSpec.map(freqRangeElement.value[0]),
					freqRangeSpec.map(freqRangeElement.value[1]),
					0,
					1
				);
				voice.frequency= voice.position.y;
				voice.distortion= (x*2).clip(1, 2)-1;
				voice.amplitude= (x*2).clip(0, 1);
				freqs.add(freq);
				dists.add(voice.distortion);
				amps.add(voice.amplitude);
			};
			cluster.setAmplitudes(amps);
			cluster.setDistortions(dists);
			if(xfade, {
				cluster.xsetFrequencies(freqs);
			}, {
				cluster.setFrequencies(freqs);
			});
			transposition.value= 0;
		});
	};
	updateSelectedVoice= {|voice|
		var x= voice.position.x+ampRangeOffset+mouseDist.x;
		var freq= voice.frequency.linexp(
			0,
			1,
			freqRangeSpec.map(freqRangeElement.value[0]),
			freqRangeSpec.map(freqRangeElement.value[1])
		);
		freq= scalesTunings.tune(freq, transposition.value).clip(minFreq, maxFreq);
		voice.distortion= (x*2).clip(1, 2)-1;
		voice.amplitude= (x*2).clip(0, 1);
		if(glissButton.value==1, {
			cluster.controllers.last.frequencies.syn.seti(\frequencies, voice.index, freq);
			cluster.controllers.last.distortions.syn.seti(\distortions, voice.index, voice.distortion);
			cluster.controllers.last.amplitudes.syn.seti(\amplitudes, voice.index, voice.amplitude);
		});
	};

	freqLfoDepthElement.action= {|val|
		cluster.set(\fLfoDepth, freqLfoDepthSpec.map(val)/500);
	};
	freqLfoRateElement.action= {|val|
		cluster.set(\fLfoRate, freqLfoRateSpec.map(val));
	};

	ampLfoDepthElement.action= {|val|
		cluster.set(\aLfoDepth, ampLfoDepthSpec.map(val)/100);
	};
	ampLfoRateElement.action= {|val|
		cluster.set(\aLfoRate, ampLfoRateSpec.map(val));
	};

	scalesTunings.action= {
		updateAllVoices.value;
	};

	curvature.action= {|key, val|
		cluster.set(key, val);
	};

	masterTuning.action= {
		updateAllVoices.value;
	};

	glissTime.action= {|val|
		cluster.set(\lag, val);
	};


	typePopup.items= [SCluster.type];
	SCluster.allSubclasses.collect{|class|
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
		createCluster.value;
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
		folderText.string= path.basename;
		s.sync;
		buffer.normalize;
		s.sync;
	};
	fileIndex= 0;

	nextButton.action= {|view, mod|
		if(cluster.class.type==\File, {
			cluster.set(\pos, 0!cluster.numChannels, \trig, 1);
		}, {
			if(cluster.class.type==\Folder, {
				if(mod.isShift, {  //shift click step backwards
					fileIndex= fileIndex-1;
				}, {  //no shift one step forward
					fileIndex= fileIndex+1;
				});
				Routine({
					var oldBuffer= buffer;
					loadBuffer.value(filePathInFolderFromPopup.value);
					cluster.set(\buf, buffer, \trig, 1);
					oldBuffer.free;
				}).play(AppClock);
			});
		});
	};
	randButton.action= {|view, mod|
		if(cluster.class.type==\File, {
			cluster.set(\loop, 1-view.value);  //wait a random time and then retrigger
		}, {
			if(cluster.class.type==\Folder, {
				if(mod.isShift, {  //shift click jump back or forth a few steps
					fileIndex= fileIndex+(5.linrand+1*[1, -1].choose);
				}, {  //no shift random selection
					fileIndex= 9999.rand;
				});
				Routine({
					var oldBuffer= buffer;
					loadBuffer.value(filePathInFolderFromPopup.value);
					cluster.set(\buf, buffer, \trig, 1);
					oldBuffer.free;
				}).play(AppClock);
			});
		});
	};
	lockButton.action= {|view, mod|
		if(cluster.class.type==\File or:{cluster.class.type==\Folder}, {
			cluster.set(\rateBlend, 1-view.value*2-1);
		});
	};

	numVoicesNumber.value= defaultNumVoices;
	numVoicesNumber.action= {|view|
		view.value= view.value.clip(1, maxNumVoices).asInteger;
		if(cluster.numChannels!=view.value, {
			createCluster.value;
		});
	};

	onButton.action= {|view|
		cluster.set(\on, view.value);
	};

	attackNumber.value= defaultAttack;
	attackNumber.action= {|view|
		view.value= view.value.clip(0, 999);
		cluster.set(\atk, view.value);
	};
	releaseNumber.value= defaultRelease;
	releaseNumber.action= {|view|
		view.value= view.value.clip(0, 999);
		cluster.set(\rel, view.value);
	};

	transposition.action= {|value, diff|
		cluster.numChannels.do{|i|
			var voice= voices[i];
			if(voice.selected, {
				updateSelectedVoice.value(voice);
			});
		};
	};
	transposition.scalesTunings= scalesTunings;

	snapshots.recallFunctions= (
		snapshotInstrument: {},
		snapshotVersion: {},
		voices: {|val| voices= val.deepCopy; updateAllVoices.value},
		type: {|val|
			var item= val.typePopup;
			var type= typeFromPopup.value(item);
			var num= val.numVoicesNumber;
			var index= val.fileIndex;
			if(typePopup.items[typePopup.value]!=item or:{fileIndex!= index}, {
				numVoicesNumber.value= num;
				fileIndex= index;
				typePopup.valueAction= typePopup.items.indexOf(item)
				??{("sCluster: typePopup"+item+"not found").warn; 0};
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
		snapshotInstrument: \sCluster,
		snapshotVersion: 1.1,
		masterTuning: masterTuning,
		scalesTunings: scalesTunings,
		glissButton: glissButton,
		freqRangeElement: freqRangeElement,
		ampRangeElement: ampRangeElement,
		freqLfoDepthElement: freqLfoDepthElement,
		freqLfoRateElement: freqLfoRateElement,
		ampLfoDepthElement: ampLfoDepthElement,
		ampLfoRateElement: ampLfoRateElement,
		curvature: curvature,
		glissTime: glissTime,
		onButton: onButton,
		attackNumber: attackNumber,
		releaseNumber: releaseNumber,
		mainBalanceElement: mainBalanceElement,
		mainVolume: mainVolume,
		mainReverbElement: mainReverbElement,
		voices: {voices.deepCopy},
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
			OSCFunc({|msg|
				{onButton.valueAction= 1-onButton.value}.defer;
			}, \on, recvPort:oscPort),

			//--from sNanokontrol
			OSCFunc({|msg| ampLfoDepthElement.value= msg[1]}, \ampLfoDepth, recvPort:oscPort),
			OSCFunc({|msg| ampLfoRateElement.value= msg[1]}, \ampLfoRate, recvPort:oscPort),
			OSCFunc({|msg| freqLfoDepthElement.value= msg[1]}, \freqLfoDepth, recvPort:oscPort),
			OSCFunc({|msg| freqLfoRateElement.value= msg[1]}, \freqLfoRate, recvPort:oscPort),
			OSCFunc({|msg| ampRangeElement.value= [msg[1], msg[2]]}, \ampRangeMinMax, recvPort:oscPort),
			OSCFunc({|msg|  //val(float 0-1)
				var span= (ampRangeElement.value[1]-ampRangeElement.value[0])*0.5;
				var val= msg[1].clip(span, 1-span);
				ampRangeElement.value= [val-span, val+span];
			}, \ampRange, recvPort:oscPort),
			OSCFunc({|msg| freqRangeElement.value= [msg[1], msg[2]]}, \freqRangeMinMax, recvPort:oscPort),
			OSCFunc({|msg|  //val(float 0-1)
				var span= (freqRangeElement.value[1]-freqRangeElement.value[0])*0.5;
				var val= msg[1].clip(span, 1-span);
				freqRangeElement.value= [val-span, val+span];
			}, \freqRange, recvPort:oscPort),
			OSCFunc({|msg|
				{curvature.valueActionNorm= [msg[1], 0]}.defer;
			}, \curvature, recvPort:oscPort),
			OSCFunc({|msg|
				{glissTime.valueActionNorm= msg[1]}.defer;
			}, \glissTime, recvPort:oscPort),
			OSCFunc({|msg|
				mainReverbElement.value= msg[1];
			}, \mainReverb, recvPort:oscPort),
			OSCFunc({|msg|
				{mainVolume.valueAction= msg[1]}.defer;
			}, \mainVolume, recvPort:oscPort),
			OSCFunc({|msg|
				{mainRecord.valueAction= 1-mainRecord.value}.defer;
			}, \mainRecord, recvPort:oscPort),

			//--from sSentograph
			OSCFunc({|msg|
				cluster.set(\amp, msg[1]);
			}, \amp, recvPort:oscPort),

			//--from sText/sKeyboard
			OSCFunc({|msg|
				{
					numVoicesNumber.valueAction= (msg.size-1).clip(1, maxNumVoices);
					{
						msg[1..voices.size].do{|a, i|
							voices[i].position.x= a*0.5;  //go over 1.0 for distortion
						};
						updateAllVoices.value;
					}.defer(0.25);
				}.defer;
			}, \amplitudes, recvPort:oscPort),
			OSCFunc({|msg|
				{
					numVoicesNumber.valueAction= (msg.size-1).clip(1, maxNumVoices);
					{
						msg[1..voices.size].do{|f, i|
							voices[i].frequency= f.explin(
								freqRangeSpec.map(freqRangeElement.value[0]),
								freqRangeSpec.map(freqRangeElement.value[1]),
								0,
								1
							);
						};
						updateAllVoices.value;
					}.defer(0.25);
				}.defer;
			}, \frequencies, recvPort:oscPort),

			//--other/unused
			OSCFunc({|msg|
				{attackNumber.valueAction= msg[1]}.defer;
			}, \attack, recvPort:oscPort),
			OSCFunc({|msg|
				{releaseNumber.valueAction= msg[1]}.defer;
			}, \release, recvPort:oscPort),
			OSCFunc({|msg|
				mainBalanceElement.value= msg[1]+1/2;
			}, \mainBalance, recvPort:oscPort)
		];
	};


	//--cluster
	createCluster= {
		var newNumChannels= numVoicesNumber.value.asInteger;
		var args;
		var activeVoices;
		var oldBuffer;
		var type= typeFromPopup.value;
		var class= ([SCluster]++SCluster.allSubclasses).detect{|c| c.type==type};
		var firstTime= cluster.isNil;

		if(firstTime, {  //only at startup
			args= [
				\on, onButton.value,
				\atk, attackNumber.value,
				\rel, releaseNumber.value,
				\frequencies, defaultFrequencies.copyFromStart(newNumChannels-1),
				\amplitudes, defaultAmplitudes.copyFromStart(newNumChannels-1)
			];
		}, {  //when changing typePopup or numVoices
			if(cluster.class.type==\File or:{cluster.class.type==\Folder}, {
				oldBuffer= buffer;
				cluster.release(nil, {oldBuffer.free});
			}, {
				cluster.release(nil);
			});

			args= cluster.arguments;
			args.put(\buf, nil);
			args.put(\on, onButton.value);
			activeVoices= voices.copyFromStart(newNumChannels-1);
			args.put(\frequencies, activeVoices.collect{|v| v.frequency.linexp(
				0,
				1,
				freqRangeSpec.map(freqRangeElement.value[0]),
				freqRangeSpec.map(freqRangeElement.value[1])
			)});
			args.put(\distortions, activeVoices.collect{|v| v.distortion});
			args.put(\amplitudes, activeVoices.collect{|v| v.amplitude});
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
					folderText.visible= true;
				},
				\Folder, {
					loadBuffer.value(filePathInFolderFromPopup.value);
					args= args++[\buf, buffer];
					nextButton.states_([["next"]]);
					nextButton.visible= true;
					randButton.states_([["rand"]]);
					randButton.visible= true;
					lockButton.visible= true;
					folderText.visible= true;
				},
				{
					nextButton.visible= false;
					randButton.visible= false;
					lockButton.visible= false;
					folderText.visible= false;
				}
			);
			//"_________".postln; args.pairsDo{|a, b| [a, b].postln};  //debug
			cluster= class.new(newNumChannels, outbus: sCluster_bus, args: args);
			~cluster= cluster;

			if(firstTime, {
				{
					glissButton.value= 1;
					freqRangeElement.value= defaultFreqRange;
					freqLfoDepthElement.value= freqLfoDepthSpec.unmap(freqLfoDepthSpec.default);
					freqLfoRateElement.value= freqLfoRateSpec.unmap(freqLfoRateSpec.default);
					ampRangeElement.value= defaultAmpRange;
					ampLfoDepthElement.value= ampLfoDepthSpec.unmap(ampLfoDepthSpec.default);
					ampLfoRateElement.value= ampLfoRateSpec.unmap(ampLfoRateSpec.default);
					glissTime.valueAction= defaultFreqGlissTime;
					curvature.valueAction= #[-4, 0];
					mainVolume.valueAction= defaultMainVolume;
					setupOscResponders.value;
					usrAnim.animate= true;
					routineGui= Routine({
						inf.do{
							if(usrRedraw, {
								usr.refresh;
								usrRedraw= false;
							});
							freqRangeElement.update;
							ampRangeElement.update;
							freqLfoDepthElement.update;
							freqLfoRateElement.update;
							ampLfoDepthElement.update;
							ampLfoRateElement.update;
							mainBalanceElement.update;
							mainReverbElement.update;
							fps.reciprocal.wait;
						};
					}).play(AppClock);
					win.front;
				}.defer;
			});
		}).play(AppClock);
	};
	sCluster_bus= Bus.audio(s, 2);
	mainOutSyn= SynthDef(\clusterMainOut, {|out= 0, pan= 0, vol= 0, verbMix= -1|
		var snd= In.ar(\sCluster_bus.ir, 2);
		snd= Balance2.ar(snd[0], snd[1], pan.lag(0.03));
		snd= snd*vol.dbamp.lag;
		snd= XFade2.ar(snd, GVerb.ar(snd, 90, 4)*0.75, verbMix.lag);
		Out.ar(out, Limiter.ar(snd));
	}).play(args: [\sCluster_bus, sCluster_bus], addAction: \addToTail);
	createCluster.value;
};
)
