
//STEPS
//1: scale image to about 1k dimension
//2: use weka segmentation to identify the ruler
//3: enable Feret's diameter in analyze->set measurements
//4: run analyze particles with display results && size about 300 to infinity
//5: get feret from result
//6: select analyze->setscale, set distance in pixels to feret
//		set known distance to irl distance, and units to mm

//Notes: 
// - scaling image down is need so weka runs faster/doesn't crash imagej
// - Feret's diameter is the largest distance between 2 points.
//	  On a ruler this will always be it's diagonal a known/measurable distance

///////////////////////////////////////////////////////////////////////////////////

#@ File (label="Select a classifier for ruler", description="Select the Weka model to apply") classifierRuler
#@ File (label="Select a image", style="file") inputImage

main();

rulerDiagonalMM = 170;

function main(){
	open(inputImage);
	original = getImageID();
	
	//change depending on image size
	run("Scale...", "x=0.25 y=0.25 width=1152 height=864 interpolation=Bilinear average create");
	scaledDown = getImageID();
	close(original);
	
	classified = getThesholdFromClassifier(scaledDown);
	selectImage(classified);
	
	run("Set Measurements...", "area centroid center perimeter bounding fit shape feret's skewness limit display add redirect=None decimal=3");
	run("Analyze Particles...", "size=1500-Infinity show=Masks display overlay");
	
	diagonal = getResult("Feret", 0);
	run("Set Scale...", "distance=" + diagonal + " known=" + 170 + " unit=mm");
	
	print("Diagonal: " + diagonal);
	close("*");
}

function getThesholdFromClassifier(inputID){
	
	selectImage(inputID);
	run("Trainable Weka Segmentation");
	wait(3000);
	selectWindow("Trainable Weka Segmentation v3.3.4");
	call("trainableSegmentation.Weka_Segmentation.loadClassifier", classifierRuler);
	call("trainableSegmentation.Weka_Segmentation.getResult");
	
	selectImage("Classified image");
	
	//converts it to black and white and inverts to normal
	setAutoThreshold("Default");
	run("Convert to Mask");
	run("Invert");
	output = getImageID();
	close("Trainable Weka Segmentation v3.3.4");
	return output
}













