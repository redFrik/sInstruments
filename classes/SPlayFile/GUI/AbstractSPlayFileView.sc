//f.olofsson 2020

//related SPlayFileView, SPlayFileDiskView, AbstractSPlayFile

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
	var fileName, popup, readFolderButton, readFileButton, lastFolderPath, lastFilePath,
	vZoomSlider, waveView, hZoomSlider,
	atkText, atkNumber, relText, relNumber, rateText, rateNumber, loopButton,
	volSlider, playButton, busText, busNumber;

	*new {|parent, bounds, spf, folder= "", controls= true|
		^super.new.initAbstractSPlayFileView(parent, bounds, spf, folder, controls).init(spf);
	}
	initAbstractSPlayFileView {|parent, bounds, argSpf, folder, controls|
		var keyDownAction;

		//--gui

		view= View(parent, bounds).layout_(VLayout(
			HLayout(
				[popup= PopUpMenu().items_(
					["_"]++soundfiles.collect{|x| x.path.basename}
				).canFocus_(false), \stretch: 1],

				readFolderButton= Button().states_([
					["folder"]
				]).canFocus_(false),

				readFileButton= Button().states_([
					["file"]
				]).canFocus_(false)
			),

			VLayout(
				HLayout(
					vZoomSlider= RangeSlider().orientation_(\vertical).canFocus_(false)
					.background_(Color.grey(0.5)).maxWidth_(20),

					StackLayout(
						waveView= SoundFileView().setData([0])
						.timeCursorOn_(true).timeCursorColor_(Color.blue)
						.gridOn_(false)//.gridColor_(Color.grey(0, 0.1))
						.rmsColor_(Color.grey(0, 0.5)).waveColors_(Color.grey(0.5)!8)
						.background_(Color.clear).minHeight_(50),
						fileName= StaticText().align_(\bottom),
					).mode_(\stackAll)
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

		//--drag&drop

		waveView.canReceiveDragHandler= {
			View.currentDrag.isString and:{
				SoundFile(View.currentDrag).info.notNil or:{
					PathName(View.currentDrag).isFolder
				}
			} or:{
				View.currentDrag.isArray and:{
					View.currentDrag.any{|path| SoundFile(path).info.notNil}
				}
			}
		};
		waveView.receiveDragHandler= {
			if(View.currentDrag.isString, {
				if(PathName(View.currentDrag).isFolder, {
					this.prReadFolder(View.currentDrag);
				}, {
					this.prReadFile([View.currentDrag]);
				});
			}, {
				this.prReadFile(View.currentDrag.select{|path| SoundFile(path).info.notNil});
			});
		};
		readFileButton.canReceiveDragHandler= waveView.canReceiveDragHandler;
		readFileButton.receiveDragHandler= waveView.receiveDragHandler;
		readFolderButton.canReceiveDragHandler= waveView.canReceiveDragHandler;
		readFolderButton.receiveDragHandler= waveView.receiveDragHandler;


		//--action functions

		popup.action= {|view|
			var val= view.value;
			if(view.items[0]=="_", {val= val-1});
			if(val>=0, {
				this.read(soundfiles[val].path);
			});
		};

		readFolderButton.action= {|view|
			FileDialog({|paths|
				this.prReadFolder(paths[0]);
			}, fileMode: 2, path: lastFolderPath);
		};

		readFileButton.action= {|view|
			FileDialog({|paths|
				this.prReadFile(paths);
			}, fileMode: 3, path: lastFilePath);
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

		this.prReadFolder(folder.standardizePath);
	}

	startPlaying {
		^this.subclassResponsibility(thisMethod);
	}

	read {|path|
		if(path.isNil, {
			readFileButton.doAction;
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
					{
						hZoomSlider.setSpan(0, 1);
						fileName.string_(currentFilePath.basename);
					}.defer;
					duration= f.duration;
				});
			});
			lastFolderPath= currentFilePath.dirname;
			lastFilePath= currentFilePath;
		});
	}

	controls_ {|show= true|
		[
			popup, readFolderButton, readFileButton,
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

	//--private

	prReadFile {|paths|
		var files= List.new;
		paths.do{|path|
			if(SoundFile(path).info.notNil, {
				files.add(path);
			});
		};
		if(files.size>0, {
			soundfiles= files.array.collect{|p| SoundFile(p)};
			popup.items= soundfiles.collect{|x| x.path.basename};
			this.read(soundfiles[0].path);
		});
	}

	prReadFolder {|path|
		soundfiles= SoundFile.collect(path+/+"*");
		if(soundfiles.size>0, {
			popup.items= ["_"]++soundfiles.collect{|x| x.path.basename};
		});
		lastFolderPath= path;
		lastFilePath= path;
	}
}
