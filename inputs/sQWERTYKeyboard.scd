//f.olofsson 2019

//assumes Swedish keyboard - adapt for other keyboards in keys Array below
//requires python script HIDtoOSC.py and an external usb keyboard http://fredrikolofsson.com/f0blog/?q=node/669
//start the script with sudo python HIDtoOSC.py --vid 6700 --pid 2 --port 12002

(
//--settings
var prefName= "qwertyKeyboardPref.json";
var winRect= Rect(16, 60, 420, 200);  //x, y, w, h
var palette= SGUI.palette;
var fntMono= Font.monospace(10);
var keys= [  //EDIT character and keycode mappings. more can be added
	[\Esc->41, \F1->58, \F2->59, \F3->60, \F4->61, \F5->62, \F6->63, \F7->64, \F8->65, \F9->66, \F10->67, \F11->68, \F12->69],
	['§'->53, '1'->30, '2'->31, '3'->32, '4'->33, '5'->34, '6'->35, '7'->36, '8'->37, '9'->38, '0'->39, '+'->45, '´'->46, \Del->42],
	[\Tab->43, 'Q'->20, 'W'->26, 'E'-> 8, 'R'->21, 'T'->23, 'Y'->28, 'U'->24, 'I'->12, 'O'->18, 'P'->19, 'Å'->47, '¨'->48],
	[\Cap->57, 'A'-> 4, 'S'->22, 'D'-> 7, 'F'-> 9, 'G'->10, 'H'->11, 'J'->13, 'K'->14, 'L'->15, 'Ö'->51, 'Ä'->52, '\''->50, \Ret->40],
	[\shiL->2, '<'->100, 'Z'->29, 'X'->27, 'C'->6, 'V'->25, 'B'-> 5, 'N'->17, 'M'->16, ','->54, '.'->55, '-'->56, \shiR->32],
	[\ctrl->1, \altL->4, \cmdL->8, ' '->44, \cmdR->128, \altR->64]
];
var mods= #[\shiL, \shiR, \ctrl, \altL, \altR, \cmdL, \cmdR];  //EDIT list keys that are modifiers here

//--functions and objects
var prefDict, tmp;
var destinations;
var rows= List.new;  //one dictionary per keyboard row
var sendOsc;
var lookupButton;

//--gui
var codeTextString;
var infoTextString;
var destinationsButton;
var pwin, win= Window("sQWERTYKeyboard", winRect);
win.layout= VLayout(
	HLayout(
		SGUI.shrink(StaticText().string_("Incomming keycodes from HIDtoOSC:")),
		codeTextString= StaticText().fixedSize_(Size(140, " ".bounds(fntMono).height))
		.background_(Color.grey(0.9, 0.5)),
		SGUI.shrink(StaticText().string_("destinations:")),
		(destinationsButton= SGUIsettings()).view
	),
	VLayout(
		*keys.collect{|row|
			var dictRow= ();
			var butRow= HLayout(
				*row.collect{|assoc|
					var sym= assoc.key;
					var but= Button().states_([
						[sym, palette.buttonText, palette.button],
						[sym, palette.buttonText, palette.highlight]
					]).fixedWidth_(25);
					dictRow.add(sym -> but);
					but;
				};
			);
			rows.add(dictRow);
			butRow;
	}),
	infoTextString= StaticText().fixedHeight_(" ".bounds(fntMono).height*2)
	.align_(\topLeft).background_(Color.grey(0.9, 0.5))
);
SGUI.report(win);
SGUI.adapt(win);
win.onClose= {
	NetAddr.localAddr.sendMsg(\closed, \sQWERTYKeyboard);
};
win.front;
infoTextString.font= fntMono;

destinationsButton.action= {
	var palette= SGUI.palette;
	var buttons= List.new;
	var cancelButton, storeButton;
	var pos, name= "destinations";
	pwin= Window.allWindows.detect{|x| x.name==name};
	if(pwin.isNil, {
		pos= Window.screenBounds.extent*#[0.5, 0.5];
		pwin= Window(name, Rect.aboutPoint(pos, 100, 150));
		pwin.view.layout_(
			VLayout(*[
				SInputs.destinations.keys.asArray.sort.collect{|x|
					buttons.add(Button().states_([
						["  "++x, palette.buttonText, palette.button],
						["•"++x, palette.buttonText, palette.highlight]
					])).last;
				},
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
			].flat)
		);
		SGUI.adapt(pwin);
		pwin.view.keyDownAction= {|view, chr, mod, unicode, keycode, key|
			if(unicode==27, {pwin.close});  //esc
		};

		buttons.do{|but, i|
			but.action= {|view|
				if(view.value==1, {
					destinations[i]= SInputs.destinations.keys.asArray.sort[i];
				}, {
					destinations[i]= nil;
				});
			};
			but.value= destinations[i].notNil.binaryValue;
		};
		cancelButton.action= {
			pwin.close;
		};
		storeButton.action= {
			if(File.exists(SInstruments.preferencesDir).not, {SInstruments.preferencesDir.mkdir});
			File.use(SInstruments.preferencesDir+/+prefName, "w", {|file|
				file.write("{\n");
				file.write("'0': '%'".format(destinations));
				file.write("\n}");
			});
			pwin.close;
		};
	});
	pwin.front;
};

destinations= SInputs.destinations.keys.asArray.sort;
if(File.exists(SInstruments.preferencesDir+/+prefName), {
	prefDict= (SInstruments.preferencesDir+/+prefName).parseYAMLFile;
	tmp= prefDict["0"];
	if(tmp.notNil, {
		tmp= tmp.drop(2).drop(-2).split(Char.comma);
		tmp= tmp.collect{|str| str.stripWhiteSpace.asSymbol};
		destinations= destinations.collect{|dSym|
			if(tmp.includes(dSym), {dSym}, {nil});
		};
	});
});

lookupButton= {|sym|
	var button;
	rows.do{|row|
		var but= row[sym];
		if(but.notNil, {
			button= but;
		});
	};
	button;
};

lookupButton.value(' ').fixedWidth_(160);
lookupButton.value(\Del).fixedWidth_(40);
lookupButton.value(\Tab).fixedWidth_(40);
lookupButton.value(\Cap).fixedWidth_(40);
lookupButton.value(\Ret).fixedWidth_(40);
lookupButton.value(\shiL).fixedWidth_(40);
lookupButton.value(\shiR).fixedWidth_(40);
lookupButton.value(\ctrl).fixedWidth_(40);
lookupButton.value(\altL).fixedWidth_(40);
lookupButton.value(\altR).fixedWidth_(40);
lookupButton.value(\cmdL).fixedWidth_(40);
lookupButton.value(\cmdR).fixedWidth_(40);

//--network
sendOsc= {|arr|
	var str= "";
	arr.do{|a|  //[destination, key, value]
		if(destinations.includes(a[0]), {
			SInputs.destinations[a[0]].sendMsg(*a[1..]);
			str= str++a;
		});
	};
	infoTextString.string= str.replace("[ ", "[").replace(" ]", "] ").replace(", ", " ");
};

OSCFunc({|msg|
	var keycodes= msg[3][2..].select{|x| x>0};
	var modifiers= msg[3][0];  //detect modifiers like shift etc
	{
		codeTextString.string= modifiers.asString+keycodes;
		infoTextString.string= "";
		rows.do{|dict, i|
			var matchingKeys;
			var matchingMods;
			matchingKeys= keys[i].select{|assoc| keycodes.includes(assoc.value) and:{mods.includes(assoc.key).not}};
			if(modifiers>0, {
				matchingMods= keys[i].select{|assoc| mods.includes(assoc.key) and:{assoc.value&modifiers!=0}};
			});
			dict.keysValuesDo{|key, but|
				var foundInKeys= matchingKeys.size>0 and:{matchingKeys.any{|assoc| assoc.key==key}};
				var foundInMods= matchingMods.notNil and:{matchingMods.any{|assoc| assoc.key==key}};
				if(foundInKeys.not&&foundInMods.not and:{but.value==1}, {
					but.valueAction= 0;
				}, {
					if(foundInKeys||foundInMods and:{but.value==0}, {
						but.valueAction= 1;
					});
				});
			};
		};
	}.defer;
}, \hid, recvPort:SInputs.destinations.sQWERTYKeyboard.port);

//--
//mappings:

#[$1, $2, $3, $4, $5, $6, $7, $8, $9].do{|chr|
	lookupButton.value(chr.toUpper.asSymbol).action= {|view|
		if(view.value==1, {
			sendOsc.value([
				[\sCluster, \keyboard, chr.ascii],
				[\sDrone, \keyboard, chr.ascii],
				[\sFormant, \keyboard, chr.ascii],
				[\sGliss, \keyboard, chr.ascii],
				[\sStream, \keyboard, chr.ascii]
			]);
		});
	};
};

#[$q, $w, $e, $r, $t, $y, $u, $i, $o, $p].do{|chr|
	lookupButton.value(chr.toUpper.asSymbol).action= {|view|
		if(view.value==1, {
			sendOsc.value([
				[\sCluster, \keyboard, chr.ascii],
				[\sDrone, \keyboard, chr.ascii],
				[\sFormant, \keyboard, chr.ascii],
				[\sGliss, \keyboard, chr.ascii],
				[\sStream, \keyboard, chr.ascii]
			]);
		});
	};
};

#[$a, $s, $d, $f, $g, $h, $j, $k].do{|chr|
	lookupButton.value(chr.toUpper.asSymbol).action= {|view|
		if(view.value==1, {
			sendOsc.value([
				[\sCluster, \keyboard, chr.ascii],
				[\sDrone, \keyboard, chr.ascii],
				[\sFormant, \keyboard, chr.ascii],
				[\sGliss, \keyboard, chr.ascii],
				[\sStream, \keyboard, chr.ascii]
			]);
		});
	};
};

#[$z, $x, $c, $v, $b, $n, $m, $,].do{|chr|
	lookupButton.value(chr.toUpper.asSymbol).action= {|view|
		if(view.value==1, {
			sendOsc.value([
				[\sCluster, \keyboard, chr.ascii],
				[\sDrone, \keyboard, chr.ascii],
				[\sFormant, \keyboard, chr.ascii],
				[\sGliss, \keyboard, chr.ascii],
				[\sStream, \keyboard, chr.ascii]
			]);
		});
	};
};
)
