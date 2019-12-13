//a bus and synth in control rate
//subclasses should provide a def including this.defName and \sController_bus.ir

AbstractSController {
	var <syn;  //synth
	var <bus;  //control bus
	*new {|numChannels= 5, target, args|
		^super.new.initAbstractSController(numChannels, target, args);
	}
	initAbstractSController {|numChannels, target, args|
		var name;
		bus= Bus.control(target.server, numChannels);
		CmdPeriod.doOnce({bus.free});
		args= (args?()).asKeyValuePairs++[\sController_bus, bus];
		name= this.defName;
		forkIfNeeded{
			if(SynthDescLib.at(name).isNil, {
				this.def.add;
				target.server.sync;
			});
			syn= Synth(name, args, target);
		};
	}
	defName {
		^(this.class.name++bus.numChannels).asSymbol;
	}
	free {
		syn.free;
		bus.free;
		bus= nil;
	}
	numChannels {
		^bus.numChannels;
	}
	def {^this.subclassResponsibility(thisMethod)}
}
