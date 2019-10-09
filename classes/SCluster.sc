//f.olofsson 2019


SCluster : AbstractSInstrument {
	var syn;
	*new {|numVoices= 4, target, outbus= 0, addAction= \addToHead, args|
		^super.new(numVoices, target, outbus, addAction, args)
		.initSCluster(numVoices, target, outbus);
	}
	initSCluster {|numVoices, target, outbus|
		var name;
		target= target.asTarget;
		target.server.ifRunning({
			forkIfNeeded{
				name= this.defName;
				if(SynthDescLib.at(name).isNil, {
					SynthDef(name, {|outBus, gate= 1, atk= 2, rel= 4, on= 1, amp= 0, vol= 0|
						var onEnv= EnvGen.kr(Env.asr(atk, 1, rel), on);
						var freqs= In.kr(\sClusterFre_bus.ir, numVoices);
						var dists= In.kr(\sClusterDist_bus.ir, numVoices);
						var amps= In.kr(\sClusterAmp_bus.ir, numVoices);
						var env= EnvGen.kr(Env.asr(atk, 1, rel), gate, doneAction:2);
						var snd= SynthDef.wrap(this.func, nil, [freqs, dists, amps]);
						snd= Splay.ar(snd, 1, vol.dbamp*0.25);  //mix to stereo
						snd= snd*numVoices.linlin(1, 50, 0, -12).dbamp;
						env= env*(onEnv+(amp.lagud(atk, rel)*(2-onEnv)));
						Out.ar(outBus, snd*env);
					}).add;
					target.server.sync;
				});
				arguments.put(\outBus, outbus);
				syn= this.prCreateSynths(name);
			};
		});
	}
	release {|releaseTime= 0.1, onFreeFunc|
		syn.release(releaseTime);
		syn.onFree({{onFreeFunc.value; this.free}.defer});
	}
	xset {|...args|
		syn.set(\gate, 0);
		args.pairsDo{|key, val|
			arguments.put(key, val);
		};
		syn= this.prCreateSynths(this.defName);
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
	setDistortions {|arr|  //convenience method
		this.set(\distortions, arr);
	}
	getDistortions {
		^controllers.collect{|ctrl| ctrl.distortions.bus.getnSynchronous};
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
		^(this.class.name++bus.numChannels).asSymbol;
	}
	*type {^\SineFB}
	func {
		^{|freqs, dists, amps|
			SinOscFB.ar(freqs, dists, amps*AmpComp.kr(freqs));
		};
	}

	//--private
	prCreateSynths {|name|
		var ctrls= (
			frequencies: SClusterFrequencies(this.numChannels, grp, arguments),
			distortions: SClusterDistortions(this.numChannels, grp, arguments),
			amplitudes: SClusterAmplitudes(this.numChannels, grp, arguments)
		);
		var args= arguments.asKeyValuePairs++[
			\sClusterFre_bus, ctrls.frequencies.bus,
			\sClusterDist_bus, ctrls.distortions.bus,
			\sClusterAmp_bus, ctrls.amplitudes.bus
		];
		controllers.add(ctrls);
		^Synth(name, args, grp).onFree({
			ctrls.do{|c| c.free};
			controllers.remove(ctrls);
		});
	}
}

SClusterSaw : SCluster {
	*type {^\Saw}
	func {
		^{|freqs, dists, amps|
			VarSaw.ar(freqs, {1.0.rand}!this.numChannels, dists*0.5+0.5, amps*AmpComp.kr(freqs));
		};
	}
}
SClusterSine : SCluster {
	*type {^\Sine}
	func {
		^{|freqs, dists, amps|
			SinOsc.ar(freqs, {2pi.rand}!this.numChannels, AmpComp.kr(freqs)*amps*(dists+1)).tanh;
		};
	}
}
SClusterPulse : SCluster {
	*type {^\Pulse}
	func {
		^{|freqs, dists, amps|
			RLPF.ar(
				LPF.ar(
					Pulse.ar(freqs, LFNoise2.kr(0.1!this.numChannels).range(0.5, 0.95), AmpComp.kr(freqs)),
					dists.linexp(0, 1, 1200, 12000)
				),
				LFNoise2.kr(0.1!this.numChannels).exprange(1200, 12000),
				LFNoise2.kr(0.1!this.numChannels, 0.4, 1),
				amps
			);
		};
	}
}
SClusterPulseWarm : SCluster {
	*type {^\PulseWarm}
	func {
		^{|freqs, dists, amps|
			var d1= dists.linlin(0, 1, 0.5, 0.05);
			var d2= dists.linlin(0, 1, 0.5, 0.3);
			RLPF.ar(
				Pulse.ar(freqs, LFNoise2.kr(0.1!this.numChannels).range(d1, d2), AmpComp.kr(freqs)),
				LFNoise2.kr(0.1!this.numChannels).exprange(300, 1000),
				0.1,
				amps*0.7
			);
		};
	}
}
SClusterFormant : SCluster {
	*type {^\Formant}
	func {
		^{|freqs, dists, amps|
			Formant.ar(
				freqs,
				freqs*(dists*3+1),
				LFNoise2.kr(0.1!this.numChannels).exprange(200, 1000),
				AmpComp.kr(freqs)*amps*0.5
			);
		};
	}
}
SClusterKarplus : SCluster {
	*type {^\Karplus}
	func {
		^{|freqs, dists, amps|
			Pluck.ar(
				PinkNoise.ar(amps),
				Dust.kr(amps*2+6),
				0.05,
				1/freqs.max(20),
				2+(dists*6),
				LFNoise2.kr(0.1)*(dists*0.2+0.01),
				AmpComp.kr(freqs)*amps
			);
		};
	}
}
SClusterNoise : SCluster {
	*type {^\Noise}
	func {
		^{|freqs, dists, amps|
			RHPF.ar(
				RLPF.ar(
					WhiteNoise.ar(0.75!this.numChannels),
					freqs,
					dists.linexp(0, 1, 1, 0.01),
					AmpComp.kr(freqs)*dists.linlin(0, 1, 1.5, 1)
				),
				freqs,
				LFNoise2.kr(0.1!this.numChannels, dists).range(0.25, 1),
				amps
			);
		};
	}
}
SClusterPink : SCluster {
	*type {^\Pink}
	func {
		^{|freqs, dists, amps|
			RHPF.ar(
				RLPF.ar(
					PinkNoise.ar(2!this.numChannels),
					freqs,
					dists.linexp(0, 1, 1, 0.01),
					AmpComp.kr(freqs)*dists.linlin(0, 1, 1.5, 1)
				),
				freqs*0.5,
				LFNoise2.kr(0.1!this.numChannels, dists).range(0.25, 2),
				amps
			);
		}
	}
}
SClusterFile : SCluster {
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
}
SClusterFolder : SCluster {
	*type {^\Folder}
	func {
		^{|freqs, dists, amps|
			var buf= \buf.kr;
			var playbackRate= freqs.explin(20, 12000, 1/3, 3);
			var rate= LinXFade2.kr(1, playbackRate, \rateBlend.kr(1));
			(
				PlayBuf.ar(1, buf, rate*BufRateScale.kr(buf), 1, 0, 1)
				*(dists*5+1)
			).tanh*amps*(1-(dists*0.5));
		}
	}
}

SClusterFrequencies : AbstractSController {
	def {
		^SynthDef(this.defName, {|lag= 1, curv= -4, warp= 5, fLfoRate= 0.1, fLfoDepth= 0|
			var freqs= \frequencies.kr(99!this.numChannels+1.0.rand2);
			var lfo= LFDNoise3.kr(fLfoRate!this.numChannels, fLfoDepth.lag(0.05)/3, 1);
			freqs= freqs.varlag(lag, curv, warp, freqs);
			Out.kr(\sController_bus.ir, freqs*lfo);
		});
	}
}
SClusterDistortions : AbstractSController {
	def {
		^SynthDef(this.defName, {|lag= 1, curv= -4, warp= 5|
			var dists= \distortions.kr(0!this.numChannels);
			dists= dists.varlag(lag, curv, warp, dists);
			Out.kr(\sController_bus.ir, dists.clip(0, 1));
		});
	}
}
SClusterAmplitudes : AbstractSController {
	def {
		^SynthDef(this.defName, {|lag= 1, curv= -4, warp= 5, aLfoRate= 0.1, aLfoDepth= 0|
			var amps= \amplitudes.kr(0.25!this.numChannels);
			var lfo= LFDNoise3.kr(aLfoRate!this.numChannels, aLfoDepth.lag(0.05)/3);
			amps= amps.varlag(lag, curv, warp, amps);
			Out.kr(\sController_bus.ir, (amps+lfo).max(0));
		});
	}
}
