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
			sFiles: NetAddr("127.0.0.1", 13066),
			sStretch: NetAddr("127.0.0.1", 13067),

			sSentograph: NetAddr("127.0.0.1", 12000),  //from python optoforce
			sGreybox: NetAddr("127.0.0.1", 12001),  //to leds
			sQWERTYKeyboard: NetAddr("127.0.0.1", 12002),  //from python hid
			sQWERTYKeyboard2: NetAddr("127.0.0.1", 12003),  //from python hid

			sKeyDpad: NetAddr("127.0.0.1", 14000),  //to remember which are playing (on)

			sOBS: NetAddr("127.0.0.1", 3333),  //for switching scenes while videostreaming (OSC-for-OBS)
		);
	}
}
