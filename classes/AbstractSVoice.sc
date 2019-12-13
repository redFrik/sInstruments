//a synthdef and synth in audio rate

AbstractSVoice {
	var <syn;
	*new {|grp, args|
		^super.new.initAbstractSVoice(grp, args);
	}
	initAbstractSVoice {|grp, args|
		var name= this.defName;
		forkIfNeeded{
			if(SynthDescLib.at(name).isNil, {
				this.def.add;
				grp.server.sync;
			});
			syn= Synth(name, args, grp);
		};
	}
	*type {^this.subclassResponsibility(thisMethod)}  //also synthdef name
	*defName {^this.subclassResponsibility(thisMethod)}  //a symbol
	func {^this.subclassResponsibility(thisMethod)}  //sound function
}
