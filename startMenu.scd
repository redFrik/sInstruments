(
//--settings
var prefName= "startMenuPref.json";
var winRect= Rect(1, 550, 240, 320);  //x, y, w, h

//--functions and objects
var keyFunc;
var keyLookup= ();
var prefDict;
var themes= SGUI.themes.keys.asArray.sort;

//--gui
var preferencesButton;
var buttons= List.new;
var pwin, win= Window("sInstruments menu", winRect);
win.userCanClose= false;
win.layout= VLayout(
	HLayout(
		StaticText().string_("sInstruments: "++SInstruments.version),
		nil,
		(preferencesButton= SGUIsettings()).view
	)
);

win.layout.add(StaticText().string_("Click to launch instruments..."));
SInstruments.instruments.do{|name|
	var button= Button().states_([
		[" "++name, SGUI.palette.buttonText, SGUI.palette.button],
		["•"++name, SGUI.palette.highlight, SGUI.palette.button],
		["•"++name, SGUI.palette.buttonText, SGUI.palette.highlight]
	]).action_{SInstruments.toFront(name)};
	buttons.add(button);
	win.layout.add(button);
};

win.layout.add(StaticText().string_("Click to launch inputs..."));
SInstruments.inputs.do{|name|
	var button= Button().states_([
		[" "++name, SGUI.palette.buttonText, SGUI.palette.button],
		["•"++name, SGUI.palette.highlight, SGUI.palette.button],
		["•"++name, SGUI.palette.buttonText, SGUI.palette.highlight]
	]).action_{SInstruments.toFront(name)};
	buttons.add(button);
	win.layout.add(button);
};

preferencesButton.action= {
	var palette= SGUI.palette;
	var themePopup;
	var ctrlPopup, altPopup, cmdPopup, lessPopup;
	var cancelButton, storeButton;
	var pos, name= "preferences";
	var items= ['_']++SInstruments.instruments++\sLauncher;
	pwin= Window.allWindows.detect{|x| x.name==name};
	if(pwin.isNil, {
		pos= Window.screenBounds.extent*0.6;
		pwin= Window(name, Rect.aboutPoint(pos, 250, 100));
		pwin.view.layout_(VLayout(
			HLayout(
				StaticText().string_("Theme").maxWidth_(50),
				themePopup= PopUpMenu().items_(themes)
			),
			nil,
			StaticText().string_("Shortcuts for launching instruments and/or bring to front"),
			HLayout(
				StaticText().string_("key 'ctrl'").maxWidth_(65),
				StaticText().string_("=").maxWidth_(25),
				ctrlPopup= PopUpMenu().items_(items)
			),
			HLayout(
				StaticText().string_("key 'alt'").maxWidth_(65),
				StaticText().string_("=").maxWidth_(25),
				altPopup= PopUpMenu().items_(items)
			),
			HLayout(
				StaticText().string_("key 'cmd'").maxWidth_(65),
				StaticText().string_("=").maxWidth_(25),
				cmdPopup= PopUpMenu().items_(items)
			),
			HLayout(
				StaticText().string_("key '<'").maxWidth_(65),
				StaticText().string_("=").maxWidth_(25),
				lessPopup= PopUpMenu().items_(items)
			),
			nil,
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
	case
	{mod.isCtrl} {SInstruments.toFront(keyLookup[\keyCtrl])}
	{mod.isAlt} {SInstruments.toFront(keyLookup[\keyAlt])}
	{mod.isCmd} {SInstruments.toFront(keyLookup[\keyCmd])}
	{chr==$<} {SInstruments.toFront(keyLookup[\keyLess])};
};
View.globalKeyDownAction= View.globalKeyDownAction.addFunc(keyFunc);

OSCFunc({|msg|  //from SGUI report
	{
		buttons.detect{|b|
			b.states[0][0].replace(" ", "").contains(msg[1].asString);
		}.value= 2;
	}.defer;
}, \toFront);
OSCFunc({|msg|  //from SGUI report
	{
		var but= buttons.detect{|b|
			b.states[0][0].replace(" ", "").contains(msg[1].asString);
		};
		if(but.notNil, {but.value= 1});
	}.defer;
}, \endFront);
OSCFunc({|msg|  //from instruments
	{
		buttons.detect{|b|
			b.states[0][0].replace(" ", "").contains(msg[1].asString);
		}.value= 0;
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
