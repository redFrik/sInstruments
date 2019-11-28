//f.olofsson 2019

//assumes Swedish keyboard - adapt for other keyboards in keys Array below
//requires python script HIDtoOSC.py and an external usb keyboard
//start the script with sudo python HIDtoOSC.py 6700 2 8 '127.0.0.1' 12002

(
//--settings
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

//--functions and objects
var rows= List.new;  //one dictionary per keyboard row
var sendOsc;
var lookupButton;

//--gui
var codeTextString;
var infoTextString;
var win= Window("sQWERTYKeyboard", winRect);
win.layout= VLayout(
	HLayout(
		SGUI.shrink(StaticText().string_("Incomming keycodes from HIDtoOSC:")),
		codeTextString= StaticText().fixedHeight_(" ".bounds(fntMono).height)
		.background_(Color.grey(0.9, 0.5))
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
	arr.do{|a|
		SInputs.destinations[a[0]].sendMsg(*a[1..]);
		str= str++a;
	};
	infoTextString.string= str.replace("[ ", "[").replace(" ]", "] ").replace(", ", " ");
};

OSCFunc({|msg|
	var codes= msg[3][2..].select{|x| x>0};
	var mods= msg[3][0];  //detect modifiers like shift etc
	{
		codeTextString.string= codes;
		infoTextString.string= "";
		rows.do{|dict, i|
			var matchingKeys;
			var matchingMods;
			matchingKeys= keys[i].select{|assoc| codes.includes(assoc.value)};
			if(mods>0, {
				matchingMods= keys[i].select{|assoc|
					//NOTE make sure to add all modifier symbols here...
					#[\shiL, \shiR, \ctrl, \altL, \altR, \cmdL, \cmdR].includes(assoc.key)
					and:{assoc.value&mods!=0};
				};
			});
			dict.keysValuesDo{|key, but|
				var foundInKeys= matchingKeys.notNil and:{matchingKeys.any{|assoc| assoc.key==key}};
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
//example mapping:
//lookupButton.value('Q').action= {|view| if(view.value==1, {sendOsc.value([[\sCluster, \attack, 1]])})};

)
