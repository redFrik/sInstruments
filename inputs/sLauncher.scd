(
//--settings
var size= 700;

//--images
var images= [
	\sCluster -> Image(SInstruments.rootDir+/+"images/sCluster-screenshot.png"),
	\sDrone -> Image(SInstruments.rootDir+/+"images/sDrone-screenshot.png"),
	\sFormant -> Image(SInstruments.rootDir+/+"images/sFormant-screenshot.png"),
	\sGliss -> Image(SInstruments.rootDir+/+"images/sGliss-screenshot.png"),
	\sStream -> Image(SInstruments.rootDir+/+"images/sStream-screenshot.png"),
];

//--gui
var win= Window("sLauncher", Rect.aboutPoint(Window.availableBounds.center, size/2, size/2));
win.userCanClose= false;
win.layout= VLayout(
	StaticText().string_("Click to launch instrument..."),
	GridLayout.rows(
		*images.collect{|x|
			UserView().drawFunc_{|usr| Pen.stringAtPoint(x.key.asString.drop(1), 50@50, Font(SGUI.font.name, 64))}
			.setBackgroundImage(x.value, 10).mouseUpAction_{SInstruments.toFront(x.key.asString)}
		}.clump(2)
	)
);
win.front;
win.onClose= {
	images.do{|x| x.value.free};
};
SGUI.adapt(win);
)
