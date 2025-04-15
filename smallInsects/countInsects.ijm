#@ File (label="Select a classifier", description="Select the Weka model to apply") classifier

inputDir=getDirectory("Choose Source Directory ");
outputDir=getDirectory("Choose folder for output");




////////////// Parameters //////////////////////////
scaleFactor = 3;			// how much the image is scaled down, ex scaleFactor of 3: 3000px -> 1000px
							//		make sure this amount puts images below 1500pxs and preferably around 1000px
							//		set to same amount as training the classifier for consistancy
lowerBoundSizeMM2 = 0.1;	// any particles below this size will be filtered out
petriDishWidthMM = 150; 	// width of the petri dish, the petri dish should take up the whole with of the image
							//		
//////////////////////////////////////////////////





scaleFactorInverse = 1/scaleFactor;

//creates files
outputDirTheshold = outputDir + "Theshold" + "/";
File.makeDirectory(outputDirTheshold);
outputDirOverlay = outputDir +  "Overlay" + "/";
File.makeDirectory(outputDirOverlay);

list = getFileList(inputDir);

main();

function main(){
	open(inputDir + list[0]);

	//setsup the classifier
	run("Trainable Weka Segmentation");
	wait(3000);
	selectWindow("Trainable Weka Segmentation v4.0.0");
	call("trainableSegmentation.Weka_Segmentation.loadClassifier", classifier);
	
	//loops through all insects
	startRow = 0;
	for (i = 0; i < list.length; i++){
		countInsects(inputDir, list[i], i, startRow);	
		startRow = nResults;
	}
	
	//cleans up files
	selectWindow("Trainable Weka Segmentation v4.0.0");
	close();
	
	selectWindow("Results");
	saveAs("results", outputDir + "results.csv");
	close("Results");
	
	selectWindow("Summary");
	Table.save(outputDir + "summary.csv");
	close("Summary");
	
	close("ROI Manager");
	print("Program Complete :)");
}

function countInsects(input, filename, iteration, startRow){
	open(inputDir + filename);
	original = getImageID();
	
	//gets pixel to MM
	imageWidth = getWidth();
	print("Image width: " + imageWidth);
	
	run("Set Scale...", "distance=" + imageWidth + " known=" + petriDishWidthMM + " unit=mm");

	//duplicates original then closes it to preserve it
	run("Duplicate...", " ");
	fullScale = getImageID();
	selectImage(original);
	close();
	
	//scales down image
	selectImage(fullScale);
	run("Scale...",  "x=" + scaleFactorInverse + " y=" + scaleFactorInverse + " interpolation=Bilinear average create");
	scaled_down = getImageID();
	
	//saves scaled down to be used in weka segmentation 
	// weka segmentation needs to use a file in your file directory
	//		if already opened
	selectImage(scaled_down);
	saveAs(".tiff", inputDir + "scaledDown");
	selectImage(scaled_down);
	close();
	
	//calls classifier
	selectWindow("Trainable Weka Segmentation v4.0.0");
	call("trainableSegmentation.Weka_Segmentation.applyClassifier", inputDir, "scaledDown.tif", 
		"showResults=true", "storeResults=false", "probabilityMaps=false", "");
	
	//scaled down as it is not need anymore
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
	
	//saves the theshold in case of later use
	saveAs(".tiff", outputDirTheshold + filename );
	
	//analyses the particles of threshold
	run("Convert to Mask");
	run("Fill Holes");
	run("Analyze Particles...", "size=" +lowerBoundSizeMM2+ "-Infinity display exclude summarize overlay add");
	close();
	
	//creates a outline of bugs on original image
	selectImage(fullScale);
	for (i=0; i<roiManager("count"); ++i) {
		roiManager("Select", i);
		roiManager("update");
	}
	run("Flatten");
	saveAs(".tiff", outputDirOverlay + filename);
	close();
	
	
	//gets offset from results for next one
	updateResults();
	close();
	

	//closes images and resets roiManger for next image
	if (isOpen(fullScale)){
		selectImage(fullScale);
		close();
	}
	roiManager("deselect");
	roiManager("delete");
}