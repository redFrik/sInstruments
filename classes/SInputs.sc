//f.olofsson 2019

SInputs {
	classvar <destinations;

	*initClass {
		destinations= (
			sGliss: NetAddr("127.0.0.1", 13060),
			sDrone: NetAddr("127.0.0.1", 13061),
			sFormant: NetAddr("127.0.0.1", 13063),
			sCluster: NetAddr("127.0.0.1", 13064),
			sStream: NetAddr("127.0.0.1", 13065),
			sSentograph: NetAddr("127.0.0.1", 12000),  //from python optoforce
			sGreybox: NetAddr("127.0.0.1", 12001),  //to leds
			sQWERTYKeyboard: NetAddr("127.0.0.1", 12002)  //from python hid
		);
	}
}
