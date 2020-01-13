//related SPlayFileView, SPlayFileDisk

SPlayFile : AbstractSPlayFile {
	var <maxNumInactiveBuffers= 10;
	var <buffers;

	*new {|target, addAction= \addToHead, channels= #[1, 2, 4]|
		^super.new(target, addAction, channels).initSPlayFile;
	}
	initSPlayFile {
		buffers= List.new;
		dict.put(\start, 0);
		dict.put(\end, 1);
		dict.put(\lag, 0.25);
	}

	frame {
		if(voices.size>0, {
			^voices[0].bus.getSynchronous.min(1)*voices[0].buf.numFrames;
		}, {
			^0;
		});
	}
	play {|path, out, amp, rate, loop, attack, curve, start, end, lag|
		forkIfNeeded{
			var voice, buf;
			path= path.standardizePath;
			buf= this.findBuffer(path);
			if(buf.isNil, {  //check that not already available in buffers list
				buf= this.read(path);
				dict.server.sync;
			}, {
				buffers.add(buffers.remove(buf));
			});
			if(buf.notNil, {  //check that not failed to read
				voices.do{|v|
					if(v.isStopped.not, {
						v.syn.release(0.05);
						v.isStopped= true;
					});
				};
				voice= (
					path: path,
					bus: Bus.control(dict.server),
					buf: buf,
					isStopped: false
				);
				voice.syn= Synth((this.class.name++"_"++buf.numChannels).asSymbol, [
					\buf, buf,
					\out, out??{dict.out},
					\amp, amp??{dict.amp},
					\rate, rate??{dict.rate},
					\loo, loop??{dict.loo},
					\atk, attack??{dict.atk},
					\cur, curve??{dict.cur},
					\start, start??{dict.start},
					\end, end??{dict.end},
					\lag, lag??{dict.lag},
					\bus, voice.bus
				], dict.target, dict.addAction).onFree({
					doneAction.value(voice);
					voice.bus.free;
					voices.remove(voice);
				});
				voices.addFirst(voice);
			});
		};
	}

	start_ {|val= 0| this.set(\start, val)}
	end_ {|val= 1| this.set(\end, val)}
	lag_ {|val= 0.25| this.set(\lag, val)}

	findBuffer {|path|
		^buffers.detect{|b| b.path==path};
	}
	read {|path|
		var buffer;
		var file= SoundFile.openRead(path.standardizePath);
		if(file.notNil, {
			if(channels.includes(file.numChannels), {
				//"%: %Ch, %Hz".format(file.path.basename, file.numChannels, file.sampleRate).postln;  //debug
				buffer= Buffer.read(dict.server, file.path);
				buffers.add(buffer);
				if(buffers.size>maxNumInactiveBuffers, {
					(buffers.size-maxNumInactiveBuffers).do{
						if(voices.any{|v| v.buf==buffers[0]}.not, {  //check that not playing
							buffers.removeAt(0).free;
						});
					};
				});
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
		^buffer;  //returns nil if failed
	}

	free {
		voices.do{|v| v.syn.free};
		buffers.do{|b| b.free};
	}

	//--private
	prCreateSynthDefs {
		channels.do{|n|
			SynthDef((this.class.name++"_"++n).asSymbol, {|out= 0, buf, gate= 1,
				amp= 1, rate= 1, loo= 0, atk= 0.01, rel= 0.05, cur= -4,
				start= 0, end= 1, lag= 0.25, bus|
				var env= EnvGen.kr(Env.asr(atk, 1, rel, cur), gate, doneAction:2);
				var dur= BufFrames.ir(buf)*BufRateScale.ir(buf);
				var diff= (end-start).lag2(lag).max(LFNoise2.kr(0.05).range(0.01, 0.02));
				var pha= Phasor.ar(0, rate/dur/diff, 0, 1);
				var pos= pha*diff+start.lag2(lag);
				var snd= BufRd.ar(n, buf, pos*dur, loo);
				var mix= SynthDef.wrap(this.prMix, nil, [snd]);
				FreeSelf.kr(T2K.kr(HPZ1.ar(pos)<0)*(1-loo));
				Out.kr(bus, pos);
				Out.ar(out, mix*amp.lag*env);
			}).add;
		};
	}
}
SPlayFileStereo : SPlayFile {
	prMix {
		^{|snd| Splay.ar(snd)};
	}
}
SPlayFileQuad : SPlayFile {
	prMix {
		^{|snd| SplayAz.ar(4, snd, width:2)};  //TODO low 3+4 does not work?
	}
}
