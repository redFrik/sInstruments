//related SPlayFileDiskView, SPlayFile

SPlayFileDisk : AbstractSPlayFile {
	classvar id= 2222;
	var >bufferSize= 8192;  //decrease for faster frame updates, increase for disk dropout safety

	frame {
		if(voices.size>0, {
			^voices[0].frame;
		}, {
			^0;
		});
	}
	play {|path, out, amp, rate, loop, attack, curve, startFrame|
		var file= SoundFile.openRead(path.standardizePath);
		if(file.notNil, {
			if(channels.includes(file.numChannels), {
				//"%: %Ch, %Hz".format(file.path.basename, file.numChannels, file.sampleRate).postln;  //debug
				voices.do{|v|
					if(v.isStopped.not, {
						v.syn.release(0.05);
						v.isStopped= true;
					});
				};
				startFrame= startFrame?0;
				forkIfNeeded{
					var voice, buf;
					buf= Buffer.cueSoundFile(dict.server, file.path, startFrame, file.numChannels, bufferSize);
					dict.server.sync;
					voice= (
						path: file.path,
						frame: startFrame,
						buf: buf,
						isStopped: false
					);
					voice.syn= Synth((this.class.name++"_"++file.numChannels).asSymbol, [
						\buf, buf,
						\out, out??{dict.out},
						\amp, amp??{dict.amp},
						\rate, rate??{dict.rate},
						\loo, loop??{dict.loo},
						\atk, attack??{dict.atk},
						\cur, curve??{dict.cur}
					], dict.target, dict.addAction).onFree({
						doneAction.value(voice);
						voice.buf.free;
						voice.osc.free;
						voices.remove(voice);
					});
					voice.osc= OSCFunc({|msg|
						if(msg[2]==id, {voice.frame= startFrame+msg[3]%file.numFrames});
					}, '/diskin', dict.server.addr, nil, [voice.syn.nodeID]);
					voices.addFirst(voice);
				};
			}, {
				"%: % channel soundfiles not supported - see channels argument in *new".format(
					this.class.name,
					file.numChannels
				).warn;
			});
			file.close;
		}, {
			"%: soundfile % not readable".format(this.class.name, path).warn;
		});
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
