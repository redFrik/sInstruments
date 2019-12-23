//f.olofsson 2019

//either nanokontrol v1 or v2

SNanoKontrol {
	classvar count= 0;

	var destinations;
	var <nanoKnobElements;
	var <nanoSliderElements;
	var <nanoButtonSElements;
	var <nanoButtonMElements;
	var <nanoButtonRElements;
	var <nanoCtrlButtons;  //dict
	var infoTextElementString;

	*new {|name= "sNanoKontrol", position|
		^super.new.initSNanoKontrol(name, position ?? {Point(0, 70)});
	}
	initSNanoKontrol {|name, position|

		//--settings
		var prefName= "%.json".format(name);
		var winRect= Rect(position.x, position.y, 400, 200);  //x, y, w, h
		var palette= SGUI.palette;
		var fnt= SGUI.font;
		var fntMono= Font.monospace(10);
		var fps= 15;  //maximum gui updaterate - does not affect sensor input rate

		//--functions and objects
		var prefDict, tmp;
		var setupCCResponders, ccResponders;
		var routineGui;
		var devices= List.new;
		var version;  //nanokontrol v1 or v2
		var ccMappings= (
			v1: (  //nanokontrol v1  (9 sliders and 9 knobs)
				\sliders: #[2, 3, 4, 5, 6, 8, 9, 12, 13],
				\knobs: #[14, 15, 16, 17, 18, 19, 20, 21, 22],
				\buttonsS: #[23, 24, 25, 26, 27, 28, 29, 30, 31],
				\buttonsR: #[33, 34, 35, 36, 37, 38, 39, 40, 41],
				\rew: 47,
				\play: 45,
				\ff: 48,
				\cycle: 49,
				\stop: 46,
				\rec: 44
			),
			v2: (  //nanokontrol v2 (8 sliders and 8 knobs)
				\sliders: #[0, 1, 2, 3, 4, 5, 6, 7],
				\knobs: #[16, 17, 18, 19, 20, 21, 22, 23],
				\buttonsS: #[32, 33, 34, 35, 36, 37, 38, 39],
				\buttonsM: #[48, 49, 50, 51, 52, 53, 54, 55],
				\buttonsR: #[64, 65, 66, 67, 68, 69, 70, 71],
				\cycle: 46,
				\rew: 43,
				\ff: 44,
				\stop: 42,
				\play: 41,
				\rec: 45,
				\trkDec: 58,
				\trkInc: 59,
				\mrkSet: 60,
				\mrkDec: 61,
				\mrkInc: 62
			)
		);

		//--gui
		var devicePopup, destinationsButton;
		var nanoChannelText;
		var pwin, win;
		nanoSliderElements= {SGUIelement()}!9;
		nanoButtonSElements= {SGUIelement()}!9;
		nanoButtonMElements= {SGUIelement()}!9;
		nanoButtonRElements= {SGUIelement()}!9;
		nanoKnobElements= {SGUIelement()}!9;
		nanoCtrlButtons= (v1: (), v2: ());
		infoTextElementString= SGUIelementString();
		win= Window(name, winRect);
		win.layout= VLayout(
			HLayout(
				SGUI.shrink(StaticText().string_("device:")),
				devicePopup= PopUpMenu().items_([]),
				SGUI.shrink(StaticText().string_("destinations:")),
				(destinationsButton= SGUIsettings()).view
			),
			HLayout(
				VLayout(
					HLayout(
						nanoCtrlButtons[\v1].put(\rew, Button().states_([
							["<<", palette.buttonText, palette.button],
							["<<", palette.buttonText, palette.highlight]
						]).fixedWidth_(25))[\rew],
						nanoCtrlButtons[\v1].put(\play, Button().states_([
							[">", palette.buttonText, palette.button],
							[">", palette.buttonText, palette.highlight]
						]).fixedWidth_(25))[\play],
						nanoCtrlButtons[\v1].put(\ff, Button().states_([
							[">>", palette.buttonText, palette.button],
							[">>", palette.buttonText, palette.highlight]
						]).fixedWidth_(25))[\ff]
					),
					HLayout(
						nanoCtrlButtons[\v1].put(\cycle, Button().states_([
							["o", palette.buttonText, palette.button],
							["o", palette.buttonText, palette.highlight]
						]).fixedWidth_(25))[\cycle],
						nanoCtrlButtons[\v1].put(\stop, Button().states_([
							[".", palette.buttonText, palette.button],
							[".", palette.buttonText, palette.highlight]
						]).fixedWidth_(25))[\stop],
						nanoCtrlButtons[\v1].put(\rec, Button().states_([
							["•", palette.buttonText, palette.button],
							["•", palette.buttonText, palette.highlight]
						]).fixedWidth_(25))[\rec]
					)
				),
				VLayout(
					HLayout(
						nanoCtrlButtons[\v2].put(\trkDec, Button().states_([
							["<", palette.buttonText, palette.button],
							["<", palette.buttonText, palette.highlight]
						]).fixedWidth_(25))[\trkDec],
						nanoCtrlButtons[\v2].put(\trkInc, Button().states_([
							[">", palette.buttonText, palette.button],
							[">", palette.buttonText, palette.highlight]
						]).fixedWidth_(25))[\trkInc],
						View()
					),
					HLayout(
						nanoCtrlButtons[\v2].put(\cycle, Button().states_([
							["cycle", palette.buttonText, palette.button],
							["cycle", palette.buttonText, palette.highlight]
						]).fixedWidth_(35))[\cycle],
						View(),
						nanoCtrlButtons[\v2].put(\mrkSet, Button().states_([
							["set", palette.buttonText, palette.button],
							["set", palette.buttonText, palette.highlight]
						]).fixedWidth_(25))[\mrkSet],
						nanoCtrlButtons[\v2].put(\mrkDec, Button().states_([
							["<", palette.buttonText, palette.button],
							["<", palette.buttonText, palette.highlight]
						]).fixedWidth_(25))[\mrkDec],
						nanoCtrlButtons[\v2].put(\mrkInc, Button().states_([
							[">", palette.buttonText, palette.button],
							[">", palette.buttonText, palette.highlight]
						]).fixedWidth_(25))[\mrkInc]
					),
					HLayout(
						nanoCtrlButtons[\v2].put(\rew, Button().states_([
							["<<", palette.buttonText, palette.button],
							["<<", palette.buttonText, palette.highlight]
						]).fixedWidth_(25))[\rew],
						nanoCtrlButtons[\v2].put(\ff, Button().states_([
							[">>", palette.buttonText, palette.button],
							[">>", palette.buttonText, palette.highlight]
						]).fixedWidth_(25))[\ff],
						nanoCtrlButtons[\v2].put(\stop, Button().states_([
							[".", palette.buttonText, palette.button],
							[".", palette.buttonText, palette.highlight]
						]).fixedWidth_(25))[\stop],
						nanoCtrlButtons[\v2].put(\play, Button().states_([
							[">", palette.buttonText, palette.button],
							[">", palette.buttonText, palette.highlight]
						]).fixedWidth_(25))[\play],
						nanoCtrlButtons[\v2].put(\rec, Button().states_([
							["•", palette.buttonText, palette.button],
							["•", palette.buttonText, palette.highlight]
						]).fixedWidth_(25))[\rec]
					)
				),
				View().maxWidth_(5),
				GridLayout.rows(
					nanoKnobElements.collect{|e| e.addView(Knob())},
					{|i|
						HLayout(
							VLayout(
								View(),
								nanoButtonSElements[i].addView(Button().states_([
									["S", palette.buttonText, palette.button],
									["S", palette.buttonText, palette.highlight]
								]).fixedWidth_(25)),
								nanoButtonMElements[i].addView(Button().states_([
									["M", palette.buttonText, palette.button],
									["M", palette.buttonText, palette.highlight]
								]).fixedWidth_(25)),
								nanoButtonRElements[i].addView(Button().states_([
									["R", palette.buttonText, palette.button],
									["R", palette.buttonText, palette.highlight]
								]).fixedWidth_(25)),
								View()
							),
							nanoSliderElements[i].addView(Slider().orientation_(\vertical))
						)
					}!nanoSliderElements.size,
					nanoChannelText= {|i| [StaticText().string_(i+1), align:\center]}!9
				)
			),
			infoTextElementString.addView(StaticText().fixedHeight_(" ".bounds(fntMono).height*2)
				.align_(\topLeft).background_(Color.grey(0.9, 0.5)))
		);
		win.onClose= {
			NetAddr.localAddr.sendMsg(\closed, name.asSymbol);
			ccResponders.do{|x| x.free};
			routineGui.stop;
		};

		devicePopup.action= {|view|
			var index;
			var device= devices[view.value];
			switch(device.version,
				1, {
					"using nanoKONTROL V1 CC mappings".postln;
					version= \v1;
					nanoCtrlButtons[\v1].keysValuesDo{|key, val| val.visible= true};
					nanoCtrlButtons[\v2].keysValuesDo{|key, val| val.visible= false};
					nanoKnobElements[8].views.do{|view| view.visible= true};
					nanoSliderElements[8].views.do{|view| view.visible= true};
					nanoButtonSElements[8].views.do{|view| view.visible= true};
					nanoButtonMElements.do{|x| x.views.do{|view| view.visible= false}};
					nanoButtonRElements[8].views.do{|view| view.visible= true};
					nanoChannelText[8][0].visible= true;
				},
				2, {
					version= \v2;
					"using nanoKONTROL V2 CC mappings".postln;
					nanoCtrlButtons[\v1].keysValuesDo{|key, val| val.visible= false};
					nanoCtrlButtons[\v2].keysValuesDo{|key, val| val.visible= true};
					nanoKnobElements[8].views.do{|view| view.visible= false};
					nanoSliderElements[8].views.do{|view| view.visible= false};
					nanoButtonSElements[8].views.do{|view| view.visible= false};
					nanoButtonMElements.do{|x| x.views.do{|view| view.visible= true}};
					nanoButtonMElements[8].views.do{|view| view.visible= false};
					nanoButtonRElements[8].views.do{|view| view.visible= false};
					nanoChannelText[8][0].visible= false;
				}
			);

			index= MIDIClient.sources.detectIndex{|x| x.uid==device.id};
			//MIDIIn.disconnect(index, MIDIClient.sources[index]);  //TODO disconnect needed?
			MIDIIn.connect(index, MIDIClient.sources[index]);

			ccResponders.do{|x| x.free};
			setupCCResponders.value(device.id);
		};

		destinationsButton.action= {
			var palette= SGUI.palette;
			var buttons= List.new;
			var cancelButton, storeButton;
			var pos, name= "destinations";
			pwin= Window.allWindows.detect{|x| x.name==name};
			if(pwin.isNil, {
				pos= Window.screenBounds.extent*#[0.4, 0.5];
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
						file.write("'%': '%'".format(devicePopup.value, destinations));
						file.write("\n}");
					});
					pwin.close;
				};
			});
			pwin.front;
		};

		setupCCResponders= {|id|

			ccResponders= [

				//--midi functions
				ccMappings[version][\knobs].collect{|cc, i|
					MIDIFunc.cc({|val, num| nanoKnobElements[i].value= val/127}, cc, srcID:id);
				},
				ccMappings[version][\sliders].collect{|cc, i|
					MIDIFunc.cc({|val, num| nanoSliderElements[i].value= val/127}, cc, srcID:id);
				},
				ccMappings[version][\buttonsS].collect{|cc, i|
					MIDIFunc.cc({|val, num| nanoButtonSElements[i].value= val/127}, cc, srcID:id);
				},
				ccMappings[version][\buttonsM].collect{|cc, i|
					MIDIFunc.cc({|val, num| nanoButtonMElements[i].value= val/127}, cc, srcID:id);
				},
				ccMappings[version][\buttonsR].collect{|cc, i|
					MIDIFunc.cc({|val, num| nanoButtonRElements[i].value= val/127}, cc, srcID:id);
				},
				MIDIFunc.cc({|val, num|
					{nanoCtrlButtons[version][\rew].valueAction= (val>0).binaryValue}.defer;
				}, ccMappings[version][\rew], srcID:id),
				MIDIFunc.cc({|val, num|
					{nanoCtrlButtons[version][\play].valueAction= (val>0).binaryValue}.defer;
				}, ccMappings[version][\play], srcID:id),
				MIDIFunc.cc({|val, num|
					{nanoCtrlButtons[version][\ff].valueAction= (val>0).binaryValue}.defer;
				}, ccMappings[version][\ff], srcID:id),
				MIDIFunc.cc({|val, num|
					{nanoCtrlButtons[version][\cycle].valueAction= (val>0).binaryValue}.defer;
				}, ccMappings[version][\cycle], srcID:id),
				MIDIFunc.cc({|val, num|
					{nanoCtrlButtons[version][\stop].valueAction= (val>0).binaryValue}.defer;
				}, ccMappings[version][\stop], srcID:id),
				MIDIFunc.cc({|val, num|
					{nanoCtrlButtons[version][\rec].valueAction= (val>0).binaryValue}.defer;
				}, ccMappings[version][\rec], srcID:id)
			];
			if(version==\v2, {
				ccResponders= ccResponders++[
					MIDIFunc.cc({|val, num|
						{nanoCtrlButtons[version][\trkDec].valueAction= (val>0).binaryValue}.defer;
					}, ccMappings[version][\trkDec], srcID:id),
					MIDIFunc.cc({|val, num|
						{nanoCtrlButtons[version][\trkInc].valueAction= (val>0).binaryValue}.defer;
					}, ccMappings[version][\trkInc], srcID:id),
					MIDIFunc.cc({|val, num|
						{nanoCtrlButtons[version][\mrkSet].valueAction= (val>0).binaryValue}.defer;
					}, ccMappings[version][\mrkSet], srcID:id),
					MIDIFunc.cc({|val, num|
						{nanoCtrlButtons[version][\mrkDec].valueAction= (val>0).binaryValue}.defer;
					}, ccMappings[version][\mrkDec], srcID:id),
					MIDIFunc.cc({|val, num|
						{nanoCtrlButtons[version][\mrkInc].valueAction= (val>0).binaryValue}.defer;
					}, ccMappings[version][\mrkInc], srcID:id)
				];
			});
			ccResponders= ccResponders.flat;
		};

		if(MIDIClient.initialized.not, {
			MIDIClient.init;
		});
		MIDIClient.sources.do{|src|
			("found midi source:"+src.device).postln;
			if(src.device.contains("nanoKONTROL"), {
				devices.add(
					(
						name: src.device,
						id: src.uid,
						version: if(src.device.contains("nanoKONTROL2"), {2}, {1})
					)
				);
			});
		};
		devicePopup.items= devices.collect{|d, i| "% [%]".format(d.name, d.id)};
		if(devicePopup.items.size>0, {
			devicePopup.valueAction= count%devicePopup.items.size;
		});
		destinations= SInputs.destinations.keys.asArray.sort;
		if(File.exists(SInstruments.preferencesDir+/+prefName), {
			prefDict= (SInstruments.preferencesDir+/+prefName).parseYAMLFile;
			tmp= prefDict[devicePopup.value.asString];
			if(tmp.notNil, {
				tmp= tmp.drop(2).drop(-2).split(Char.comma);
				tmp= tmp.collect{|str| str.stripWhiteSpace.asSymbol};
				destinations= destinations.collect{|dSym|
					if(tmp.includes(dSym), {dSym}, {nil});
				};
			});
		});
		count= count+1;

		routineGui= Routine({
			inf.do{
				nanoKnobElements.do{|e| e.update};
				nanoSliderElements.do{|e| e.update};
				nanoButtonSElements.do{|e| e.update};
				nanoButtonMElements.do{|e| e.update};
				nanoButtonRElements.do{|e| e.update};
				infoTextElementString.update;
				fps.reciprocal.wait;
			}
		}).play(AppClock);
		SGUI.report(win);
		SGUI.adapt(win);
		infoTextElementString.views.do{|view| view.font= fntMono};
		win.front;
	}

	sendOsc {|arr|
		var str= "";
		arr.do{|a|  //[destination, key, value]
			if(destinations.includes(a[0]), {
				SInputs.destinations[a[0]].sendMsg(*a[1..]);
				str= str++a.collect{|x| if(x.isFloat, {SGUI.fixDec(x, 2)}, {x})};
			});
		};
		infoTextElementString.value= str.replace("[ ", "[").replace(" ]", "] ").replace(",", "");
	}
}
