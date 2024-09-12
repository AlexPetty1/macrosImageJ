
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
var minParticleSize = 3000;


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
	
	//loops through all images
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
	saveAs(".tiff", outputDir + "temp");
	selectImage(scaled_down);
	close();
	
	selectWindow("Trainable Weka Segmentation v3.3.4");
	call("trainableSegmentation.Weka_Segmentation.applyClassifier", outputDir, "temp.tif", 
		"showResults=true", "storeResults=false", "probabilityMaps=false", "");
	
	//scaled down not need anymore
	if(isOpen("temp.tif")){
		selectImage("temp.tif");
		close();	
	}
	File.delete(outputDir + "temp.tif");
	
	//rescales image and runs rgb color to get threshold
	selectImage("Classification result");
	classificationResults = getImageID();
	
	run("Scale...", "x=" + scaleFactor + " y=" + scaleFactor + " interpolation=Bilinear average create");
	classificationResultsScaled = getImageID();

	setOption("BlackBackground", false);
	selectImage(classificationResultsScaled);
	run("8-bit");
	run("Convert to Mask");
	threshold = getImageID();
	
	//
	run("Set Measurements...", "area centroid center perimeter bounding fit shape feret's skewness limit display add redirect=None decimal=3");
	run("Analyze Particles...", "size=" + minParticleSize +" -Infinity show=Masks display overlay");
	scaledMask = getImageID();
	
	
	//assume the largest particle is the ruler and catches min particle size
	diagonal = longestFeret();
	
	saveAs(".jpg", outputDirTheshold + filename );
	
	//removes ending of file ex: test.jpg -> test
	tableFileName = removeFileEnding(filename);
	
	//add to table
	selectWindow(measurmentTableName);
	Table.set("Image", iteration, tableFileName);
	Table.set("Value", iteration, diagonal);
	Table.update;
	
	//clean up
	selectImage(threshold);
	close();
	selectImage(scaledMask);
	close();
	selectImage(classificationResults);
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


//removes the ending type of a file ex: test.jpg -> test
function removeFileEnding(fileName){
	typeStart = lastIndexOf(fileName, ".");
		if(typeStart != -1){
			fileName = substring(fileName, 0, typeStart);
		}
	return fileName;
}













