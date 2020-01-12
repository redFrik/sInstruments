//f.olofsson 2020

//related: SPlayFileDisk

//single click - set playback position
//double click - start playing from position
//ctrl drag - scroll
//ctrl+shift drag - zoom

//TODO time markers in seconds
//TODO nicer loading with progress indication
//TODO better way to mix down 1 ch for display and not only use the first channel as now
//TODO increase cursor updaterate with predictive animation
//TODO improve helpfile

SPlayFileDiskView {
	var <view;
	var <spf;
	var <duration= -1;
	var <currentFilePath;
	var volumeSpec;
	var filePopup, readButton,
	vZoomSlider, waveView, hZoomSlider,
	atkText, atkNumber, relText, relNumber, rateText, rateNumber, loopButton,
	volSlider, playButton, busText, busNumber;

	*new {|spf, folder= "", controls= true|
		^super.new.initSPlayFileDiskView(spf, folder, controls);
	}

	initSPlayFileDiskView {|argSpf, folder, controls|
		var selectedCursorPosition, startPlaying;
		var cursorUpdater;
		var keyDownAction= {|view, char, mod, uni, keycode, key|
			if(char==Char.space, {
				playButton.valueAction= 1-playButton.value;
			});
		};
		var soundfiles= [];
		folder= folder.standardizePath;
		if(PathName(folder).isFolder, {
			soundfiles= SoundFile.collect(folder+/+"*");
		});

		spf= argSpf??{SPlayFileDiskStereo()};
		spf.server.ifNotRunning({"%: boot server first".format(this.class.name).warn});

		view= VLayout(
			HLayout(
				[filePopup= PopUpMenu().items_(
					["_"]++soundfiles.collect{|x| x.path.basename}
				), \stretch: 1],

				readButton= Button().states_([
					["read"]
				]).canFocus_(false)
			),

			VLayout(
				HLayout(
					vZoomSlider= RangeSlider().orientation_(\vertical).canFocus_(false),

					waveView= SoundFileView().setData([0])
					.timeCursorOn_(true).timeCursorColor_(Color.white)
					.gridOn_(false)//.gridColor_(Color.grey(0, 0.1))
					.rmsColor_(Color.grey(0, 0.5)).waveColors_(Color.grey(0.5)!8)
					.background_(Color.clear)
					.setSelectionColor(0, Color.clear)
				),

				hZoomSlider= RangeSlider().orientation_(\horizontal).canFocus_(false)
			),

			HLayout(
				atkText= StaticText().string_("atk:"),
				atkNumber= NumberBox().clipLo_(0).fixedWidth_(55),

				relText= StaticText().string_("rel:"),
				relNumber= NumberBox().clipLo_(0).fixedWidth_(55),

				rateText= StaticText().string_("rate:"),
				rateNumber= NumberBox().clipLo_(0).fixedWidth_(55),

				[View(), stretch: 1],

				loopButton= Button().states_([
					[" loop"], ["√loop"]
				]).canFocus_(false)
			),

			HLayout(
				[volSlider= Slider().orientation_(\horizontal).canFocus_(false), stretch: 1],

				playButton= Button().states_([
					["play"], ["play", Color.black, Color(0.5, 1, 0.5)]
				]),

				busText= StaticText().string_("bus:"),
				busNumber= NumberBox().decimals_(0).clipLo_(0).fixedWidth_(55)
			)
		);

		this.controls_(controls);

		filePopup.action= {|view|
			var val= view.value;
			view.items= view.items.put(0, "_");
			view.value= val;
			if(val>0, {
				this.read(soundfiles[val-1].path);
			});
		};

		readButton.action= {|view|
			Dialog.openPanel({|path|
				filePopup.items= filePopup.items.put(0, path.basename);
				filePopup.value= 0;
				this.read(path);
			});
		};

		vZoomSlider.action= {|view|
			waveView.yZoom= view.lo*9+1;
		};
		vZoomSlider.mouseDownAction= {|view, x, y, mod, num, cnt|
			var midPoint;
			if(cnt==2, {
				view.setSpanActive(0, 1);
			}, {
				midPoint= view.bounds.height*0.5;
				if(view.range>0, {
					if(y<midPoint, {
						view.setDeviation(y.linlin(0, midPoint, 0.5, 0), 0.5);
					}, {
						view.setDeviation(y.linlin(midPoint, view.bounds.height, 0, 0.5), 0.5);
					});
				});
			});
		};
		vZoomSlider.mouseMoveAction= vZoomSlider.mouseDownAction;

		waveView.mouseUpAction= {|view|
			selectedCursorPosition= view.timeCursorPosition;
		};
		waveView.mouseMoveAction= {|view, x, y, mod|
			if(mod.isCtrl, {
				hZoomSlider.lo= waveView.scrollPos;
				hZoomSlider.range= (waveView.xZoom/duration);
			});
		};
		waveView.mouseDownAction= {|view, x, y, mod, num, cnt|
			if(cnt==2 and:{playButton.value==0}, {
				playButton.valueAction= 1;
			});
		};

		hZoomSlider.action= {|view|
			waveView.zoomToFrac(view.range);
			waveView.scrollTo(view.lo);
		};
		hZoomSlider.mouseDownAction= {|view, x, y, mod, num, cnt|
			if(cnt==2, {
				view.setSpanActive(0, 1);
			});
		};

		atkNumber.action= {|view|
			spf.atk= view.value;
		};
		atkNumber.value= 0.01;

		relNumber.action= {|view|
			spf.rel= view.value;
		};
		relNumber.value= 0.05;

		rateNumber.action= {|view|
			spf.rate= view.value;
		};
		rateNumber.value= 1;

		loopButton.action= {|view|
			spf.loop= view.value;
		};

		volumeSpec= ControlSpec(-inf, 3, 'db', 0, 0, "dB");
		volSlider.action= {|view|
			spf.amp= volumeSpec.map(view.value).dbamp;
		};
		volSlider.value= volumeSpec.unmap(volumeSpec.default);

		playButton.action= {|view|
			if(currentFilePath.isNil, {
				view.value= 0;
			}, {
				if(view.value== 1, {
					startPlaying.value;
				}, {
					spf.stop;
				});
			});
		};

		spf.doneAction= {
			{
				playButton.value= 0;
				waveView.timeCursorPosition= 0;
			}.defer;
		};

		startPlaying= {
			spf.play(
				currentFilePath,
				selectedCursorPosition?waveView.timeCursorPosition,
				busNumber.value,
				volumeSpec.map(volSlider.value).dbamp
			);
		};

		busNumber.action= {|view|
			spf.out= view.value.asInteger;
		};

		waveView.keyDownAction= keyDownAction;
		atkNumber.keyDownAction= keyDownAction;
		relNumber.keyDownAction= keyDownAction;
		rateNumber.keyDownAction= keyDownAction;
		busNumber.keyDownAction= keyDownAction;

		cursorUpdater= Routine({
			var lastFrame= 0;
			inf.do{
				if(spf.frame!=lastFrame, {
					lastFrame= spf.frame;
					waveView.timeCursorPosition= spf.frame;
				});
				0.01.wait;
			};
		}).play(AppClock);

		waveView.onClose= {
			spf.free;
			cursorUpdater.stop;
		};
	}

	controls_ {|show= true|
		[
			filePopup, readButton,
			vZoomSlider, hZoomSlider,
			atkText, atkNumber, relText, relNumber, rateText, rateNumber, loopButton,
			volSlider, playButton, busText, busNumber
		].do{|v| v.visible= show};
	}

	read {|path|
		if(path.isNil, {
			readButton.doAction;
		}, {
			spf.stop;
			currentFilePath= path.standardizePath;
			SoundFile.use(currentFilePath, {|f|
				var buf= Buffer.readChannel(spf.server, f.path, channels:[0], action:{|b|
					b.loadToFloatArray(action:{|arr|
						{
							waveView.setData(arr, channels: 1, samplerate: f.sampleRate);
							buf.free;
						}.defer;
					});
					{hZoomSlider.setSpan(0, 1)}.defer;
					duration= f.duration;
				});
			});
		});
	}

	yZoom_ {|amount= 1|
		vZoomSlider.setSpanActive(0.5-(amount*0.5), 0.5+(amount*0.5));
	}
	xZoom_ {|lo= 0, hi= 1|
		hZoomSlider.setSpanActive(lo, hi);
	}

	atk_ {|val= 0.01| atkNumber.valueAction= val}
	rel_ {|val= 0.05| relNumber.valueAction= val}
	rate_ {|val= 1| rateNumber.valueAction= val}
	loop_ {|val= 0| loopButton.valueAction= val}
	vol_ {|val= 0| volSlider.valueAction= volumeSpec.unmap(val)}  //dB

	play {playButton.valueAction= 1}
	stop {playButton.valueAction= 0}

	bus_ {|val= 0| busNumber.valueAction= val}

	rmsColor_ {|col| waveView.rmsColor= col}
	timeCursorColor_ {|col| waveView.timeCursorColor= col}
	waveColor_ {|col| waveView.waveColors= [col]}
	background_ {|col| waveView.background= col}

	makeWindow {|pos|
		pos= pos??{Point(100, 100)};
		^Window(this.class.name, Rect(pos.x, pos.y, 800, 400)).front.view.layout_(
			view
		)
	}
}
