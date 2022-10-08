(
//--settings
var size= 600;
var winRect= Rect(242, 255, size*1.25, size);  //x, y, w, h

//--images
var images= [
	\sCluster -> Image(SInstruments.rootDir+/+"images/sCluster-screenshot.png"),
	\sDrone -> Image(SInstruments.rootDir+/+"images/sDrone-screenshot.png"),
	\sFormant -> Image(SInstruments.rootDir+/+"images/sFormant-screenshot.png"),
	\sGliss -> Image(SInstruments.rootDir+/+"images/sGliss-screenshot.png"),
];

//--gui
var win= Window("sLauncher", winRect);
win.userCanClose= false;
win.layout= VLayout(
	StaticText().string_("Click to launch instrument..."),
	GridLayout.rows(
		*images.collect{|x|
			View().setBackgroundImage(x.value, 10).mouseUpAction_{SInstruments.toFront(x.key.asString)}
		}.clump(2)
	)
);
win.front;
win.onClose= {
	images.do{|x| x.value.free};
};
SGUI.adapt(win);
)
