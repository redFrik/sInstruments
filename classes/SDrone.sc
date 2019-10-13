//f.olofsson 2019
//based on the Ndef i used for 'Strange Foreign Bodies'

SDrone : AbstractSInstrument {
	var syn, efx;  //synths
	*new {|numVoices= 5, target, outbus= 0, addAction= \addToHead, args|
		^super.new(numVoices, target, outbus, addAction, args)
		.initSDrone(numVoices, target, outbus);
	}
	initSDrone {|numVoices, target, outbus|
		target= target.asTarget;
		target.server.ifRunning({
			forkIfNeeded{
				SynthDef(\sDrone_syn, {
					|lag= 6, gate= 1, atk= 4, rel= 4, dist= 0, on= 1, amp= 0|
					var onEnv= EnvGen.kr(Env.asr(atk, 1, rel), on);
					var freqs= In.kr(\sDroneFre_bus.ir, numVoices);
					var amps= In.kr(\sDroneAmp_bus.ir, numVoices);
					var env= EnvGen.kr(Env.asr(atk, 1, rel), gate, doneAction:2);
					var snd= SynthDef.wrap(this.func, nil, [freqs, dist.lag(lag), amps]);
					env= env*(onEnv+(amp.lagud(atk, rel)*(2-onEnv)));
					Out.ar(\sDrone_bus.ir, snd*env);
				}).add;
				SynthDef(\sDrone_efx, {|outBus, lag= 6, gate= 1,
					hp= 9, lp= 15000, dmin= 0.495, dmax= 0.5, dec= 10, vol= 0|
					var rates= 1/((1..numVoices.max(2))*10+70);
					var snd= In.ar(\sDrone_bus.ir, numVoices)*gate;
					var del= SinOsc.ar(rates).range(dmin.lag(lag), dmax.lag(lag));
					var delMix= EnvGen.kr(Env(#[0, 0, 1], [dmax, dmax]));
					hp= hp.lag2(lag);
					lp= lp.lag2(lag);
					snd= SynthDef.wrap(this.mix, nil, [snd]);
					snd= HPF.ar(snd, hp);
					snd= AllpassC.ar(snd, 1, Splay.ar(del.lag(lag)), dec.lag(lag), delMix);
					snd= LPF.ar(snd, lp, vol.dbamp.lag*0.5);
					if(numVoices<2, {snd= snd* -1.5.dbamp});  //special case if mono
					snd= LeakDC.ar(snd);
					DetectSilence.ar(snd.abs.sum+gate, doneAction:2);
					Out.ar(outBus, snd.tanh);
				}).add;
				target.server.sync;
				efx= Synth(\sDrone_efx, arguments.asKeyValuePairs++[\sDrone_bus, bus, \outBus, outbus], grp);
				syn= this.prCreateSynths;
			};
		});
	}
	release {|releaseTime= 0.1, onFreeFunc|
		syn.release(releaseTime);
		efx.set(\gate, 0);
		efx.onFree({onFreeFunc.value; this.free});
	}
	xset {|...args|
		syn.set(\gate, 0);
		args.pairsDo{|key, val|
			arguments.put(key, val);
		};
		syn= this.prCreateSynths;
	}
	set {|...args|
		args.pairsDo{|key, val|
			arguments.put(key, val);
			grp.set(key, val);
		};
	}
	setAmplitudes {|arr|  //convenience method
		this.set(\amplitudes, arr);
	}
	getAmplitudes {
		^controllers.collect{|ctrl| ctrl.amplitudes.bus.getnSynchronous};
	}
	setFrequencies {|arr|  //convenience method
		this.set(\frequencies, arr);
	}
	xsetFrequencies {|arr|  //convenience method
		this.xset(\frequencies, arr);
	}
	getFrequencies {
		^controllers.collect{|ctrl| ctrl.frequencies.bus.getnSynchronous};
	}

	defName {
		^this.class.name.asSymbol;
	}
	*type {^\SineFB}
	func {
		^{|freqs, dists, amps|
			SinOscFB.ar(freqs, dists, amps);
		};
	}
	mix {
		^{|snd|
			reduce(snd.asArray, \hypot);
		};
	}

	//--private
	prCreateSynths {
		var ctrls= (
			frequencies: SDroneFrequencies(this.numChannels, grp, arguments),
			amplitudes: SDroneAmplitudes(this.numChannels, grp, arguments)
		);
		var args= arguments.asKeyValuePairs++[
			\sDroneFre_bus, ctrls.frequencies.bus,
			\sDroneAmp_bus, ctrls.amplitudes.bus,
			\sDrone_bus, bus
		];
		controllers.add(ctrls);
		^Synth(\sDrone_syn, args, grp).onFree({
			ctrls.do{|c| c.free};
			controllers.remove(ctrls);
		});
	}
}

SDroneSaw : SDrone {
	*type {^\Saw}
	func {
		^{|freqs, dists, amps|
			VarSaw.ar(freqs, {1.0.rand}!this.numChannels, dists*0.5+0.5, amps);
		};
	}
}
SDroneSine : SDrone {
	*type {^\Sine}
	func {
		^{|freqs, dists, amps|
			SinOsc.ar(freqs, {|i| sin(i)}!this.numChannels, dists*2+1).tanh*amps;
		};
	}
	mix {
		^{|snd|
			Mix(snd)*0.5;
		};
	}
}
SDronePulse : SDrone {
	*type {^\Pulse}
	func {
		^{|freqs, dists, amps|
			RLPF.ar(
				LPF.ar(
					Pulse.ar(freqs, LFNoise2.kr(0.1!this.numChannels).range(0.5, 0.95)),
					dists.linexp(0, 1, 1200, 12000)
				),
				LFNoise2.kr(0.1!this.numChannels).exprange(1200, 12000),
				LFNoise2.kr(0.1!this.numChannels, 0.4, 1),
				amps
			);
		};
	}
	mix {
		^{|snd|
			Mix(snd)*0.5;
		};
	}
}
SDronePulseWarm : SDrone {
	*type {^\PulseWarm}
	func {
		^{|freqs, dists, amps|
			var d1= dists.linlin(0, 1, 0.5, 0.05);
			var d2= dists.linlin(0, 1, 0.5, 0.3);
			RLPF.ar(
				Pulse.ar(freqs, LFNoise2.kr(0.1!this.numChannels).range(d1, d2)),
				LFNoise2.kr(0.1!this.numChannels).exprange(300, 1000),
				0.1,
				amps
			);
		};
	}
	mix {
		^{|snd|
			Mix(snd)*0.25;
		};
	}
}
SDroneFormant : SDrone {
	*type {^\Formant}
	func {
		^{|freqs, dists, amps|
			Formant.ar(
				freqs,
				freqs*(dists*3+1),
				LFNoise2.kr(0.1!this.numChannels).exprange(200, 1000),
				amps*0.5
			);
		};
	}
	mix {
		^{|snd|
			Mix(snd)*0.5;
		};
	}
}
SDroneKarplus : SDrone {
	*type {^\Karplus}
	func {
		^{|freqs, dists, amps|
			Pluck.ar(
				PinkNoise.ar(amps),
				Dust.kr(amps*2+6),
				0.05,
				1/freqs.max(20),
				2+(dists*6),
				LFNoise2.kr(0.1!this.numChannels)*(dists*0.2+0.01),
				amps*1.5
			);
		};
	}
	mix {
		^{|snd|
			Mix(snd);
		};
	}
}
SDroneNoise : SDrone {
	*type {^\Noise}
	func {
		^{|freqs, dists, amps|
			RHPF.ar(
				RLPF.ar(
					WhiteNoise.ar(0.75!this.numChannels),
					freqs,
					dists.linexp(0, 1, 1, 0.01),
					dists.linlin(0, 1, 1.5, 1)
				),
				freqs,
				LFNoise2.kr(0.1!this.numChannels, dists).range(0.25, 1),
				amps
			);
		};
	}
	mix {
		^{|snd|
			Mix(snd)*0.5;
		};
	}
}
SDroneNoise2 : SDroneNoise {
	*type {^\Noise2}
	mix {
		^{|snd|
			reduce(snd.asArray, \hypot);
		};
	}
}
SDronePink : SDrone {
	*type {^\Pink}
	func {
		^{|freqs, dists, amps|
			RHPF.ar(
				RLPF.ar(
					PinkNoise.ar(2!this.numChannels),
					freqs,
					dists.linexp(0, 1, 1, 0.01),
					dists.linlin(0, 1, 1.5, 1)
				),
				freqs*0.5,
				LFNoise2.kr(0.1!this.numChannels, dists).range(0.25, 2),
				amps
			);
		}
	}
	mix {
		^{|snd|
			Mix(snd)*0.5;
		};
	}
}
SDronePink2 : SDronePink {
	*type {^\Pink2}
	mix {
		^{|snd|
			reduce(snd.asArray, \hypot);
		};
	}
}
SDroneFile : SDrone {
	*type {^\File}
	func {
		^{|freqs, dists, amps|
			var buf= \buf.ir;
			var playbackRate= freqs.explin(20, 12000, 1/3, 3);
			var rate= LinXFade2.kr(1, playbackRate, \rateBlend.kr(1));
			var pos= \pos.kr({1.0.rand}!this.numChannels)%1*BufFrames.ir(buf);
			var loop= \loop.kr(1);
			var rand= Impulse.kr(1/BufDur.ir(buf)*rate*LFNoise1.kr(0.1, 0.2, 0.6), 0, 1-loop);
			(
				PlayBuf.ar(1, buf, rate*BufRateScale.ir(buf), \trig.tr+rand, pos, loop)
				*(dists*5+1)
			).tanh*amps*(1-(dists*0.5));
		}
	}
	mix {
		^{|snd|
			Mix(snd)*0.5;
		};
	}
}
SDroneFolder : SDrone {
	*type {^\Folder}
	func {
		^{|freqs, dists, amps|
			var buf= \buf.kr;
			var playbackRate= freqs.explin(20, 12000, 1/3, 3);
			var rate= LinXFade2.kr(1, playbackRate, \rateBlend.kr(1));
			var pos= {1.0.rand}!this.numChannels*BufFrames.ir(buf);
			(
				PlayBuf.ar(1, buf, rate*BufRateScale.kr(buf), 1, pos, 1)
				*(dists*5+1)
			).tanh*amps*(1-(dists*0.5));
		}
	}
	mix {
		^{|snd|
			Mix(snd)*0.5;
		};
	}
}

SDroneFrequencies : AbstractSController {
	def {
		^SynthDef(this.defName, {|lag= 3,
			fmod= 50, fmul= 0.1, famp= 0, flag= 0, curv= 0, warp= 4|
			var rates= (1..this.numChannels)*fmul.lag(lag);
			var freqs= \frequencies.kr(99!this.numChannels+1.0.rand2);
			var mods= SinOsc.ar(fmod.lag(lag)+rates, Rand(0, 2pi), famp, 1);
			freqs= freqs.varlag(flag, curv, warp, freqs);
			freqs= freqs*mods;
			Out.kr(\sController_bus.ir, freqs);
		});
	}
}
SDroneAmplitudes : AbstractSController {
	def {
		^SynthDef(this.defName, {|
			rate= 0.01, min= 0.95, atk= 0.1, rel= 0.1|
			var rates= (this.numChannels..1).wrap(1, 5.1)+4;
			var amps= \amplitudes.kr(0.25!this.numChannels);
			var mods= SinOsc.ar(rate/rates, Rand(0, 2pi)).range(min, 1);
			amps= amps*mods;
			amps= amps.lagud(atk, rel);
			Out.kr(\sController_bus.ir, amps);
		});
	}
}
