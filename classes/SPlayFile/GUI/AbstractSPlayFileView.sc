//f.olofsson 2020

//single click - set playback position
//double click - start playing from position
//ctrl drag left-right - scroll left-right
//ctrl+shift drag up-down - zoom in-out
//shift drag - (extend selection)
//shift double click - (select all)

//TODO cursors should survive cmdperiod
//TODO time markers in seconds
//TODO nicer loading with progress indication
//TODO better way to mix down 1 ch for display and not only use the first channel as now
//TODO improve helpfile

AbstractSPlayFileView : SCViewHolder {

	var <spf;
	var <duration= -1;
	var <currentFilePath;
	var <>fps= 25;
	var soundfiles;
	var cursorUpdater;
	var volumeSpec;
	var filePopup, readButton,
	vZoomSlider, waveView, hZoomSlider,
	atkText, atkNumber, relText, relNumber, rateText, rateNumber, loopButton,
	volSlider, playButton, busText, busNumber;

	*new {|parent, bounds, spf, folder= "", controls= true|
		^super.new.initAbstractSPlayFileView(parent, bounds, spf, folder, controls).init(spf);
	}
	initAbstractSPlayFileView {|parent, bounds, argSpf, folder, controls|
		var keyDownAction;

		soundfiles= [];

		folder= folder.standardizePath;
		if(PathName(folder).isFolder, {
			soundfiles= SoundFile.collect(folder+/+"*");
		});

		view= View(parent, bounds).layout_(VLayout(
			HLayout(
				[filePopup= PopUpMenu().items_(
					["_"]++soundfiles.collect{|x| x.path.basename}
				).canFocus_(false), \stretch: 1],

				readButton= Button().states_([
					["read"]
				]).canFocus_(false)
			),

			VLayout(
				HLayout(
					vZoomSlider= RangeSlider().orientation_(\vertical).canFocus_(false)
					.background_(Color.grey(0.5)),

					waveView= SoundFileView().minSize_(Size(133, 100)).setData([0])
					.timeCursorOn_(true).timeCursorColor_(Color.white)
					.gridOn_(false)//.gridColor_(Color.grey(0, 0.1))
					.rmsColor_(Color.grey(0, 0.5)).waveColors_(Color.grey(0.5)!8)
					.background_(Color.clear)
				),

				hZoomSlider= RangeSlider().orientation_(\horizontal).canFocus_(false)
				.background_(Color.grey(0.5))
			),

			HLayout(
				atkText= StaticText().string_("atk:"),
				atkNumber= NumberBox().clipLo_(0).scroll_step_(0.05).fixedWidth_(55),

				relText= StaticText().string_("rel:"),
				relNumber= NumberBox().clipLo_(0).scroll_step_(0.05).fixedWidth_(55),

				rateText= StaticText().string_("rate:"),
				rateNumber= NumberBox().clipLo_(0).scroll_step_(0.05).fixedWidth_(55),

				[View(), stretch: 1],

				loopButton= Button().states_([
					[" loop"], ["√loop"]
				]).canFocus_(false)
			),

			HLayout(
				[
					volSlider= Slider().orientation_(\horizontal).canFocus_(false)
					.background_(Color.grey(0.5)),
					stretch: 1
				],

				playButton= Button().states_([
					["play"], ["play", Color.black, Color(0.5, 1, 0.5)]
				]),

				busText= StaticText().string_("bus:"),
				busNumber= NumberBox().decimals_(0).clipLo_(0).fixedWidth_(55)
			)
		));

		if(controls.not, {
			this.controls_(false);
		});

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

		waveView.mouseDownAction= {|view, x, y, mod, num, cnt|
			if(cnt==2 and:{playButton.value==0}, {
				waveView.setSelectionStart(0, view.timeCursorPosition);
				waveView.setSelectionSize(0, waveView.numFrames-view.timeCursorPosition);
				playButton.valueAction= 1;
				true;  //block propagation
			});
		};
		waveView.mouseMoveAction= {|view, x, y, mod|
			if(mod.isCtrl, {
				hZoomSlider.lo= waveView.scrollPos;
				hZoomSlider.range= (waveView.xZoom/duration);
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
					this.startPlaying;
				}, {
					spf.stop;
				});
			});
		};

		busNumber.action= {|view|
			spf.out= view.value.asInteger;
		};

		keyDownAction= {|view, char, mod, uni, keycode, key|
			if(char==Char.space, {
				playButton.valueAction= 1-playButton.value;
			});
		};
		waveView.keyDownAction= keyDownAction;
		atkNumber.keyDownAction= keyDownAction;
		relNumber.keyDownAction= keyDownAction;
		rateNumber.keyDownAction= keyDownAction;
		busNumber.keyDownAction= keyDownAction;

		waveView.onClose= {
			spf.free;
			cursorUpdater.stop;
		};
	}

	startPlaying {
		^this.subclassResponsibility(thisMethod);
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

	controls_ {|show= true|
		[
			filePopup, readButton,
			vZoomSlider, hZoomSlider,
			atkText, atkNumber, relText, relNumber, rateText, rateNumber, loopButton,
			volSlider, playButton, busText, busNumber
		].do{|v| v.visible= show};
	}

	yZoom_ {|amount= 1|
		amount= amount.clip(0, 1);
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
		view.front.bounds_(Rect(pos.x, pos.y, 800, 400)).name_(this.class.name)
	}
	focus {|flag= true|
		waveView.focus(flag);
	}
}
