//f.olofsson & t.ungvary 2019
//for Budapest concert

SGliss : AbstractSInstrument {
	var out;  //synth
	var <voices;  //list with gliss voice instances
	*new {|maxNumVoices= 100, target, outbus= 0, addAction= \addToHead, args|
		^super.new(2, target, outbus, addAction, args)
		.initSGliss(maxNumVoices, target, outbus);
	}
	initSGliss {|maxNumVoices, target, outbus|
		target= target.asTarget;
		target.server.ifRunning({
			voices= List.new;
			out= SynthDef(\sGliss_out, {
				|outBus, atk= 0.1, rel= 1, gate= 1, vol= 0, on= 1, amp= 0|
				var onEnv= EnvGen.kr(Env.asr(atk, 1, rel), on);
				var snd= In.ar(\sGliss_bus.ir, this.numChannels);  //stereo
				var env= EnvGen.kr(Env.asr(atk, 1, rel), gate, doneAction:2);
				env= env*(onEnv+(amp.lagud(atk, rel)*(2-onEnv)));
				Out.ar(outBus, snd*env*(vol.dbamp.lag));
			}).play(grp, [\sGliss_bus, bus, \outBus, outbus]++arguments.asKeyValuePairs, \addToTail);
			controllers.add((
				frequencies: SGlissFrequencies(maxNumVoices, grp, arguments),
				amplitudes: SGlissAmplitudes(maxNumVoices, grp, arguments),
				pannings: SGlissPannings(maxNumVoices, grp, arguments)
			));
		});
	}
	release {|releaseTime= 1|
		out.release(releaseTime);
		out.onFree({this.free});
	}
	set {|...args|
		args.pairsDo{|key, val|
			arguments.put(key, val);
			grp.set(key, val);
		};
	}
	setPannings {|arr|  //convenience method
		this.set(\pannings, arr);
	}
	getPannings {
		^controllers.collect{|ctrl| ctrl.pannings.bus.getnSynchronous};
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
	getFrequencies {
		^controllers.collect{|ctrl| ctrl.frequencies.bus.getnSynchronous};
	}

	numVoices {
		^voices.size;
	}
	addVoices {|num= 1, type= \Sine, args|
		var voiceClass;
		if(controllers.notNil, {
			voiceClass= AbstractSGlissVoice.allSubclasses.detect{|c| c.type==type};
			if(voiceClass.notNil, {
				forkIfNeeded{
					num.do{|i|
						var arr;
						var freCtrl= controllers[0].frequencies;
						var ampCtrl= controllers[0].amplitudes;
						var panCtrl= controllers[0].pannings;
						if(voices.size<freCtrl.numChannels, {
							arr= [
								\sControllerFre_busChan, freCtrl.bus.index+voices.size,
								\sControllerAmp_busChan, ampCtrl.bus.index+voices.size,
								\sControllerPan_busChan, panCtrl.bus.index+voices.size,
								\sGliss_bus, bus
							];
							arguments.keysValuesDo{|key, val|
								arr= arr++key++val.asArray.wrapAt(i);
							};
							voices.add(voiceClass.new(grp, arr++args));
						}, {
							"addVoices overflow - increase numChannels".warn;
						});
					};
				};
			}, {
				"%: type % not found".format(this.class.name, type).warn;
			});
		});
	}
	removeVoices {|num= 1, action|
		num.do{|i|
			var rel= arguments.rel.asArray.wrapAt(voices.size-1);
			var voice= voices.pop;
			if(voice.notNil, {
				voice.syn.set(\rel, rel, \gate, 0);
				if(i==0, {
					voice.syn.onFree(action);
				});
			});
		};
	}
}

AbstractSGlissVoice : AbstractSVoice {
	defName {
		^("sGliss_"++this.class.type).asSymbol;
	}
	def {
		^SynthDef(this.defName, {
			|atk= 0.1, rel= 1, cur= -4, gate= 1, mul= 1, add= 0, del= 0|
			var fre= DelayN.kr(In.kr(\sControllerFre_busChan.ir)*mul+add, 10, del).max(5);
			var amp= DelayN.kr(In.kr(\sControllerAmp_busChan.ir), 10, del).lagud(atk, rel);
			var pan= In.kr(\sControllerPan_busChan.ir);
			var env= EnvGen.kr(Env.asr(atk, 1, rel, cur), gate, doneAction:2);
			var snd= SynthDef.wrap(this.func, nil, [fre, amp]);
			Out.ar(\sGliss_bus.ir, Pan2.ar(snd*env, pan, 0.1));
		});
	}
}
SGlissSaw : AbstractSGlissVoice {
	*type {^\Saw}
	func {
		^{|fre, amp|
			var snd= VarSaw.ar(fre, Rand(0, 1), LFNoise2.kr(0.1, 0.45, 0.5), AmpComp.kr(fre));
			snd*amp;
		};
	}
}
SGlissSine : AbstractSGlissVoice {
	*type {^\Sine}
	func {
		^{|fre, amp|
			SinOsc.ar(fre, Rand(0, 2pi), AmpComp.kr(fre)*1.25*amp);
		};
	}
}
SGlissSineFB : AbstractSGlissVoice {
	*type {^\SineFB}
	func {
		^{|fre, amp|
			SinOscFB.ar(fre, LFNoise2.kr(0.1).range(0.25, 0.75), AmpComp.kr(fre)*amp);
		};
	}
}
SGlissPulse : AbstractSGlissVoice {
	*type {^\Pulse}
	func {
		^{|fre, amp|
			RLPF.ar(
				LPF.ar(
					Pulse.ar(fre, LFNoise2.kr(0.1).range(0.5, 0.95), AmpComp.kr(fre)),
					9000
				),
				LFNoise2.kr(0.1).exprange(1200, 12000),
				LFNoise2.kr(0.1, 0.4, 1),
				amp
			);
		};
	}
}
SGlissPulseWarm : AbstractSGlissVoice {
	*type {^\PulseWarm}
	func {
		^{|fre, amp|
			RLPF.ar(
				Pulse.ar(fre, LFNoise2.kr(0.1).range(0.1, 0.2), AmpComp.kr(fre)),
				LFNoise2.kr(0.1).exprange(300, 1000),
				0.1,
				amp
			);
		};
	}
}
SGlissVOsc : AbstractSGlissVoice {
	*type {^\VOsc}
	func {
		^{|fre, amp|
			var buffer= {
				var num= 4.rrand(9);
				LocalBuf.newFrom(
					Env(
						[0, {0.5.rand2}!(num-1), 0].flat,
						{1.0.rand(9)}!num,
						{rand2(9.0)}!num
					).asSignal(1024).asWavetable
				)
			}.dup(3)[0];
			LeakDC.ar(
				VOsc.ar(
					buffer+LFNoise1.kr(0.1).range(0, 2),
					fre,
					Rand(0, 2pi),
					AmpComp.kr(fre)*amp
				)
			);
		};
	}
}
SGlissFormant : AbstractSGlissVoice {
	*type {^\Formant}
	func {
		^{|fre, amp|
			Formant.ar(
				fre,
				fre*IRand(1, 4),
				LFNoise2.kr(0.1).exprange(200, 1000),
				AmpComp.kr(fre)*amp*0.5
			);
		};
	}
}
SGlissKarplus : AbstractSGlissVoice {
	*type {^\Karplus}
	func {
		^{|fre, amp|
			Pluck.ar(
				PinkNoise.ar(amp),
				Dust.kr(amp*2+6),
				0.05,
				1/fre.max(20),
				8,
				LFNoise2.kr(0.1)*0.01,
				AmpComp.kr(fre)*amp*1.5
			);
		};
	}
}
SGlissNoise : AbstractSGlissVoice {
	*type {^\Noise}
	func {
		^{|fre, amp|
			RHPF.ar(
				RLPF.ar(
					WhiteNoise.ar(0.75),
					fre,
					LFNoise2.kr(0.1).exprange(0.05, 0.25),
					AmpComp.kr(fre)
				),
				fre,
				LFNoise2.kr(0.1).range(0.25, 1),
				amp
			);
		};
	}
}
SGlissPink : AbstractSGlissVoice {
	*type {^\Pink}
	func {
		^{|fre, amp|
			RHPF.ar(
				RLPF.ar(
					PinkNoise.ar(2),
					fre,
					LFNoise2.kr(0.1).exprange(0.05, 0.25),
					AmpComp.kr(fre)
				),
				fre*0.5,
				LFNoise2.kr(0.1).range(0.25, 1),
				amp
			);
		}
	}
}
SGlissFile : AbstractSGlissVoice {
	*type {^\File}
	func {
		^{|fre, amp|
			var buf= \buf.ir;
			var playbackRate= fre.explin(20, 12000, 1/3, 3);
			var rate= LinXFade2.kr(1, playbackRate, \rateBlend.kr(1));
			var pos= \pos.kr(0)%1*BufFrames.ir(buf);
			var loop= \loop.kr(1);
			var rand= Impulse.kr(1/BufDur.ir(buf)*rate*LFNoise1.kr(0.1, 0.2, 0.6), 0, 1-loop);
			PlayBuf.ar(1, buf, rate*BufRateScale.ir(buf), \trig.tr+rand, pos, loop)*amp;
		}
	}
}
SGlissFolder : AbstractSGlissVoice {
	*type {^\Folder}
	func {
		^{|fre, amp|
			var buf= \buf.kr;
			var playbackRate= fre.explin(20, 12000, 1/3, 3);
			var rate= LinXFade2.kr(1, playbackRate, \rateBlend.kr(1));
			var pos= 1.0.rand*BufFrames.ir(buf);
			PlayBuf.ar(1, buf, rate*BufRateScale.kr(buf), 1, pos, 1)*amp;
		}
	}
}

SGlissFrequencies : AbstractSController {
	def {
		^SynthDef(this.defName, {|lag= 3, lfoRate= 0.1, lfoDepth= 0, curv= -4, warp= 5|
			var freqs= \frequencies.kr(99!this.numChannels+1.0.rand2);
			var lfo= LFDNoise3.kr(lfoRate!this.numChannels, lfoDepth.lag(0.05)*0.5, 1);
			freqs= freqs.varlag(lag, curv, warp, freqs);
			Out.kr(\sController_bus.ir, freqs*lfo);
		});
	}
}
SGlissAmplitudes : AbstractSController {
	def {
		^SynthDef(this.defName, {|lag= 3, lfoRate= 0.1, lfoDepth= 0, curv= -4, warp= 5|
			var amps= \amplitudes.kr(0.5!this.numChannels);
			var min, max, lfo;
			lfoDepth= lfoDepth.lag(0.05);
			min= 1-lfoDepth;
			max= lfoDepth*0.25+1;
			lfo= LFDNoise3.kr(lfoRate!this.numChannels).range(min, max);
			amps= amps.varlag(lag, curv, warp, amps);
			Out.kr(\sController_bus.ir, amps*lfo);
		});
	}
}
SGlissPannings : AbstractSController {
	def {
		^SynthDef(this.defName, {|lag= 3, lfoRate= 0.1, lfoDepth= 0, curv= -4, warp= 5|
			var pans= \pannings.kr(0!this.numChannels);
			var lfo= LFDNoise3.kr(lfoRate!this.numChannels, lfoDepth.lag(0.05));
			pans= pans.varlag(lag, curv, warp, pans);
			Out.kr(\sController_bus.ir, pans+lfo);
		});
	}
}
