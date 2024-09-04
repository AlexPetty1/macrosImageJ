
//STEPS
//1: scale image to about 1k dimension
//2: use weka segmentation to identify the ruler
//3: enable Feret's diameter in analyze->set measurements
//4: run analyze particles with display results && size about 300 to infinity
//5: get feret from result
//6: select analyze->setscale, set distance in pixels to feret
//		set known distance to irl distance, and units to mm
//7: saves result to a csv

//Notes: 
// - scaling image down is need so weka runs faster/doesn't crash imagej
// - Feret's diameter is the largest distance between 2 points.
//	  On a ruler this will always be it's diagonal a known/measurable distance

///////////////////////////////////////////////////////////////////////////////////

var rulerDiagonalMM = 170;
var scaleFactor = 4;
var scaleFactorInverse =  1/scaleFactor;
var minParticleSize = 1500;


#@ File (label="Select a classifier for ruler", description="Select the Weka model to apply") classifierRuler
//#@ File (label="Select a image", style="file") inputImage

inputDir = getDirectory("Choose Source Directory ");
outputDir = getDirectory("Choose folder for output");


//creates files
outputDirTheshold = outputDir + "Theshold" + "/";
outputDirCSV = outputDir +  "CSV" + "/";

if(File.exists(outputDirTheshold) == false){
		File.makeDirectory(outputDirTheshold);
}

if(File.exists(outputDirCSV) == false){
		File.makeDirectory(outputDirCSV);
}


main();


function main(){
	inputList = getFileList(inputDir);
	open(inputDir + inputList[0]);
	
	//sets up csv table
	csvTableName = "Measurement Table";
	Table.create(csvTableName);
	blankArray = newArray(1);
	blankArray[0] = 0;

	Table.setColumn("Image" , inputList);
	Table.setColumn("Value", blankArray);
	

	//setsup the classifier
	run("Trainable Weka Segmentation");
	wait(3000);
	selectWindow("Trainable Weka Segmentation v3.3.4");
	call("trainableSegmentation.Weka_Segmentation.loadClassifier", classifierRuler);
	
	//loops through all insects
	for (i = 0; i < inputList.length; i++){
		print(inputList[i]);
		getMeasurement(inputList[i], csvTableName, i);
	}
	
	selectWindow("Trainable Weka Segmentation v3.3.4");
	close();
	
	selectWindow(csvTableName);
	Table.save(outputDirCSV + "Measurements.csv");
	
	selectWindow("Results");
	close();
	
	print("Program Done");
	
}

function getMeasurement(filename, measurmentTableName, iteration){
	
	open(inputDir + filename);
	original = getImageID();

	run("Duplicate...", " ");
	fullScale = getImageID();
	selectImage(original);
	close();
	
	//sets measurements
	selectImage(fullScale);
	
	//scales down image
	run("Scale...",  "x=" + scaleFactorInverse + " y=" + scaleFactorInverse + " interpolation=Bilinear average create");
	scaled_down = getImageID();
	
	selectImage(fullScale);
	close();

	
	//saves scaled down to be used in weka segmentation 
	// weka segmentation needs to use a file in your file directory
	//		if already opened
	selectImage(scaled_down);
	saveAs(".tiff", inputDir + "scaledDown");
	selectImage(scaled_down);
	close();
	
	selectWindow("Trainable Weka Segmentation v3.3.4");
	call("trainableSegmentation.Weka_Segmentation.applyClassifier", inputDir, "scaledDown.tif", 
		"showResults=true", "storeResults=false", "probabilityMaps=false", "");
	
	//scaled down not need anymore
	if(isOpen("scaledDown.tif")){
		selectImage("scaledDown.tif");
		close();	
	}
	File.delete(inputDir + "scaledDown.tif");
	
	//rescales image and runs rgb color to get threshold
	selectImage("Classification result");
	run("Scale...", "x=" + scaleFactor + " y=" + scaleFactor + " interpolation=Bilinear average create");
	run("RGB Color");
	resultScaled = getImageID();
	
	//selects just green and uses it as threshold
	run("Split Channels");
	wait(50);
	selectImage("Classification result-1 (blue)");
	close();
	selectImage("Classification result-1 (red)");
	close();
	selectImage("Classification result");
	close();
	selectImage("Classification result-1 (green)");
	threshold = getImageID();
	
	//
	run("Set Measurements...", "area centroid center perimeter bounding fit shape feret's skewness limit display add redirect=None decimal=3");
	run("Analyze Particles...", "size=" + minParticleSize +" -Infinity show=Masks display overlay");
	scaledMask = getImageID();
	
	
	//assume the largest particle is the ruler and catches min particle size
	diagonal = longestFeret();
	
	saveAs(".jpg", outputDirTheshold + filename );
	
	//add to table
	selectWindow(measurmentTableName);
	Table.set("Image", iteration, filename);
	Table.set("Value", iteration, diagonal);
	Table.update;
	
	//clean up
	selectImage(threshold);
	close();
	selectImage(scaledMask);
	close();
	run("Clear Results");
}


// finds the longest feret radius from results
function longestFeret(){
	longest = 0;
	for (i = 0; i < nResults; i++) {
		feret = getResult("Feret", i);
		if(feret > longest){
			longest = feret;
		}
	}
	
	return longest;
}













