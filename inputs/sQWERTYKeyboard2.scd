//f.olofsson 2019

//assumes Swedish keyboard - adapt for other keyboards in keys Array below
//requires python script HIDtoOSC.py and an external usb keyboard http://fredrikolofsson.com/f0blog/?q=node/669
//start the script with sudo python HIDtoOSC.py --vid 6700 --pid 2 --port 12002

(
//--settings
var keys= [  //EDIT character and keycode mappings. more can be added
	[\Esc->41, \F1->58, \F2->59, \F3->60, \F4->61, \F5->62, \F6->63, \F7->64, \F8->65, \F9->66, \F10->67, \F11->68, \F12->69],
	['§'->53, '1'->30, '2'->31, '3'->32, '4'->33, '5'->34, '6'->35, '7'->36, '8'->37, '9'->38, '0'->39, '+'->45, '´'->46, \Del->42],
	[\Tab->43, 'Q'->20, 'W'->26, 'E'-> 8, 'R'->21, 'T'->23, 'Y'->28, 'U'->24, 'I'->12, 'O'->18, 'P'->19, 'Å'->47, '¨'->48],
	[\Cap->57, 'A'-> 4, 'S'->22, 'D'-> 7, 'F'-> 9, 'G'->10, 'H'->11, 'J'->13, 'K'->14, 'L'->15, 'Ö'->51, 'Ä'->52, '\''->50, \Ret->40],
	[\shiL->2, '<'->100, 'Z'->29, 'X'->27, 'C'->6, 'V'->25, 'B'-> 5, 'N'->17, 'M'->16, ','->54, '.'->55, '-'->56, \shiR->32],
	[\ctrl->1, \altL->4, \cmdL->8, ' '->44, \cmdR->128, \altR->64]
];
var mods= #[\shiL, \shiR, \ctrl, \altL, \altR, \cmdL, \cmdR];  //EDIT list keys that are modifiers here
var kb= SQWERTYKeyboard("sQWERTYKeyboard2", Point(116, 60), keys, mods);  //EDIT name

//--mappings

#[$1, $2, $3, $4, $5, $6, $7, $8, $9].do{|chr|
	kb.lookupButton(chr.toUpper.asSymbol).action= {|view|
		if(view.value==1, {
			kb.sendOsc([
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
	kb.lookupButton(chr.toUpper.asSymbol).action= {|view|
		if(view.value==1, {
			kb.sendOsc([
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
	kb.lookupButton(chr.toUpper.asSymbol).action= {|view|
		if(view.value==1, {
			kb.sendOsc([
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
	kb.lookupButton(chr.toUpper.asSymbol).action= {|view|
		if(view.value==1, {
			kb.sendOsc([
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
