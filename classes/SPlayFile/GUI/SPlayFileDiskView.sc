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
			var lastTime= 0;
			var timeDiff= 0;
			inf.do{
				var f= spf.frame;
				var percentage;
				if(f>0, {
					if(f!=lastFrame, {
						lastFrame= f;
						timeDiff= spf.bufferSize/spf.server.sampleRate;
						lastTime= Main.elapsedTime;
					}, {
						percentage= Main.elapsedTime.linlin(lastTime, lastTime+timeDiff, 0, 1);
						f= lastFrame+(spf.bufferSize*percentage);
					});
					waveView.timeCursorPosition= f;
				}, {
					if(lastFrame!=0, {
						waveView.timeCursorPosition= f;
						lastFrame= 0;
					});
				});
				(1/fps).wait;
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
