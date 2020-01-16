//related: SPlayFile

SPlayFileView : AbstractSPlayFileView {

	init {|argSpf|

		spf= argSpf??{SPlayFileStereo()};
		spf.server.ifNotRunning({"%: boot server first".format(this.class.name).warn});
		spf.doneAction= {
			{
				playButton.value= 0;
				waveView.timeCursorPosition= 0;
			}.defer;
		};

		this.selectionColor= Color.yellow(1, 0.5);
		waveView.action= {|view|
			var start= waveView.selectionStart(0);
			var end= start+waveView.selectionSize(0);
			start= start/waveView.numFrames;
			end= end/waveView.numFrames;
			if(start==end, {end= 1});
			spf.start= start;
			spf.end= end;
		};

		cursorUpdater= Routine({
			var lastFrame= 0;
			inf.do{
				var f= spf.frame;
				if(f!=lastFrame, {
					lastFrame= f;
					waveView.timeCursorPosition= f;
				});
				(1/fps).wait;
			};
		}).play(AppClock);
	}

	selectionColor_ {|col| waveView.setSelectionColor(0, col)}

	startPlaying {
		var start= waveView.selectionStart(0);
		var end= start+waveView.selectionSize(0);
		start= start/waveView.numFrames;
		end= end/waveView.numFrames;
		if(start==end, {end= 1});
		spf.play(
			currentFilePath,
			busNumber.value,
			volumeSpec.map(volSlider.value).dbamp,
			start: start,
			end: end
		);
	}
}
