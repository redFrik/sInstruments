//an audio bus and a group together with controllers (AbstractSController) and arguments
//subclasses should call super.init first before setting up controllers and other synths

AbstractSInstrument {
	var <controllers;  //list with dictionaries
	var <arguments;  //dictionary with current arguments
	var grp;  //audio group for everything here
	var bus;  //numChannels audio bus for internal routing
	*new {|numChannels= 2, target, outbus= 0, addAction= \addToHead, args|
		^super.new.initAbstractSInstrument(numChannels, target, addAction, args);
	}
	initAbstractSInstrument {|numChannels, target, addAction, args|
		target= target.asTarget;
		target.server.ifRunning({
			controllers= List.new;
			arguments= ();
			args.pairsDo{|key, val| arguments.put(key, val)};
			grp= Group(target, addAction);
			bus= Bus.audio(target.server, numChannels.max(1));
			CmdPeriod.doOnce({bus.free});
		}, {
			"%: boot server first".format(this.class).warn;
		});
	}
	free {
		controllers.do{|dict| dict.do{|ctrl| ctrl.free}};
		grp.free;
		bus.free;
		bus= nil;
	}
	numChannels {
		^bus.numChannels;
	}
	group {
		^grp;
	}
}
