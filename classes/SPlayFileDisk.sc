//f.olofsson 2020

//TODO finish helpfiles
//TODO test on linux headless
//TODO improve quad playback
//TODO crossfade when looping

//related SPlayFileDiskView

SPlayFileDisk {
	classvar id= 2222;
	var <frame= 0;
	var >bufferSize= 8192;  //decrease for faster frame updates, increase for disk dropout safety
	var >doneAction;
	var dict, channels;
	*new {|target, addAction= \addToHead, channels= #[1, 2, 4]|
		^super.new.initSPlayFileDisk(target, addAction, channels);
	}
	initSPlayFileDisk {|argTarget, argAddAction, argChannels|
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
	play {|path, startFrame, out, amp, rate, loop, attack, curve|
		var file;
		path= path.standardizePath;
		file= SoundFile.openRead(path);
		if(file.notNil, {
			if(channels.includes(file.numChannels), {
				//"%: %Ch, %Hz".format(path.basename, file.numChannels, file.sampleRate).postln;  //debug
				startFrame= startFrame?0;
				dict.syn.release(0.01);
				forkIfNeeded{
					var buffer, osc;
					buffer= Buffer.cueSoundFile(dict.server, path, startFrame, file.numChannels, bufferSize);
					dict.server.sync;
					dict.syn= Synth((this.class.name++"_"++file.numChannels).asSymbol, [
						\buf, buffer,
						\out, out??{dict.out},
						\amp, amp??{dict.amp},
						\rate, rate??{dict.rate},
						\loo, loop??{dict.loo},
						\atk, attack??{dict.atk},
						\cur, curve??{dict.cur}
					], dict.target, dict.addAction).onFree({
						buffer.free;
						osc.free;
						doneAction.value(path, dict.syn.nodeID);
						dict.syn= nil;
					});
					osc= OSCFunc({|msg|
						if(msg[2]==id, {frame= startFrame+msg[3]});
					}, '/diskin', dict.server.addr, nil, [dict.syn.nodeID]);
				};
			}, {
				"%: files with % channels not supported".format(this.class.name, file.numChannels).warn;
			});
			file.close;
		}, {
			"%s: soundfile % not readable".format(this.class.name, path.basename).warn;
		});
	}
	stop {|release, curve|
		release= release??{dict.rel};
		curve= curve??{dict.cur};
		dict.syn.set(\rel, release, \cur, curve, \gate, 0);
	}
	set {|key, val|
		dict.put(key, val);
		dict.syn.set(key, val);
	}
	atk_ {|val= 0.01| this.set(\atk, val)}
	rel_ {|val= 0.05| this.set(\rel, val)}
	out_ {|val= 0| this.set(\out, val)}
	amp_ {|val= 1| this.set(\amp, val)}
	rate_ {|val= 1| this.set(\rate, val)}
	loop_ {|val= 1| this.set(\loo, val)}
	server {^dict.server}
	free {
		dict.syn.free;
	}

	//--private
	prCreateSynthDefs {
		channels.do{|n|
			SynthDef((this.class.name++"_"++n).asSymbol, {|out= 0, buf, gate= 1,
				amp= 1, rate= 1, loo= 0, atk= 0.01, rel= 0.05, cur= -4|
				var env= EnvGen.kr(Env.asr(atk, 1, rel, cur), gate, doneAction:2);
				var snd= VDiskIn.ar(n, buf, rate*BufRateScale.ir(buf), loo, id);
				var mix= SynthDef.wrap(this.prMix, nil, [snd]);
				FreeSelfWhenDone.kr(snd);
				Out.ar(out, mix*amp.lag*env);
			}).add;
		};
	}
	prMix {
		^{|snd| Mix.ar(snd)};
	}
}
SPlayFileDiskStereo : SPlayFileDisk {
	prMix {
		^{|snd| Splay.ar(snd)};
	}
}
SPlayFileDiskQuad : SPlayFileDisk {
	prMix {
		^{|snd| SplayAz.ar(4, snd, width:2)};  //TODO low 3+4 does not work?
	}
}
