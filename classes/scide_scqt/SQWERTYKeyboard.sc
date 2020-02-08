//f.olofsson 2019

//requires python script HIDtoOSC.py

SQWERTYKeyboard {
	var destinations;
	var rows;
	var infoTextString;

	*new {|name= "sQWERTYKeyboard", position, keys, mods|
		^super.new.initSQWERTYKeyboard(name, position ?? {Point(16, 60)}, keys, mods);
	}
	initSQWERTYKeyboard {|name, position, keys, mods|

		//--settings
		var prefName= "%.json".format(name);
		var winRect= Rect(position.x, position.y, 420, 200);  //x, y, w, h
		var palette= SGUI.palette;
		var fntMono= Font.monospace(10);

		//--functions and objects
		var prefDict, tmp;

		//--gui
		var codeTextString;
		var destinationsButton;
		var pwin, win= Window(name, winRect);
		rows= List.new;  //one dictionary per keyboard row
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
			NetAddr.localAddr.sendMsg(\closed, name.asSymbol);
		};
		win.front;
		infoTextString.font= fntMono;

		destinationsButton.action= {
			var palette= SGUI.palette;
			var buttons= List.new;
			var cancelButton, storeButton;
			var pname= name++"destinations";
			pwin= Window.allWindows.detect{|x| x.name==pname};
			if(pwin.isNil, {
				pwin= Window(pname, Rect.aboutPoint(position+#[400, 200], 100, 150));
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
						file.write("'%': '%'".format(name, destinations).postln);
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
			tmp= prefDict[name];
			if(tmp.notNil, {
				tmp= tmp.drop(2).drop(-2).split(Char.comma);
				tmp= tmp.collect{|str| str.stripWhiteSpace.asSymbol};
				destinations= destinations.collect{|dSym|
					if(tmp.includes(dSym), {dSym}, {nil});
				};
			});
		});

		this.lookupButton(' ').fixedWidth_(160);
		this.lookupButton(\Del).fixedWidth_(40);
		this.lookupButton(\Tab).fixedWidth_(40);
		this.lookupButton(\Cap).fixedWidth_(40);
		this.lookupButton(\Ret).fixedWidth_(40);
		this.lookupButton(\shiL).fixedWidth_(40);
		this.lookupButton(\shiR).fixedWidth_(40);
		this.lookupButton(\ctrl).fixedWidth_(40);
		this.lookupButton(\altL).fixedWidth_(40);
		this.lookupButton(\altR).fixedWidth_(40);
		this.lookupButton(\cmdL).fixedWidth_(40);
		this.lookupButton(\cmdR).fixedWidth_(40);

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
		}, \hid, recvPort:SInputs.destinations[name.asSymbol].port);
		"%: listening for \hid on port %".format(name, SInputs.destinations[name.asSymbol].port).postln;
	}
	lookupButton {|sym|
		var i= 0;
		var button;
		while({i<rows.size}, {
			button= rows[i][sym];
			if(button.notNil, {
				i= inf;
			}, {
				i= i+1;
			});
		});
		^button;
	}
	sendOsc {|arr|
		var str= "";
		arr.do{|a|  //[destination, key, value]
			if(destinations.includes(a[0]), {
				SInputs.destinations[a[0]].sendMsg(*a[1..]);
				str= str++a;
			});
		};
		infoTextString.string= str.replace("[ ", "[").replace(" ]", "] ").replace(", ", " ");
	}
}
