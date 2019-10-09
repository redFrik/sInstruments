//f.olofsson 2019

SGUI {  //abstract class
	classvar currentPalette, <>font, <>themes, <currentTheme;
	var <view, >action;
	*initClass {
		themes= (
			dark: QPalette.dark.highlight_(Color.green(1, 0.75)),
			light: QPalette.light.highlight_(Color.green(0.5, 0.5)),
			default: QPalette.auto(Color.white, Color.white).highlight_(Color.green(2/3, 0.75))
		);
		this.selectTheme(\default);
		font= Font(Font.default, 12);
	}
	*palette {|dict|
		var p= themes[currentTheme];
		currentPalette= QPalette()
		.window_(p.window)
		.windowText_(p.windowText)
		.button_(p.button)
		.buttonText_(p.buttonText)
		.base_(p.base)
		.highlight_(p.highlight)
		.highlightText_(p.highlightText);
		if(dict.notNil, {
			dict.keysValuesDo{|key, val|
				currentPalette.setColor(val, key);
			};
		});
		^currentPalette;
	}
	*selectTheme {|theme|
		currentTheme= theme;
		^currentPalette= themes[theme] ?? {themes.default};
	}
	*fixDec {|val, numDecimals= 2|  //float to string with fixed number of decimals
		var str= val.round(0.1**numDecimals).asString;
		var num= str.size-str.indexOf($.)-1;
		^str.extend(str.size+numDecimals-num, $0);
	}
	*shrink {|staticTextView|
		^staticTextView.fixedWidth= staticTextView.string.bounds(font).width+2;
	}
	*adapt {|win|
		win.view.palette= currentPalette;
		win.view.allChildren.do{|v|
			switch(v.class,
				Button, {
					v.canFocus= false;
					v.font= font;
					v.maxHeight= 22;
				},
				ListView, {
					v.canFocus= false;
					v.font= font;
					v.selectedStringColor= currentPalette.buttonText;
					v.stringColor= currentPalette.buttonText;
					v.hiliteColor= currentPalette.highlight.alpha= 0.2;
				},
				MultiSliderView, {
					v.canFocus= false;
					v.elasticMode= true;
					v.fillColor= currentPalette.highlight;
					v.strokeColor= currentPalette.buttonText;
				},
				NumberBox, {
					v.font= font;
					v.maxHeight= 22;
					v.typingColor= currentPalette.highlight;
					v.normalColor= currentPalette.buttonText;
				},
				PopUpMenu, {
					v.canFocus= false;
					v.font= font;
					v.maxHeight= 22;
				},
				RangeSlider, {
					v.canFocus= false;
					v.knobColor= currentPalette.highlight;
					v.minHeight= 22;
				},
				Slider, {
					v.canFocus= false;
					v.knobColor= currentPalette.highlight;
				},
				StaticText, {
					v.font= font;
					v.maxHeight= 22;
				},
				TextField, {
					v.font= font;
					v.stringColor= currentPalette.buttonText;
				},
				TextView, {
					v.font= font;
					v.stringColor= currentPalette.buttonText;
				},
				UserView, {
					v.canFocus= false;
				}
			);
		};
		win.view.canFocus= true;
		win.view.focus;
		CmdPeriod.doOnce({win.close});
	}
	*report {|win|
		win.view.toFrontAction= {
			NetAddr.localAddr.sendMsg(\toFront, win.name);
		};
		win.view.endFrontAction= {
			NetAddr.localAddr.sendMsg(\endFront, win.name);
		};
	}
}

SGUIscalesTunings : SGUI {
	var <scales, <tunings;  //all available scales and tunings
	var <scale, <tuning;  //current scale and tuning
	var scalesList, tuningsList;
	*new {
		^super.new.initSGUIscalesTuning;
	}
	initSGUIscalesTuning {
		var scaleNames, tuningNames;
		view= HLayout(
			VLayout(
				StaticText().string_("Scale"),
				scalesList= ListView().background_(Color.clear)
			),
			VLayout(
				StaticText().string_("Tuning"),
				tuningsList= ListView().background_(Color.clear)
			)
		);

		scaleNames= Scale.names;
		scaleNames.addFirst(scaleNames.take(\enigmatic));
		scaleNames.addFirst(scaleNames.take(\minorPentatonic));
		scaleNames.addFirst(scaleNames.take(\minor));
		scaleNames.addFirst(scaleNames.take(\majorPentatonic));
		scaleNames.addFirst(scaleNames.take(\major));
		scaleNames.addFirst(scaleNames.take(\lydian));
		scaleNames.addFirst(scaleNames.take(\harmonicMinor));
		scaleNames.addFirst(scaleNames.take(\chromatic));
		scales= scaleNames.collect{|n| Scale.newFromKey(n)};
		scalesList.items= [\_]++scales.collect{|s| s.name.asSymbol};
		scalesList.action= {|view|
			var matchingTunings, current, tname, tindex;
			if(view.value==0, {
				this.clear;
			}, {
				scale= scales.detect{|s| s.name.asSymbol==view.items[view.value]};
				matchingTunings= tunings.select{|t| scale.checkTuningForMismatch(t)};

				if(tuningsList.value==0, {
					tuning= scale.tuning;
				}, {
					current= tuningsList.items[tuningsList.value];
					tuning= tunings.detect{|t| t.name.asSymbol==current};
					if(scale.checkTuningForMismatch(tuning), {
						scale.tuning= tuning;
					}, {
						tuning= scale.tuning;
					});
				});

				tuningsList.items= [\_]++matchingTunings.collect{|t| t.name.asSymbol};
				tname= tuning.name.asSymbol;
				tindex= matchingTunings.detectIndex{|t| t.name.asSymbol==tname};
				tuningsList.value= tindex+1;
			});
			action.value;
		};

		tuningNames= Tuning.names;
		tuningNames.addFirst(tuningNames.take(\kirnberger));
		tuningNames.addFirst(tuningNames.take(\et19));
		tuningNames.addFirst(tuningNames.take(\wcSJ));
		tuningNames.addFirst(tuningNames.take(\pythagorean));
		tuningNames.addFirst(tuningNames.take(\mean4));
		tuningNames.addFirst(tuningNames.take(\just));
		tuningNames.addFirst(tuningNames.take(\et12));
		tunings= tuningNames.collect{|n| Tuning.newFromKey(n)};
		tuningsList.items= [\_]++tunings.collect{|t| t.name.asSymbol};
		tuningsList.action= {|view|
			var matchingScales, current, sname, sindex;
			if(view.value==0, {
				this.clear;
			}, {
				tuning= tunings.detect{|t| t.name.asSymbol==view.items[view.value]};
				matchingScales= scales.select{|s| s.checkTuningForMismatch(tuning)};

				if(matchingScales.size==0, {  //eg et19
					scale= Scale.chromatic(tuning);
					scalesList.items= [\_]++scale.name.asSymbol;
					scalesList.value= 1;
				}, {
					if(scalesList.value==0, {
						sindex= matchingScales.detectIndex{|s| s.name.beginsWith("Chromatic")};
						if(sindex.isNil, {  //eg partch
							sindex= 0;
						});
					}, {
						current= scalesList.items[scalesList.value];
						sindex= matchingScales.detectIndex{|s| s.name.asSymbol==current};
						if(sindex.isNil, {
							sindex= matchingScales.detectIndex{|s| s.name.beginsWith("Chromatic")};
							if(sindex.isNil, {  //eg partch
								sindex= 0;
							});
						});
					});
					scale= matchingScales[sindex];
					scale.tuning= tuning;

					scalesList.items= [\_]++matchingScales.collect{|s| s.name.asSymbol};
					scalesList.value= sindex+1;
				});
			});
			action.value;
		};
	}
	clear {
		scalesList.items= [\_]++scales.collect{|s| s.name.asSymbol};
		tuningsList.items= [\_]++tunings.collect{|t| t.name.asSymbol};
		scalesList.value= 0;
		tuningsList.value= 0;
		scale= nil;
		tuning= nil;
	}
	size {
		if(scale.isNil, {
			^12;
		});
		^scale.size;
	}
	tune {|freq, transpose= 0|
		if(scale.notNil, {
			if(transpose==0, {
				freq= freq.cpsmidi.nearestInScale(scale.semitones).midicps;
			}, {
				freq= freq.cpsmidi.nearestInScale(scale.semitones);
				freq= freq.keyToDegree(scale.semitones, tuning.stepsPerOctave)+transpose;
				freq= freq.degreeToKey(scale.semitones, tuning.stepsPerOctave).midicps;
			});
		}, {
			freq= freq*(2**(transpose/12));
		});
		^freq;
	}
	value {^[scale!?{scale.name.asSymbol}, tuning!?{tuning.name.asSymbol}]}
	valueAction_ {|arr|  //array with symbols [scale name, tuning name]
		var sindex, tindex;
		this.clear;
		if(arr[0].notNil, {
			sindex= scalesList.items.detectIndex{|s| s==arr[0]};
			scalesList.valueAction= sindex;
		});
		if(arr[1].notNil, {
			tindex= tuningsList.items.detectIndex{|t| t==arr[1]};
			tuningsList.valueAction= tindex;
		});
	}
	fixedHeight_ {|val|
		scalesList.fixedHeight= val;
		tuningsList.fixedHeight= val;
	}
}

SGUItransposition : SGUI {
	var >scalesTunings;
	var <value= 0;
	var shiftState= false;
	var transposeKeys;
	var transpButtons;
	var transpTexts;
	var arrowButtons;  //right, left, down, up
	*new {|transposeKeys|
		^super.new.initSGUItransposition(transposeKeys);
	}
	initSGUItransposition {|argTransposeKeys|
		var transpCenterBut;
		transposeKeys= argTransposeKeys;
		transpButtons= List.new;
		transpTexts= List.new;
		arrowButtons= Array.newClear(4);
		view= VLayout(
			SGUI.shrink(StaticText().string_("Transposition")),
			HLayout(
				GridLayout.rows(
					transposeKeys.collect{|key|
						var str= key.asString;
						transpButtons.add(
							Button().states_([
								[str, currentPalette.buttonText, currentPalette.button],
								[str, currentPalette.buttonText, currentPalette.highlight]
							]).fixedWidth_(25)
						).last;
					},
					transposeKeys.collect{|key, i|
						[transpTexts.add(StaticText()).last, align:\center]
					}
				),
				HLayout(
					(arrowButtons[1]= Button().states_([
						["<", currentPalette.buttonText, currentPalette.button]
					]).fixedWidth_(25))[1],
					VLayout(
						(arrowButtons[3]= Button().states_([
							["^", currentPalette.buttonText, currentPalette.button]
						]).fixedWidth_(25))[3],
						(arrowButtons[2]= Button().states_([
							["v", currentPalette.buttonText, currentPalette.button]
						]).fixedWidth_(25))[2]
					),
					(arrowButtons[0]= Button().states_([
						[">", currentPalette.buttonText, currentPalette.button]
					]).fixedWidth_(25))[0]
				)
			)
		);
		this.updateTexts;
		transpButtons.do{|but, i|
			var step= i-transposeKeys.size.div(2);
			var transpHighest= transposeKeys.size-1-transposeKeys.size.div(2);
			if(step==0, {
				transpCenterBut= but;
				transpCenterBut.value= 1;
			});
			but.action= {|view|
				var shiftVal= 0;
				if(view.value==1, {
					if(shiftState, {
						if(step>0, {
							shiftVal= transposeKeys.size-1-transposeKeys.size.div(2);
						}, {
							if(step<0, {
								shiftVal= 0-transposeKeys.size.div(2);
							});
						});
					});
					this.valueAction= step+shiftVal;
				}, {
					transpCenterBut.valueAction= 1;
				});
			};
		};
		arrowButtons[0].action= {
			this.valueAction= value+scalesTunings.size;
		};
		arrowButtons[1].action= {
			this.valueAction= value-scalesTunings.size;
		};
		arrowButtons[2].action= {
			this.valueAction= value-1;
		};
		arrowButtons[3].action= {
			this.valueAction= value+1;
		};
	}
	updateTexts {
		transpTexts.do{|view, i|
			var str, step;
			step= i-transposeKeys.size.div(2);
			if(shiftState, {
				if(step>0, {
					step= step+(transposeKeys.size-1-transposeKeys.size.div(2));
				}, {
					if(step<0, {
						step= step-transposeKeys.size.div(2);
					});
				});
			});
			str= step.asString;
			if(step>0, {str= "+"++step});
			view.string= str;
		};
	}
	updateButtons {
		var index= 0;
		if(shiftState, {
			if(value>0, {
				index= value-(transposeKeys.size-1-transposeKeys.size.div(2));
			}, {
				if(value<0, {
					index= value+transposeKeys.size.div(2);
				});
			});
		}, {
			index= value;
		});
		index= index+transposeKeys.size.div(2);
		if(index>=0 and:{index<transposeKeys.size}, {
			transpButtons.do{|b, i| b.value= (i==index).binaryValue};
		}, {
			transpButtons.do{|b| b.value= 0};
		});
	}
	value_ {|val= 0|
		if(val!=value, {
			value= val;
			this.updateButtons;
		});
	}
	valueAction_ {|step|
		var lastValue= value;
		this.value= step;
		action.value(value, value-lastValue);
	}
	keyDownAction {|chr, mod, unicode, keycode|
		if(mod.isShift, {
			shiftState= true;
			this.updateTexts;
		});
		case
		{keycode==124} {arrowButtons[0].doAction}  //right
		{keycode==123} {arrowButtons[1].doAction}  //left
		{keycode==125} {arrowButtons[2].doAction}  //down
		{keycode==126} {arrowButtons[3].doAction}  //up
		{keycode==33} {transpButtons[transpButtons.size-2].valueAction= 1}
		{keycode==30} {transpButtons[transpButtons.size-1].valueAction= 1}
		{transposeKeys.includes(chr.toUpper)} {
			transpButtons[transposeKeys.indexOf(chr.toUpper)].valueAction= 1;
		};
	}
	keyUpAction {|chr, mod, unicode, keycode|
		if(mod.isShift.not, {
			shiftState= false;
			this.updateTexts;
		});
	}
}

SGUImasterTuning : SGUI {
	var <value= 440;
	var box;
	*new {|min= 390, max= 490|
		^super.new.initSGUImasterTuning(min, max);
	}
	initSGUImasterTuning {|min, max|
		view= HLayout(
			SGUI.shrink(StaticText().string_("Master tuning")),
			box= NumberBox().scroll_step_(0.01).decimals_(3).fixedWidth_(55),
			SGUI.shrink(StaticText().string_("Hz"))
		);
		box.action= {|view|
			view.value= view.value.clip(min, max);
			value= view.value;
			action.value(value);
		};
		box.value= 440;
	}
	tune {|freq|
		^(freq.cpsmidi+(value.cpsmidi-69)).midicps;
	}
	valueAction_ {|val|
		box.valueAction= val;
	}
}

SGUIcurvature : SGUI {
	var popup, slider, box, usr;
	var lineArr;
	var spec;
	*new {
		^super.new.initSGUIcurvature;
	}
	initSGUIcurvature {
		view= HLayout(
			slider= Slider().orientation_(\vertical).maxSize_(22@100),
			VLayout(
				popup= PopUpMenu().items_(#[
					\manual_curvature,
					\step,
					\linear,
					\exponential,
					\sine,
					\welch,
					\squared,
					\cubed
				]),
				[HLayout(
					box= NumberBox().scroll_step_(0.1).maxDecimals_(1).fixedWidth_(35),
					usr= UserView().fixedSize_(67@67)
				), align:\topLeft]
			)
		);
		popup.action= {|view|
			slider.enabled= false;
			box.enabled= false;
			switch(view.value,
				0, {
					slider.enabled= true;
					box.enabled= true;
					action.value(\warp, 5);
					this.calculateLine(5, box.value);
				},
				1, {  //step
					action.value(\warp, 0);
					this.calculateLine(0, 0);
				},
				2, {  //linear
					action.value(\warp, 1);
					this.calculateLine(1, 0);
				},
				3, {  //exponential
					action.value(\warp, 2);
					this.calculateLine(2, 0);
				},
				4, {  //sine
					action.value(\warp, 3);
					this.calculateLine(3, 0);
				},
				5, {  //welch
					action.value(\warp, 4);
					this.calculateLine(4, 0);
				},
				6, {  //squared
					action.value(\warp, 6);
					this.calculateLine(6, 0);
				},
				7, {  //cubed
					action.value(\warp, 7);
					this.calculateLine(7, 0);
				}
			);
		};
		spec= ControlSpec(-20, 20, 'lin', 0, -4);
		slider.action= {|view|
			box.valueAction= spec.map(view.value);
		};
		box.action= {|view|
			view.value= spec.constrain(view.value);
			action.value(\curv, view.value);
			this.calculateLine(5, view.value);
			slider.value= spec.unmap(view.value);
		};
		usr.background= Color.clear;
		usr.drawFunc= {|usr|
			var uw= usr.bounds.width;
			var uh= usr.bounds.height;
			Pen.strokeColor= currentPalette.buttonText;
			lineArr.do{|val, i|
				var x= i.linlin(0, lineArr.size-1, 0, uw);
				var y= val.linlin(0, 1, uh-1, 1);
				if(i==0, {
					Pen.moveTo(Point(0, y));
				}, {
					Pen.lineTo(Point(x, y));
				});
			};
			Pen.stroke;
		};
	}
	calculateLine {|warp, curv|
		{DC.kr(1).varlag(0.198, curv, warp, 0.001)}.loadToFloatArray(0.2, action:{|arr|
			lineArr= arr;
			{usr.refresh}.defer;
		});
	}
	value {^[box.value, popup.value]}
	valueAction_ {|arr|
		slider.value= spec.unmap(arr[0]);
		box.valueAction= arr[0];
		popup.valueAction= arr[1];
	}
	valueActionNorm_ {|arr|
		slider.value= arr[0];
		box.valueAction= spec.map(arr[0]);
		popup.valueAction= arr[1];
	}
}

SGUIglissTime : SGUI {
	var slider, box;
	var spec;
	*new {|val|
		^super.new.initSGUIglissTime(val);
	}
	initSGUIglissTime {|val|
		view= HLayout(
			SGUI.shrink(StaticText().string_("Gliss time")),
			slider= Slider().orientation_(\horizontal),
			box= NumberBox().scroll_step_(0.1).fixedWidth_(55),
			SGUI.shrink(StaticText().string_("s"))
		);
		spec= ControlSpec(0.1, 1000, 'exp', 0, val, "s");
		slider.action= {|view|
			box.valueAction= spec.map(view.value);
		};
		box.action= {|view|
			view.value= spec.constrain(view.value);
			action.value(view.value);
			slider.value= spec.unmap(view.value);
		};
	}
	value {^box.value}
	valueAction_ {|val|
		slider.value= spec.unmap(val);
		box.valueAction= val;
	}
	valueActionNorm_ {|val|
		slider.valueAction= val;
	}
}

SGUIsettings : SGUI {
	*new {
		^super.new.initSGUIsettings;
	}
	initSGUIsettings {
		var size= Size(22, 22);
		var button;
		view= StackLayout(
			UserView().drawFunc_({
				Pen.strokeColor= currentPalette.buttonText;
				SGUIicons.drawCog(size.width);
			}).acceptsMouse_(false).fixedSize_(size),
			button= Button().states_([]).fixedSize_(size)
		).mode_(\stackAll);
		button.action= {|view|
			action.value(view);
		};
	}
}

SGUIsnapshots : SGUI {
	var >include;
	var >recallFunctions;
	var <banks;
	var path, files, bankKeys, snapshotKeys;
	var bankButtons, snapButtons;
	var activeSnapshot;
	*new {|path, files, bankKeys, snapshotKeys, instrument|
		^super.new.initSGUIsnapshot(path, files, bankKeys, snapshotKeys, instrument);
	}
	initSGUIsnapshot {|argPath, argFiles, argBankKeys, argSnapshotKeys, instrument|
		var settingsButton;
		path= argPath;
		files= argFiles;
		bankKeys= argBankKeys.flat;
		snapshotKeys= argSnapshotKeys.flat;
		if(File.exists(path).not, {path.mkdir});
		banks= files.collect{|assoc|
			if(File.exists(path+/+assoc.value), {
				Object.readArchive(path+/+assoc.value);
			}, {
				();
			});
		};
		activeSnapshot= [nil, nil];
		bankButtons= List.new;
		snapButtons= List.new;
		view= VLayout(
			HLayout(
				SGUI.shrink(StaticText().string_("Snapshots")),
				(settingsButton= SGUIsettings()).view
			),
			HLayout(
				*files.collect{|assoc|
					var str= assoc.key.asString;
					bankButtons.add(
						Button().states_([
							[str, currentPalette.buttonText, currentPalette.button],
							[str, currentPalette.buttonText, currentPalette.highlight]
						]).fixedWidth_(str.bounds(font).width+5)
					).last;
				}
			),
			VLayout(
				*argSnapshotKeys.collect{|row|
					HLayout(
						*snapButtons.add(
							row.collect{|key| Button().states_([
								[key, currentPalette.buttonText, currentPalette.button],
								[key, currentPalette.highlight, currentPalette.button],
								[key, currentPalette.buttonText, currentPalette.highlight]
							]).fixedWidth_(25)}
						).last
					)
				}
			),
			[SGUI.shrink(StaticText().string_("(shift+click to store)")), align:\top]
		);
		settingsButton.action= {|view|
			var copyFromPopup, copyToPopup, copyButton;
			var clearPopup, clearButton;
			var backupPopup, recallButton, storeButton;
			var infoText, doneButton;
			var pos, name= "snapshot settings - "++(instrument?"");
			var win= Window.allWindows.detect{|x| x.name==name};
			if(win.isNil, {
				pos= Window.screenBounds.extent*0.6;
				win= Window(name, Rect.aboutPoint(pos, 250, 100));
				win.view.layout_(VLayout(
					StaticText().string_("Copy - overwrite all snapshots in a bank with snapshots from another"),
					HLayout(
						copyFromPopup= PopUpMenu().items_({|i| "Bank"++(i+1)}!banks.size),
						SGUI.shrink(StaticText().string_("->")),
						copyToPopup= PopUpMenu().items_({|i| "Bank"++(i+1)}!banks.size).value_(1),
						copyButton= Button().states_([
							["Copy", currentPalette.buttonText, currentPalette.button]
						])
					),
					StaticText().string_("Clear - erase all snapshots in a bank"),
					HLayout(
						clearPopup= PopUpMenu().items_({|i| "Bank"++(i+1)}!banks.size),
						clearButton= Button().states_([
							["Clear", currentPalette.buttonText, currentPalette.button]
						])
					),
					StaticText().string_("Backup - read or write a bank of snapshots to file"),
					HLayout(
						backupPopup= PopUpMenu().items_({|i| "Bank"++(i+1)}!banks.size),
						recallButton= Button().states_([
							["Recall", currentPalette.buttonText, currentPalette.button]
						]),
						storeButton= Button().states_([
							["Store", currentPalette.buttonText, currentPalette.button]
						])
					),
					View(),
					infoText= StaticText(),
					HLayout(
						[View(), stretch:1],
						doneButton= Button().states_([
							["Done", currentPalette.buttonText, currentPalette.button]
						])
					)
				));
				this.class.adapt(win);
				infoText.minHeight_(44);
				win.view.keyDownAction= {|view, chr, mod, unicode, keycode, key|
					if(unicode==27, {win.close});  //esc
					if(unicode==13, {win.close});
				};

				copyButton.action_({
					infoText.string= "";
					infoText.stringColor= currentPalette.buttonText;
					if(copyFromPopup.value!=copyToPopup.value, {
						SGUIdialogWindow({
							banks[copyToPopup.value]= banks[copyFromPopup.value].copy;
							banks[copyToPopup.value].writeArchive(path+/+files[copyToPopup.value].value);
							this.updateSnapButtons(copyToPopup.value);
							infoText.string= "copied snapshots from Bank% to Bank%".format(
								copyFromPopup.value+1,
								copyToPopup.value+1
							);
						});
					}, {
						infoText.stringColor= Color.red;
						infoText.string= "Error: cannot copy to and from the same bank";
					});
				});
				clearButton.action_({
					infoText.string= "";
					infoText.stringColor= currentPalette.buttonText;
					SGUIdialogWindow({
						banks[clearPopup.value]= ();
						banks[clearPopup.value].writeArchive(path+/+files[clearPopup.value].value);
						this.updateSnapButtons(clearPopup.value);
						infoText.string= "cleared snapshots in Bank%".format(clearPopup.value+1);
					});
				});
				recallButton.action_({
					infoText.string= "";
					infoText.stringColor= currentPalette.buttonText;
					FileDialog({|paths|
						var ok, bank;
						try{bank= Object.readArchive(paths[0])};
						if(bank.notNil and:{bank.notEmpty}, {
							ok= bank.every{|arr|
								arr.any{|assoc| assoc.key==\snapshotInstrument and:{assoc.value==instrument}};
							};
							if(ok, {
								banks[backupPopup.value]= bank;
								banks[backupPopup.value].writeArchive(path+/+files[backupPopup.value].value);
								this.updateSnapButtons(copyToPopup.value);
								infoText.string= "loaded snapshots into Bank%".format(backupPopup.value+1);
							}, {
								infoText.stringColor= Color.red;
								infoText.string= "Error: non matching instrument bank in file %".format(paths[0]);
							});
						}, {
							infoText.stringColor= Color.red;
							infoText.string= "Error: not a valid bank file %".format(paths[0]);
						});
					}, {}, 1, 0);
				});
				storeButton.action_({
					infoText.string= "";
					infoText.stringColor= currentPalette.buttonText;
					if(banks[backupPopup.value].notEmpty, {
						FileDialog({|paths|
							var bank= banks[backupPopup.value];
							bank.do{|arr|  //safety - make sure instrument is there for old snapshots
								if(arr.any{|assoc| assoc.key==\snapshotInstrument and:{assoc.value==instrument}}.not, {
									arr.add((\snapshotInstrument -> instrument));
								});
							};
							bank.writeArchive(paths[0]);
							infoText.string= "saved snapshots from Bank% to file %".format(backupPopup.value+1, paths[0]);
						}, {}, 0, 1);
					}, {
						infoText.stringColor= Color.red;
						infoText.string= "Error: Bank% is empty".format(backupPopup.value+1);
					});
				});
				doneButton.action_({
					win.close;
				});
			});
			win.front;
		};
		bankButtons.do{|but, i|
			but.action= {|view|
				bankButtons.do{|b| b.value= 0};
				view.value= 1;
				this.updateSnapButtons(i);
			};
		};
		snapButtons= snapButtons.flat;
		snapButtons.do{|but, i|
			var key= snapshotKeys[i].asSymbol;
			but.action= {|view, mod|
				var index= bankButtons.detectIndex{|b| b.value==1};
				if(mod.isShift, {
					this.store(index, key);
					activeSnapshot= [index, view];
					this.updateSnapButtons(index);
				}, {
					if(banks[index][key].notNil, {
						this.recall(index, key);
						activeSnapshot= [index, view];
						this.updateSnapButtons(index);
					});
				});
			};
		};
		bankButtons[0].valueAction= 1;
	}
	store {|index, key|
		if(banks[index][key].isNil, {
			"storing new snapshot %:%".format(files[index].key, key).postln;
		}, {
			"overwriting snapshot %:%".format(files[index].key, key).postln;
		});
		banks[index].put(key, List.new);
		Routine({
			include.pairsDo{|name, item|
				banks[index][key].add((name->item.value(Condition(true))));
			};
			banks[index].writeArchive(path+/+files[index].value);
		}).play(AppClock);
	}
	recall {|index, key|
		"recalling snapshot %:%".format(files[index].key, key).postln;
		banks[index][key].do{|assoc|
			if(recallFunctions[assoc.key].notNil, {
				recallFunctions[assoc.key].value(assoc.value);
			}, {
				include.pairsDo{|k, v|
					if(k==assoc.key, {
						v.valueAction= assoc.value;
					});
				};
			});
		};
	}
	updateSnapButtons {|index|
		snapButtons.do{|but, i|
			var key= snapshotKeys[i].asSymbol;
			if(banks[index][key].isNil, {
				but.value= 0;
			}, {
				if(index==activeSnapshot[0] and:{but==activeSnapshot[1]}, {
					but.value= 2;
				}, {
					but.value= 1;
				});
			});
		};
	}
	keyDownAction {|chr, mod|
		var index= snapshotKeys.detectIndex{|c| chr.toUpper==c};
		if(index.notNil, {
			snapButtons[index].doAction(mod);
		}, {
			index= bankKeys.detectIndex{|c| chr.toUpper==c};
			if(index.notNil, {
				bankButtons[index].doAction;
			});
		});
	}
}

SGUIvolume : SGUI {
	var slider;
	var spec;
	*new {
		^super.new.initSGUIvolume;
	}
	initSGUIvolume {
		view= HLayout(
			StaticText().string_("Volume").fixedWidth_(45),  //not shrunk because should match balance etc
			slider= Slider().orientation_(\horizontal)
		);
		spec= ControlSpec(-90, 2, 'db', 0, 0, "dB");
		slider.action= {|view|
			action.value(spec.map(view.value));
		};
	}
	value {^spec.map(slider.value)}
	valueAction_ {|val|
		slider.valueAction= spec.unmap(val);
	}
}

SGUIcpu : SGUI {
	*new {|server, updateRate= 0.1|
		^super.new.initSGUIcpu(server, updateRate);
	}
	initSGUIcpu {|server, updateRate|
		var task;
		server= server??{Server.default};
		view= StaticText().fixedWidth_("Avg CPU: 100.00%".bounds(font).width+2);
		updateRate= updateRate.max(0.01);
		server.waitForBoot{
			task= Routine({
				inf.do{
					view.string= "Avg CPU: %\\%".format(SGUI.fixDec(server.avgCPU, 2));
					updateRate.wait;
				};
			}).play(AppClock);
			view.onClose= {task.stop};
		};
	}
	value {^view.string}
}

SGUIrecord : SGUI {
	*new {|server, path, prefix= ""|
		^super.new.initSGUIrecord(server, path, prefix);
	}
	initSGUIrecord {|server, path, prefix|
		server= server??{Server.default};
		view= Button().states_([
			["  Record", currentPalette.buttonText, currentPalette.button],
			["√Record", currentPalette.buttonText, currentPalette.highlight]
		]);
		view.action= {|view|
			var file;
			if(view.value==1, {
				file= prefix++Date.localtime.stamp++"."++server.recHeaderFormat;
				if(File.exists(path).not, {path.mkdir});
				server.record(path+/+file);
			}, {
				if(server.isRecording, {server.stopRecording});
			});
		};
		view.onClose= {if(server.isRecording, {server.stopRecording})};
	}
	value {^view.value}
	valueAction_ {|val|
		view.valueAction= val;
	}
}

SGUIampUserView : SGUI {
	var <uw, <uh, pw, ph;
	*new {|usrView, usrPadding|
		^super.new.initSGUIampUserView(usrView, usrPadding);
	}
	initSGUIampUserView {|usrView, usrPadding|
		usrView.background= Color.clear;
		usrView.clearOnRefresh= true;
		pw= usrPadding.width;
		ph= usrPadding.height;
		uw= usrView.bounds.width-pw;
		uh= usrView.bounds.height-(ph*2);
		usrView.onResize= {
			uw= usrView.bounds.width-pw;
			uh= usrView.bounds.height-(ph*2);
		};
	}
	drawMarkings {|numMarkings= 5, ampRangeLo, ampRangeHi|
		var y, str;
		Pen.fillColor= currentPalette.buttonText;
		Pen.strokeColor= Color.grey(0.5, 0.5);
		str= SGUI.fixDec(ampRangeLo, 2);
		y= ampRangeLo.linlin(0, 1, 0, 0-uh);
		Pen.stringLeftJustIn(str, Rect.aboutPoint(Point(0, 0), pw, 10));
		str= SGUI.fixDec(ampRangeHi, 2);
		y= ampRangeHi.linlin(0, 1, 0, 0-uh);
		Pen.stringLeftJustIn(str, Rect.aboutPoint(Point(0, 0-uh), pw, 10));
		numMarkings.do{|i|
			var amp= i.linlin(0, numMarkings-1, 0, 1);
			if(amp>=ampRangeLo and:{amp<=ampRangeHi}, {
				y= amp.linlin(ampRangeLo, ampRangeHi, 0, 0-uh);
				Pen.moveTo(Point(0, y));
				Pen.lineTo(Point(uw, y));
				if(y>(5-uh) and:{y<(-5)}, {
					str= SGUI.fixDec(amp, 2);
					Pen.stringLeftJustIn(str, Rect.aboutPoint(Point(0, y), pw, 10));
				});
			});
		};
		Pen.stroke;
	}
	drawTarget {|target, ampRangeLo, ampRangeHi|
		var x= target.position.x*uw;
		var y= target.position.y.linlin(ampRangeLo, ampRangeHi, 0, 0-uh);
		var str= SGUI.fixDec(target.amplitude.linlin(0, 1, ampRangeLo, ampRangeHi), 2);
		Pen.fillOval(Rect.aboutPoint(Point(x, y), 10, 10));
		Pen.stringCenteredIn(str, Rect.aboutPoint(Point(x, y-15), 25, 10));
	}
}

SGUIfreqUserView : SGUI {
	var <uw, <uh, pw, ph;
	var minFreq, maxFreq;
	*new {|usrView, usrPadding, minFreq= 20, maxFreq= 12000|
		^super.new.initSGUIfreqUserView(usrView, usrPadding, minFreq, maxFreq);
	}
	initSGUIfreqUserView {|usrView, usrPadding, argMinFreq, argMaxFreq|
		usrView.background= Color.clear;
		usrView.clearOnRefresh= true;
		pw= usrPadding.width;
		ph= usrPadding.height;
		uw= usrView.bounds.width-pw;
		uh= usrView.bounds.height-(ph*2);
		usrView.onResize= {
			uw= usrView.bounds.width-pw;
			uh= usrView.bounds.height-(ph*2);
		};
		minFreq= argMinFreq;
		maxFreq= argMaxFreq;
	}
	drawMarkings {|numMarkings= 10, freqRangeLo, freqRangeHi|
		var y, str;
		Pen.fillColor= currentPalette.buttonText;
		Pen.strokeColor= Color.grey(0.5, 0.5);
		str= freqRangeLo.asInteger.asString++"Hz";
		y= freqRangeLo.explin(minFreq, maxFreq, 0, 0-uh);
		Pen.stringLeftJustIn(str, Rect.aboutPoint(Point(0, 0), pw, 10));
		str= freqRangeHi.asInteger.asString;
		y= freqRangeHi.explin(minFreq, maxFreq, 0, 0-uh);
		Pen.stringLeftJustIn(str, Rect.aboutPoint(Point(0, 0-uh), pw, 10));
		numMarkings.do{|i|
			var freq= i.linexp(0, numMarkings-1, minFreq, maxFreq);
			if(freq>=freqRangeLo and:{freq<=freqRangeHi}, {
				y= freq.explin(freqRangeLo, freqRangeHi, 0, 0-uh);
				Pen.moveTo(Point(0, y));
				Pen.lineTo(Point(uw, y));
				if(y>(5-uh) and:{y<(-5)}, {
					str= freq.asInteger.asString;
					Pen.stringLeftJustIn(str, Rect.aboutPoint(Point(0, y), pw, 10));
				});
			});
		};
		Pen.stroke;
	}
	drawTarget {|target, freq|
		var x= target.position.x*uw;
		var y= target.position.y*(0-uh);
		Pen.fillOval(Rect.aboutPoint(Point(x, y), 10, 10));
		Pen.stringCenteredIn(SGUI.fixDec(freq, 2), Rect.aboutPoint(Point(x, y-15), 25, 10));
	}
}

SGUIdialogWindow : SGUI {
	*new {|action, text= "Are you sure?"|
		^super.new.initSGUIdialogWindow(action, text);
	}
	initSGUIdialogWindow {|argAction, argText|
		var okButton, cancelButton;
		var pos= Window.screenBounds.extent*0.5;
		var win= Window("Confirm", Rect.aboutPoint(pos, 100, 50), false, false);
		win.view.layout_(VLayout(
			StaticText().string_(argText),
			HLayout(
				okButton= Button().states_([
					["Ok", currentPalette.buttonText, currentPalette.button]
				]),
				View(),
				cancelButton= Button().states_([
					["Cancel", currentPalette.buttonText, currentPalette.button]
				])
			)
		));
		this.class.adapt(win);
		win.view.keyDownAction= {|view, chr, mod, unicode, keycode, key|
			if(unicode==27, {win.close});  //esc
		};
		okButton.action= argAction<>{win.close};
		cancelButton.action= {win.close};
		win.front;
		view= win;
	}
}
