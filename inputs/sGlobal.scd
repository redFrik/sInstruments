(
//--settings
var winRect= Rect(Window.availableBounds.width-400, 0, 400, 200);  //x, y, w, h
var palette= SGUI.palette;
var fnt= Font.monospace(10);
var volumeSpec= ControlSpec(-inf, 10, 'db', 0.0, 0.0, "dB");
var snapshotKeys= #[  //more can be added
	[$A, $S, $D, $F, $G, $H, $J, $K],
	[$Z, $X, $C, $V, $B, $N, $M, $,]
];
var bankKeys= #[  //more can be added
	$1, $2, $3, $4, $5, $6, $7, $8, $9
];

//--functions and objects
var sendOsc;

//--gui
var volumeSlider, volumeNumber;
var bankButtons= List.new;
var snapButtons= List.new;
var snapshots;
var record;
var infoTextString;
var win= Window("sGlobal", winRect);
win.layout= VLayout(
	HLayout(
		StaticText().string_("Volume:"),
		volumeSlider= Slider().orientation_(\horizontal),
		volumeNumber= NumberBox().maxWidth_(75),
		StaticText().string_("dB")
	),
	HLayout(
		StaticText().string_("Snapshots:"),//SGUI.shrink(StaticText().string_("Snapshots")),
		VLayout(
			HLayout(
				*bankKeys.collect{|key, i|
					var str= "Bank%".format(i+1);
					bankButtons.add(
						Button().states_([
							[str, palette.buttonText, palette.button],
							[str, palette.buttonText, palette.highlight]
						]).fixedWidth_(str.bounds(SGUI.font).width+5)
					).last;
				}
			),
			VLayout(
				*snapshotKeys.collect{|row, i|
					HLayout(
						*snapButtons.add(
							row.collect{|key| Button().states_([
								[key, palette.buttonText, palette.button],
								[key, palette.highlight, palette.button],
								[key, palette.buttonText, palette.highlight]
							]).fixedWidth_(25)}
						).last
					)
				}
			)
		),
	),
	HLayout(
		StaticText().string_("Record:"),
		(record= SGUIrecord(s, SInstruments.recordingsDir, "sGlobal_")).view
	),
	infoTextString= StaticText().fixedHeight_(" ".bounds(fnt).height*6)
	.align_(\topLeft).background_(Color.grey(0.9, 0.5))
);
if(SGUI.currentTheme!=\dark, {
	win.view.children.select{|v| v.isKindOf(Slider)}.do{|v|
		v.background= Color.grey(0.7725, 0.5);
	};
});
SGUI.report(win);
SGUI.adapt(win);
win.onClose= {
	NetAddr.localAddr.sendMsg(\closed, \sGlobal);
};
win.front;
infoTextString.font= fnt;

sendOsc= {|arr|
	var str= "";
	arr.do{|a|
		SInputs.destinations[a[0]].sendMsg(a[1], *a[2..]);
		str= str++a;
	};
	infoTextString.string= str.replace("[ ", "[").replace(" ]", "] ").replace(", ", " ");
};

volumeSlider.action= {|view|
	s.volume.volume= volumeSpec.map(view.value);
	volumeNumber.value= volumeSpec.map(view.value);
};
volumeSlider.value= volumeSpec.unmap(0);
volumeNumber.action= {|view|
	view.value= volumeSpec.constrain(view.value);
	s.volume.volume= view.value;
	volumeSlider.value= volumeSpec.unmap(view.value);
};
volumeNumber.value= 0;
s.volume.setVolumeRange(-inf, volumeSpec.maxval);

//--button functions
snapButtons.do{|row, i|
	row.do{|but, j|
		but.action= {|view|
			if(view.value==1, {
				sendOsc.value([
					[\sCluster, \snapshots, snapshotKeys[i][j].asString, 0],
					[\sDrone, \snapshots, snapshotKeys[i][j].asString, 0],
					[\sGliss, \snapshots, snapshotKeys[i][j].asString, 0],
					[\sStream, \snapshots, snapshotKeys[i][j].asString, 0],
				]);
				{view.value= 0}.defer(0.15);
			});
		};
	};
};
bankButtons.do{|but, i|
	but.action= {|view|
		if(view.value==1, {
			sendOsc.value([
				[\sCluster, \snapshots, bankKeys[i].asString],
				[\sDrone, \snapshots, bankKeys[i].asString],
				[\sGliss, \snapshots, bankKeys[i].asString],
				[\sStream, \snapshots, bankKeys[i].asString],
			]);
			{view.value= 0}.defer(0.15);
		});
	};
};
)
