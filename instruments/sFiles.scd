//TODO send iOnOff to sKeyDpad

(
//--settings
var oscPort= SInputs.destinations.sFiles.port;
var winRect= Rect(Window.availableBounds.width-400, Window.availableBounds.height, 400, 400);  //x, y, w, h
var palette= SGUI.palette((highlight: Color.grey(2/3, 0.5)));
var numPlayers= 8;

s.options.numWireBufs= s.options.numWireBufs.max(128);
s.options.memSize= s.options.memSize.max(2**16);
s.latency= 0.08;
s.waitForBoot{

	//--functions and objects
	var players;
	var paths= Array.newClear(numPlayers);
	var playFunc;
	var setupOscResponders, oscResponders;

	//--gui
	var backgroundImage;
	var folder, files;
	var win= Window("sFiles", winRect);
	win.layout= VLayout();
	win.layout.add(
		folder= DragSink().object_("drop folder or files here")
		.canReceiveDragHandler_{
			View.currentDrag.isString or:{View.currentDrag.isArray}
		}
		.receiveDragHandler_{
			var index= 0;
			var paths;
			if(View.currentDrag.isString, {
				if(PathName(View.currentDrag).isFolder, {
					paths= (View.currentDrag+/+"*").pathMatch;
				}, {
					paths= [View.currentDrag];
				});
			}, {
				paths= View.currentDrag;
			});
			paths.do{|path|
				if(index<files.size, {
					if(SoundFile(path).info.notNil, {
						files[index].read(path);
						index= index+1;
					});
				});
			}
		}
	);
	files= {|i|
		var sfv= SPlayFileView(folder: SInstruments.soundfilesDir, controls: false);
		var ctrlBut= Button().states_(#[["i"], ["i"]]);
		var playBut= Button().states_([[">"]]);
		var stopBut= Button().states_([["."]]);
		ctrlBut.action_{|v| sfv.controls= v.value.booleanValue};
		playBut.action_{|v| sfv.play};
		stopBut.action_{|v| sfv.stop};
		win.layout.add(
			HLayout(
				sfv.timeCursorColor_(Color.blue),
				VLayout(
					ctrlBut,
					playBut,
					stopBut,
				)
			)
		);
		sfv
	}.dup(numPlayers);
	backgroundImage= Image(500, 500).draw({|img|
		Pen.fillColor= Color.yellow(0.3, 0.15);
		100.do{|i|
			Pen.fillOval(Rect(400.linrand, 400.linrand, 50, 50));
		};
	});
	win.view.setBackgroundImage(backgroundImage, 10, 0.2);
	if(SGUI.currentTheme!=\dark, {
		win.view.children.select{|v| v.isKindOf(SoundFileView)}.do{|v|
			v.background= Color.grey(0.7725, 0.5);
		};
	});

	win.onClose= {
		NetAddr.localAddr.sendMsg(\closed, \sFiles);
		players.do{|x| x.stop(0.1)};
		oscResponders.do{|x| x.free};
	};


	//--network
	setupOscResponders= {
		oscResponders= [
			OSCFunc({|msg|
				msg.postln;
				if(msg[1]==0, {
					players.do{|x| x.stop(0.1)};
				});
			}, \onOff, recvPort:oscPort),
		]
	};

	//SInputs.destinations.sKeyDpad.sendMsg(\iOnOff, \sFiles, ...);  //TODO

	players= {SPlayFileStereo()}.dup(numPlayers);
	playFunc= {|i|
		var sf;
		if(paths[i].notNil, {
			sf= SoundFile.openRead(paths[i]);
			files[i].soundfile= sf;
			files[i].read;
			files[i].refresh;
			players[i].play(paths[i]);
		});
	};

	SGUI.report(win);
	SGUI.adapt(win);
	win.front;

	setupOscResponders.value;
	PathName(SInstruments.soundfilesDir).deepFiles.select{|p| SoundFile(p.fullPath).info.notNil}.do{|p, i|
		if(i<files.size, {
			files[i].read(p.fullPath);
		});
	};
};
)
