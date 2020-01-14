//related: SPlayFileDisk, SPlayFileView

SPlayFileDiskView : AbstractSPlayFileView {

	init {|argSpf|

		spf= argSpf??{SPlayFileDiskStereo()};
		spf.server.ifNotRunning({"%: boot server first".format(this.class.name).warn});
		spf.doneAction= {
			{
				playButton.value= 0;
				waveView.timeCursorPosition= 0;
			}.defer;
		};

		waveView.setSelectionColor(0, Color.clear);

		cursorUpdater= Routine({
			var lastFrame= 0;
			inf.do{
				var f= spf.frame;
				if(f!=lastFrame, {
					lastFrame= f;
					waveView.timeCursorPosition= f;
				});
				0.01.wait;
			};
		}).play(AppClock);
	}

	startPlaying {
		spf.play(
			currentFilePath,
			busNumber.value,
			volumeSpec.map(volSlider.value).dbamp,
			startFrame: waveView.timeCursorPosition
		);
	}
}
