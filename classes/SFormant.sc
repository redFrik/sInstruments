//f.olofsson 2019
//based on optoformant3

SFormant : AbstractSInstrument {
	var syn, out;  //synths
	*new {|target, outbus= 0, addAction= \addToHead, args|
		^super.new(2, target, outbus, addAction, args)
		.initSFormant(target, outbus);
	}
	initSFormant {|target, outbus|
		target= target.asTarget;
		target.server.ifRunning({
			forkIfNeeded{
				SynthDef(\sFormant_syn, {|gate= 1, atk= 4, rel= 4, vol= 0, on= 1,
					x= 0, y= 0, yScale= 1, fundOffset= 50, formOffset= 50,
					lagUp= 0.001, lagDown= 0.01, detune= 0, pan= 0, ampAdd= 0|
					var voicesDiff, fundFreq, formFreq, bwFreq;
					var onEnv= EnvGen.kr(Env.asr(atk, 1, rel), on);
					var freqs= In.kr(\sFormantFre_bus.ir, this.numChannels);
					var amps= In.kr(\sFormantAmp_bus.ir, this.numChannels)+ampAdd.lag(0.01)*onEnv;
					var env= EnvGen.kr(Env.asr(atk, 0.6, rel), gate, doneAction:2);
					var snd;
					y= y*yScale;
					voicesDiff= [1, 1.5+LFNoise2.kr(0.01, 0.1)+detune];
					fundFreq= freqs[0].lagud(lagUp, lagDown)*voicesDiff+fundOffset.lag(0.1);
					formFreq= (freqs[1]*yScale)*voicesDiff+formOffset.lag(0.1);
					bwFreq= freqs[0].lag+(freqs[1]*yScale).lag(3);
					snd= Formant.ar(fundFreq, formFreq, bwFreq.max(fundFreq));
					snd= Mix(snd*amps)*vol.dbamp.lag*0.25;
					snd= snd+AllpassC.ar(
						snd,
						0.1,
						(x/#[400, -400]).clip(-1, 1).linexp(-1, 1, 0.01, 0.1),
						9,
						(y/200-0.20).max(0).lag*0.5
					).tanh;
					snd= Balance2.ar(snd[0], snd[1], pan.lag(0.01));
					Out.ar(\sFormant_bus.ir, snd*env);
				}).add;
				SynthDef(\sFormant_out, {|outBus, verb= 0, gate= 1|
					var snd= In.ar(\sFormant_bus.ir, this.numChannels);
					snd= snd+GVerb.ar(Mix(snd), 99, mul:verb.lag(0.1));
					snd= LeakDC.ar(snd);
					FreeSelf.kr(DetectSilence.ar(snd).product*(1-gate));
					Out.ar(outBus, snd);
				}).add;
				target.server.sync;
				out= Synth(\sFormant_out, [\sFormant_bus, bus, \outBus, outbus], grp);
				syn= this.prCreateSynths;
			};
		});
	}
	release {|releaseTime= 0.1, onFreeFunc|
		syn.release(releaseTime);
		out.set(\gate, 0);
		out.onFree({onFreeFunc.value; this.free});
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

	//--private
	prCreateSynths {
		var ctrls= (
			frequencies: SFormantFrequencies(this.numChannels, grp, arguments),
			amplitudes: SFormantAmplitudes(this.numChannels, grp, arguments)
		);
		var args= arguments.asKeyValuePairs++[
			\sFormantFre_bus, ctrls.frequencies.bus,
			\sFormantAmp_bus, ctrls.amplitudes.bus,
			\sFormant_bus, bus
		];
		controllers.add(ctrls);
		^Synth(\sFormant_syn, args, grp).onFree({
			ctrls.do{|c| c.free};
			controllers.remove(ctrls);
		});
	}
}

SFormantFrequencies : AbstractSController {
	def {
		^SynthDef(this.defName, {
			var freqs= \frequencies.kr(50!this.numChannels);
			Out.kr(\sController_bus.ir, freqs);
		});
	}
}
SFormantAmplitudes : AbstractSController {
	def {
		^SynthDef(this.defName, {|lag= 0.01|
			var amps= \amplitudes.kr(0.5!this.numChannels);
			amps= amps.lag(lag);
			Out.kr(\sController_bus.ir, amps);
		});
	}
}
