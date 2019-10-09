//f.olofsson 2019

(
//--settings
var winRect= Rect(0, 60, 800, 120);  //x, y, w, h
var palette= SGUI.palette;
var fnt= SGUI.font;
var fnt2= SGUI.font.copy.size_(10);
var range= [36, 96];  //minmax range in midinotes, first&last black keys are ignored

//--functions and objects
var keys, createKeys, numWhiteKeys, lastKey;
var whiteKeySize, blackKeySize;
var velClicked, currentKey, setCurrentKey;
var updateMidiNotesText, updateMidiVelocitiesText;
var stringToFloats;

//--gui
var minNumber, maxNumber;
var presetsPop;
var clearButton;
var usrView;
var midiNotesText, midiVelocitiesText;
var midiSendPop, midiSendBut;
var win= Window("sKeyboard", winRect);
win.layout= VLayout(
	HLayout(
		StaticText().string_("Min"),
		minNumber= NumberBox().fixedWidth_(55).step_(1),//.clipLo_(0).clipHi_(127),
		StaticText().string_("Max"),
		maxNumber= NumberBox().fixedWidth_(55).step_(1),//.clipLo_(0).clipHi_(127),
		View().fixedWidth_(55),
		StaticText().string_("Presets:"),
		[presetsPop= PopUpMenu(), stretch:1],
		clearButton= Button().states_([["Clear"]])
	),
	usrView= UserView().minSize_(Size(winRect.width-22, winRect.height*0.75)),
	midiNotesText= TextView().maxHeight_(22),
	midiVelocitiesText= TextView().maxHeight_(22),
	HLayout(
		midiSendPop= PopUpMenu().items_(#["sCluster", "sDrone", "sGliss", "sStream-patterns", "sStream"]),
		midiSendBut= Button().states_([["Send"]])
	)
);
SGUI.report(win);
SGUI.adapt(win);
win.onClose= {
	NetAddr.localAddr.sendMsg(\closed, \sKeyboard);
};
win.front;


minNumber.action= {|view|
	view.value= view.value.clip(0, maxNumber.value-1);
	if(range[0]!=view.value, {
		range[0]= view.value.asInteger;
		createKeys.value;
		usrView.refresh;
	});
};
minNumber.value= range[0];
maxNumber.action= {|view|
	view.value= view.value.clip(minNumber.value+1, 127);
	if(range[1]!=view.value, {
		range[1]= view.value.asInteger;
		createKeys.value;
		usrView.refresh;
	});
};
maxNumber.value= range[1];

presetsPop.items= #["", "random notes", "Octaves", "Overtones", "Overtones2", "Cmaj7", "D#m"];
presetsPop.action= {|view|
	switch(view.value,
		0, {
			keys.do{|key|
				key.put(\isClicked, false);
			};
		},
		1, {
			keys.do{|key|
				key.put(\isClicked, 0.333.coin);
				key.put(\velocity, 127.rand+1);
			};
		},
		2, {
			keys.do{|key|
				key.put(\isClicked, #[60, 72, 84].includes(key.note));
				key.put(\velocity, 80);
			};
		},
		3, {
			keys.do{|key, i|
				key.put(\isClicked, #[48, 60, 67, 72, 76, 79, 82].includes(key.note));
				key.put(\velocity, (80-i).max(1));
			};
		},
		4, {
			keys.do{|key, i|
				key.put(\isClicked, #[43, 55, 62, 67, 71].includes(key.note));
				key.put(\velocity, (80-i).max(1));
			};
		},
		5, {
			keys.do{|key|
				var index= #[60, 64, 67, 71].indexOf(key.note);
				if(index.notNil, {
					key.put(\isClicked, true);
					key.put(\velocity, #[64, 60, 56, 52][index]);
				}, {
					key.put(\isClicked, false);
				});
			};
		},
		6, {
			keys.do{|key|
				var index= #[63, 66, 70].indexOf(key.note);
				if(index.notNil, {
					key.put(\isClicked, true);
					key.put(\velocity, 80);
				}, {
					key.put(\isClicked, false);
				});
			};
		}
	);
	updateMidiNotesText.value;
	updateMidiVelocitiesText.value;
	usrView.refresh;
};

clearButton.action= {|view|
	presetsPop.valueAction= 0;
};

usrView.drawFunc= {|usr|
	var x;
	whiteKeySize= Size(usr.bounds.width/numWhiteKeys, usr.bounds.height);
	blackKeySize= Size(whiteKeySize.width*0.6, whiteKeySize.height*0.6);

	Pen.push;
	x= 0;
	Pen.strokeColor= Color.black;
	keys.do{|key|
		var strRect, velPoint;
		if(key.isWhite, {
			key.put(\rect, Rect(x, 0, whiteKeySize.width, whiteKeySize.height));
			if(key.isClicked, {
				velPoint= Point(whiteKeySize.width*0.5+x, key.velocity.linlin(0, 127, 5, whiteKeySize.height-5));
				Pen.fillColor= Color.grey(0.75, 0.75);
			}, {
				Pen.fillColor= Color.white;
			});
			Pen.addRect(key.rect);
			Pen.fillStroke;
			if(velPoint.notNil, {
				Pen.fillColor= palette.highlight;
				Pen.fillOval(Rect.aboutPoint(velPoint, 5, 5));
			});
			key.put(\velPoint, velPoint);
			strRect= Rect(x, whiteKeySize.height-20, whiteKeySize.width, 20);
			Pen.stringCenteredIn(key.note.asString, strRect, fnt2, Color.black);
			x= x+whiteKeySize.width;
		});
	};
	Pen.pop;

	Pen.push;
	x= 0-whiteKeySize.width;
	keys.do{|key|
		var xx, strRect, velPoint;
		if(key.isWhite.not and:{usr.bounds.width-1-x>whiteKeySize.width}, {
			xx= x+(whiteKeySize.width*0.667);
			key.put(\rect, Rect(xx, 0, blackKeySize.width, blackKeySize.height));
			if(key.isClicked, {
				velPoint= Point(blackKeySize.width*0.5+xx, key.velocity.linlin(0, 127, 5, blackKeySize.height-5));
				Pen.fillColor= Color.grey(0.25, 0.75);
			}, {
				Pen.fillColor= Color.black;
			});
			Pen.addRect(key.rect);
			Pen.fill;
			if(velPoint.notNil, {
				Pen.fillColor= palette.highlight;
				Pen.fillOval(Rect.aboutPoint(velPoint, 5, 5));
			});
			key.put(\velPoint, velPoint);
			strRect= Rect(xx, blackKeySize.height-20, blackKeySize.width, 20);
			Pen.stringCenteredIn(key.note.asString, strRect, fnt2, Color.white);
		}, {
			x= x+whiteKeySize.width;
		});
	};
	Pen.pop;
};
usrView.mouseDownAction= {|view, x, y, mod|
	setCurrentKey.value(x, y);
	velClicked= currentKey.velPoint.notNil and:{Point(x, y).dist(currentKey.velPoint)<=5};
	usrView.mouseMoveAction.value(view, x, y, mod);
};
usrView.mouseMoveAction= {|view, x, y, mod|
	var keyHeight;
	setCurrentKey.value(x, y);
	if(currentKey.notNil, {  //can be nil if dragged outside
		if(currentKey.isWhite, {
			keyHeight= whiteKeySize.height;
		}, {
			keyHeight= blackKeySize.height;
		});
		currentKey.put(\velocity, y.linlin(0, keyHeight, 0, 127).clip(1, 127).asInteger);
		if(velClicked.not and:{lastKey!=currentKey}, {
			lastKey= currentKey;
			currentKey.put(\isClicked, currentKey.isClicked.not);
			updateMidiNotesText.value;
		});
		updateMidiVelocitiesText.value;
		usrView.refresh;
	});
};
usrView.mouseUpAction= {|view, x, y, mod|
	lastKey= nil;
};

setCurrentKey= {|x, y|
	var mousePos= Point(x, y);
	currentKey= keys.detect{|key|  //first check black
		key.isWhite.not and:{key.rect.contains(mousePos)};
	};
	if(currentKey.isNil, {
		currentKey= keys.detect{|key|  //then white
			key.isWhite and:{key.rect.contains(mousePos)};
		};
	});
};

createKeys= {
	keys= List.new;
	{|i|
		var note= range[0]+i;
		var black= #[1, 3, 6, 8, 10].includes(note%12);
		if((black and:{i==0 or:{i==(range[1]-1)}}).not, {  //ignore start and/or end black key
			keys.add((
				note: note,
				velocity: 0,
				isWhite: black.not,
				isClicked: false
			));
		});
	}!(range[1]+1-range[0]);
	numWhiteKeys= keys.count{|key| key.isWhite};
};
createKeys.value;

updateMidiNotesText= {
	var str= "";
	keys.do{|key|
		if(key.isClicked, {
			str= str++key.note.asString++", ";
		});
	};
	str= str.drop(-2);
	midiNotesText.string= str;
	midiNotesText.stringColor= palette.buttonText;
};
updateMidiVelocitiesText= {
	var str= "";
	keys.do{|key|
		if(key.isClicked, {
			str= str++key.velocity.asString++", ";
		});
	};
	str= str.drop(-2);
	midiVelocitiesText.string= str;
	midiVelocitiesText.stringColor= palette.buttonText;
};

stringToFloats= {|str|
	str= str.split(Char.comma);
	str.collect{|s| s.asFloat};
};
midiSendBut.action= {
	var freqs, amps, dest;
	freqs= stringToFloats.value(midiNotesText.string).midicps;
	amps= stringToFloats.value(midiVelocitiesText.string)/127;
	dest= midiSendPop.items[midiSendPop.value].asSymbol;
	if(dest=='sStream-patterns', {  //special case
		SInputs.destinations[\sStream].sendMsg(\patternFrequencies, *freqs.postln);
		SInputs.destinations[\sStream].sendMsg(\patternAmplitudes, *amps.postln);
	}, {
		SInputs.destinations[dest].sendMsg(\frequencies, *freqs.postln);
		{SInputs.destinations[dest].sendMsg(\amplitudes, *amps.postln)}.defer(0.5);  //safety for sCluster
	});
};
)
