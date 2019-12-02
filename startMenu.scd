(
//--settings
var prefName= "startMenuPref.json";
var winRect= Rect(1, 550, 240, 320);  //x, y, w, h
var fnt= SGUI.font;

//--functions and objects
var keyFunc;
var keyLookup= ();
var prefDict;
var themes= SGUI.themes.keys.asArray.sort;

//--gui
var preferencesButton;
var buttons= List.new;
var pwin, win= Window("sInstruments menu", winRect);
win.layout= VLayout(
	HLayout(
		StaticText().string_("sInstruments: "++SInstruments.version),
		View(),
		(preferencesButton= SGUIsettings()).view
	),
	StaticText().string_("Click to launch instruments..."),
	buttons.add(Button().states_([
		[" sGliss", SGUI.palette.buttonText, SGUI.palette.button],
		["•sGliss", SGUI.palette.highlight, SGUI.palette.button],
		["•sGliss", SGUI.palette.buttonText, SGUI.palette.highlight]
	]).action_{SInstruments.toFront("sGliss")}).last,
	buttons.add(Button().states_([
		[" sDrone", SGUI.palette.buttonText, SGUI.palette.button],
		["•sDrone", SGUI.palette.highlight, SGUI.palette.button],
		["•sDrone", SGUI.palette.buttonText, SGUI.palette.highlight]
	]).action_{SInstruments.toFront("sDrone")}).last,
	buttons.add(Button().states_([
		[" sFormant", SGUI.palette.buttonText, SGUI.palette.button],
		["•sFormant", SGUI.palette.highlight, SGUI.palette.button],
		["•sFormant", SGUI.palette.buttonText, SGUI.palette.highlight]
	]).action_{SInstruments.toFront("sFormant")}).last,
	buttons.add(Button().states_([
		[" sCluster", SGUI.palette.buttonText, SGUI.palette.button],
		["•sCluster", SGUI.palette.highlight, SGUI.palette.button],
		["•sCluster", SGUI.palette.buttonText, SGUI.palette.highlight]
	]).action_{SInstruments.toFront("sCluster")}).last,
	buttons.add(Button().states_([
		[" sStream", SGUI.palette.buttonText, SGUI.palette.button],
		["•sStream", SGUI.palette.highlight, SGUI.palette.button],
		["•sStream", SGUI.palette.buttonText, SGUI.palette.highlight]
	]).action_{SInstruments.toFront("sStream")}).last,
	StaticText().string_("Click to launch inputs..."),
	buttons.add(Button().states_([
		[" sGreybox", SGUI.palette.buttonText, SGUI.palette.button],
		["•sGreybox", SGUI.palette.highlight, SGUI.palette.button],
		["•sGreybox", SGUI.palette.buttonText, SGUI.palette.highlight]
	]).action_{SInstruments.toFront("sGreybox")}).last,
	buttons.add(Button().states_([
		[" sGreybox2", SGUI.palette.buttonText, SGUI.palette.button],
		["•sGreybox2", SGUI.palette.highlight, SGUI.palette.button],
		["•sGreybox2", SGUI.palette.buttonText, SGUI.palette.highlight]
	]).action_{SInstruments.toFront("sGreybox2")}).last,
	buttons.add(Button().states_([
		[" sKeyboard", SGUI.palette.buttonText, SGUI.palette.button],
		["•sKeyboard", SGUI.palette.highlight, SGUI.palette.button],
		["•sKeyboard", SGUI.palette.buttonText, SGUI.palette.highlight]
	]).action_{SInstruments.toFront("sKeyboard")}).last,
	buttons.add(Button().states_([
		[" sKeyBpad", SGUI.palette.buttonText, SGUI.palette.button],
		["•sKeyBpad", SGUI.palette.highlight, SGUI.palette.button],
		["•sKeyBpad", SGUI.palette.buttonText, SGUI.palette.highlight]
	]).action_{SInstruments.toFront("sKeyBpad")}).last,
	buttons.add(Button().states_([
		[" sKeyCpad", SGUI.palette.buttonText, SGUI.palette.button],
		["•sKeyCpad", SGUI.palette.highlight, SGUI.palette.button],
		["•sKeyCpad", SGUI.palette.buttonText, SGUI.palette.highlight]
	]).action_{SInstruments.toFront("sKeyCpad")}).last,
	buttons.add(Button().states_([
		[" sNanoKontrol", SGUI.palette.buttonText, SGUI.palette.button],
		["•sNanoKontrol", SGUI.palette.highlight, SGUI.palette.button],
		["•sNanoKontrol", SGUI.palette.buttonText, SGUI.palette.highlight]
	]).action_{SInstruments.toFront("sNanoKontrol")}).last,
	buttons.add(Button().states_([
		[" sNanoKontrol2", SGUI.palette.buttonText, SGUI.palette.button],
		["•sNanoKontrol2", SGUI.palette.highlight, SGUI.palette.button],
		["•sNanoKontrol2", SGUI.palette.buttonText, SGUI.palette.highlight]
	]).action_{SInstruments.toFront("sNanoKontrol2")}).last,
	buttons.add(Button().states_([
		[" sQWERTYKeyboard", SGUI.palette.buttonText, SGUI.palette.button],
		["•sQWERTYKeyboard", SGUI.palette.highlight, SGUI.palette.button],
		["•sQWERTYKeyboard", SGUI.palette.buttonText, SGUI.palette.highlight]
	]).action_{SInstruments.toFront("sQWERTYKeyboard")}).last,
	buttons.add(Button().states_([
		[" sSentograph", SGUI.palette.buttonText, SGUI.palette.button],
		["•sSentograph", SGUI.palette.highlight, SGUI.palette.button],
		["•sSentograph", SGUI.palette.buttonText, SGUI.palette.highlight]
	]).action_{SInstruments.toFront("sSentograph")}).last,
	buttons.add(Button().states_([
		[" sText", SGUI.palette.buttonText, SGUI.palette.button],
		["•sText", SGUI.palette.highlight, SGUI.palette.button],
		["•sText", SGUI.palette.buttonText, SGUI.palette.highlight]
	]).action_{SInstruments.toFront("sText")}).last
);

preferencesButton.action= {
	var palette= SGUI.palette;
	var themePopup;
	var ctrlPopup, altPopup, cmdPopup, lessPopup;
	var cancelButton, storeButton;
	var pos, name= "preferences";
	pwin= Window.allWindows.detect{|x| x.name==name};
	if(pwin.isNil, {
		pos= Window.screenBounds.extent*0.6;
		pwin= Window(name, Rect.aboutPoint(pos, 250, 100));
		pwin.view.layout_(VLayout(
			HLayout(
				StaticText().string_("Theme").maxWidth_(50),
				themePopup= PopUpMenu().items_(themes)
			),
			View(),
			StaticText().string_("Shortcuts for launching instruments and/or bring to front"),
			HLayout(
				StaticText().string_("key 'ctrl'").maxWidth_(65),
				StaticText().string_("=").maxWidth_(25),
				ctrlPopup= PopUpMenu().items_(['_']++SInstruments.instruments)
			),
			HLayout(
				StaticText().string_("key 'alt'").maxWidth_(65),
				StaticText().string_("=").maxWidth_(25),
				altPopup= PopUpMenu().items_(['_']++SInstruments.instruments)
			),
			HLayout(
				StaticText().string_("key 'cmd'").maxWidth_(65),
				StaticText().string_("=").maxWidth_(25),
				cmdPopup= PopUpMenu().items_(['_']++SInstruments.instruments)
			),
			HLayout(
				StaticText().string_("key '<'").maxWidth_(65),
				StaticText().string_("=").maxWidth_(25),
				lessPopup= PopUpMenu().items_(['_']++SInstruments.instruments)
			),
			View(),
			HLayout(
				[View(), stretch:1],
				cancelButton= Button().states_([
					["Cancel", palette.buttonText, palette.button]
				]),
				storeButton= Button().states_([
					["Store", palette.buttonText, palette.button]
				])
			)
		));
		SGUI.adapt(pwin);
		pwin.view.keyDownAction= {|view, chr, mod, unicode, keycode, key|
			if(unicode==27, {pwin.close});  //esc
		};
		themePopup.action= {|view|
			var p= SGUI.selectTheme(themes[view.value]);
			Window.allWindows.do{|w| w.view.palette= p};
		};
		themePopup.value= themes.indexOf(SGUI.currentTheme);
		ctrlPopup.action= {|view|
			keyLookup[\keyCtrl]= view.items[view.value];
		};
		ctrlPopup.value= ctrlPopup.items.indexOf(keyLookup[\keyCtrl])?0;
		altPopup.action= {|view|
			keyLookup[\keyAlt]= view.items[view.value];
		};
		altPopup.value= altPopup.items.indexOf(keyLookup[\keyAlt])?0;
		cmdPopup.action= {|view|
			keyLookup[\keyCmd]= view.items[view.value];
		};
		cmdPopup.value= cmdPopup.items.indexOf(keyLookup[\keyCmd])?0;
		lessPopup.action= {|view|
			keyLookup[\keyLess]= view.items[view.value];
		};
		lessPopup.value= lessPopup.items.indexOf(keyLookup[\keyLess])?0;
		cancelButton.action= {
			pwin.close;
		};
		storeButton.action= {
			if(File.exists(SInstruments.preferencesDir).not, {SInstruments.preferencesDir.mkdir});
			File.use(SInstruments.preferencesDir+/+prefName, "w", {|file|
				file.write("{\n");
				file.write("'theme': '%'".format(themePopup.items[themePopup.value]));
				file.write(",\n");
				file.write("'keyCtrl': '%'".format(ctrlPopup.items[ctrlPopup.value]));
				file.write(",\n");
				file.write("'keyAlt': '%'".format(altPopup.items[altPopup.value]));
				file.write(",\n");
				file.write("'keyCmd': '%'".format(cmdPopup.items[cmdPopup.value]));
				file.write(",\n");
				file.write("'keyLess': '%'".format(lessPopup.items[lessPopup.value]));
				file.write("\n}");
			});
			pwin.close;
		};
	});
	pwin.front;
};

if(File.exists(SInstruments.preferencesDir+/+prefName), {
	prefDict= (SInstruments.preferencesDir+/+prefName).parseYAMLFile;
	SGUI.selectTheme(prefDict["theme"].asSymbol);
	keyLookup.put(\keyCtrl, prefDict["keyCtrl"].asSymbol);
	keyLookup.put(\keyAlt, prefDict["keyAlt"].asSymbol);
	keyLookup.put(\keyCmd, prefDict["keyCmd"].asSymbol);
	keyLookup.put(\keyLess, prefDict["keyLess"].asSymbol);
});

keyFunc= {|view, chr, mod, unicode, keycode, key|
	if(keycode==0 and:{chr.toLower!=$a}, {
		case
		{mod.isCtrl} {SInstruments.toFront(keyLookup[\keyCtrl])}
		{mod.isAlt} {SInstruments.toFront(keyLookup[\keyAlt])}
		{mod.isCmd} {SInstruments.toFront(keyLookup[\keyCmd])};
	}, {
		if(chr==$<, {SInstruments.toFront(keyLookup[\keyLess])});
	});
};
View.globalKeyDownAction= View.globalKeyDownAction.addFunc(keyFunc);

OSCFunc({|msg|  //from SGUI report
	{
		buttons.detect{|b| b.states[0][0].contains(msg[1].asString)}.value= 2;
	}.defer;
}, \toFront);
OSCFunc({|msg|  //from SGUI report
	{
		var but= buttons.detect{|b| b.states[0][0].contains(msg[1].asString)};
		if(but.notNil, {but.value= 1});
	}.defer;
}, \endFront);
OSCFunc({|msg|  //from instruments
	{
		buttons.detect{|b| b.states[0][0].contains(msg[1].asString)}.value= 0;
	}.defer;
}, \closed);

win.front;
win.onClose= {
	if(pwin.notNil, {pwin.close});
	View.globalKeyDownAction= View.globalKeyDownAction.removeFunc(keyFunc);
};
SGUI.adapt(win);
s.options.numWireBufs= s.options.numWireBufs.max(128);
s.options.memSize= s.options.memSize.max(2**16);
s.latency= 0.08;
s.boot;
)
