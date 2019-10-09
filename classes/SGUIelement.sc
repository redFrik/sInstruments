//f.olofsson 2019

SGUIelement {
	//TODO optional smoothing, rounding subclasses?
	var <value, lastValue;
	var viewsSpecs, defaultSpec, lastViewValue;
	var >action;
	var softSetLastTime;
	*new {
		^super.new.initSGUIelement;
	}
	initSGUIelement {
		value= 0;
		lastViewValue= 0;
		viewsSpecs= List.new;
		defaultSpec= ControlSpec(0, 1);
		softSetLastTime= 0;
	}
	value_ {|val|
		value= val;
		if(value!=lastValue, {
			lastValue= value;
			action.value(value);
		});
	}
	valueAction_ {|val|
		value= val;
		lastValue= value;
		action.value(value);
	}
	doAction {
		action.value(value);
	}
	softSetValue {|val, within= 0.03, timeout= 1|
		if(Main.elapsedTime-softSetLastTime<timeout, {
			this.value= val;
			softSetLastTime= Main.elapsedTime;
		}, {
			if((val-value).abs<within, {
				this.value= val;
				softSetLastTime= Main.elapsedTime;
			});
		});
	}
	asView {^viewsSpecs.last[0]}
	views {^viewsSpecs.flop[0]}
	addView {|view, spec|
		spec= spec?defaultSpec;
		viewsSpecs.add([view, spec]);
		view.action= {|v|
			value= spec.unmap(v.value);
			action.value(value);
			this.prUpdate;
		};
		^view;
	}
	update {
		if(value!=lastViewValue, {
			this.prUpdate;
		});
	}
	prUpdate {
		lastViewValue= value;
		viewsSpecs.do{|vs|
			vs[0].value= vs[1].map(value);
		};
	}
}

SGUIelementRange : SGUIelement {
	initSGUIelement {
		value= [0, 1];
		lastViewValue= [0, 1];
		viewsSpecs= List.new;
		defaultSpec= ControlSpec(0, 1);
		softSetLastTime= 0;
	}
	softSetValue {|index, val, within= 0.03, timeout= 1|
		if(Main.elapsedTime-softSetLastTime<timeout, {
			this.value= value.copy.put(index, val);
			softSetLastTime= Main.elapsedTime;
		}, {
			if((val-value[index]).abs<within, {
				this.value= value.copy.put(index, val);
				softSetLastTime= Main.elapsedTime;
			});
		});
	}
	addView {|view, spec|
		spec= spec?defaultSpec;
		viewsSpecs.add([view, spec]);
		view.action= {|v|
			value= [spec.unmap(v.lo), spec.unmap(v.hi)];
			action.value(value);
			this.prUpdate;
		};
		^view;
	}
	prUpdate {
		lastViewValue= value;
		viewsSpecs.do{|vs|
			vs[0].setSpan(vs[1].map(value[0]), vs[1].map(value[1]));
		};
	}
}

SGUIelementString : SGUIelement {
	initSGUIelement {
		value= "";
		lastViewValue= "";
		viewsSpecs= List.new;
	}
	addView {|view|
		viewsSpecs.add([view, nil]);
		view.action= {|v|
			value= v;
			action.value(value);
			this.prUpdate;
		};
		^view;
	}
	prUpdate {
		lastViewValue= value;
		viewsSpecs.do{|vs|
			vs[0].string= value;
		};
	}
}
