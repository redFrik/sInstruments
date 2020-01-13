//f.olofsson 2020
//for playing soundfiles from disk or from memory (ram)

//implement start end selection
//TODO finish helpfiles
//TODO test on linux headless
//TODO improve quad playback
//TODO crossfade when looping

//related SPlayFile, SPlayFileDisk

AbstractSPlayFile {
	var dict, channels;
	var <voices;
	var >doneAction;
	*new {|target, addAction= \addToHead, channels= #[1, 2, 4]|
		^super.new.initAbstractSPlayFile(target, addAction, channels);
	}
	initAbstractSPlayFile {|argTarget, argAddAction, argChannels|
		voices= List.new;
		channels= argChannels;
		dict= (
			target: argTarget.asTarget,
			server: argTarget.asTarget.server,
			addAction: argAddAction,
			out: 0,
			amp: 1,
			rate: 1,
			loo: 0,
			atk: 0.01,
			rel: 0.05,
			cur: -4
		);
		dict.server.ifRunning({
			this.prCreateSynthDefs;
		}, {
			dict.server.onBootAdd({this.prCreateSynthDefs});
		});
	}
	frame {
		^this.subclassResponsibility(thisMethod);
	}
	play {|path, out, amp, rate, loop, attack, curve|
		^this.subclassResponsibility(thisMethod);
	}
	stop {|release, curve|
		voices.do{|v|
			if(v.isStopped.not, {
				release= release??{dict.rel};
				curve= curve??{dict.cur};
				v.syn.set(\rel, release, \cur, curve, \gate, 0);
				v.isStopped= true;
			});
		};
	}

	set {|key, val|
		dict.put(key, val);
		voices.do{|v| v.syn.set(key, val)};
	}
	free {
		voices.do{|v| v.syn.free};
	}
	server {
		^dict.server;
	}

	atk_ {|val= 0.01| this.set(\atk, val)}
	rel_ {|val= 0.05| this.set(\rel, val)}
	out_ {|val= 0| this.set(\out, val)}
	amp_ {|val= 1| this.set(\amp, val)}
	rate_ {|val= 1| this.set(\rate, val)}
	loop_ {|val= 1| this.set(\loo, val)}

	//--private
	prCreateSynthDefs {
		^this.subclassResponsibility(thisMethod);
	}
	prMix {
		^{|snd| Mix.ar(snd)};
	}
}
