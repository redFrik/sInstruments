SGUIicons {
	*drawCog {|size= 22, numCogs= 7, lineWidth= 1, innerRad= 0.25,
		outerRadA= 0.75, outerRadB= 0.5,
		outerTeethAA= -0.1, outerTeethAB= 0.1,
		outerTeethBA= -0.1, outerTeethBB= 0.1|
		var points= [
			Point(size*0.5*outerRadA, size*pi/numCogs*outerTeethAA),
			Point(size*0.5*outerRadA, size*pi/numCogs*outerTeethAB),
			Point(size*0.5*outerRadB, size*pi/numCogs*outerTeethBA),
			Point(size*0.5*outerRadB, size*pi/numCogs*outerTeethAB)
		];
		Pen.width= lineWidth;
		Pen.translate(size*0.5, size*0.5);
		Pen.strokeOval(Rect.aboutPoint(Point(0, 0), size*0.5*innerRad, size*0.5*innerRad));
		numCogs.do{|i|
			Pen.moveTo(points[0]);
			Pen.lineTo(points[1]);
			points= points.collect{|p| p.rotate(pi/numCogs)};
			Pen.lineTo(points[2]);
			Pen.lineTo(points[3]);
			points= points.collect{|p| p.rotate(pi/numCogs)};
			Pen.lineTo(points[0]);
			Pen.lineTo(points[1]);
			Pen.stroke;
		};
	}
}
