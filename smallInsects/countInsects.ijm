#@ File (label="Select a classifier", description="Select the Weka model to apply") classifier

inputDir=getDirectory("Choose Source Directory ");
outputDir=getDirectory("Choose folder for output");

scaleFactor = 3;
scaleFactorInverse = 1/scaleFactor;

lowerBoundSizeMM2 = 0.1;

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
	selectWindow("Trainable Weka Segmentation v3.3.4");
	call("trainableSegmentation.Weka_Segmentation.loadClassifier", classifier);
	
	//loops through all insects
	startRow = 0;
	for (i = 0; i < list.length; i++){
		countInsects(inputDir, list[i], i, startRow);	
		startRow = nResults;
	}
	
	selectWindow("Trainable Weka Segmentation v3.3.4");
	close();
	
	selectWindow("results");
	saveAs("results", outputDir + "results.csv");
	close();
	
	selectWindow("Summary");
	saveAs("summary", outputDir + "summary.csv");
	close();
}

function countInsects(input, filename, iteration, startRow){
	open(inputDir + filename);
	original = getImageID();
	
	//gets pixel to MM
	imageWidth = getWidth();
	print("Image width: " + imageWidth);
	
	run("Set Scale...", "distance=" + imageWidth + " known=150 unit=mm");
//	run("Set Scale...", "distance= " + diagonal + " known=" + 170 + " unit=mm");
	//duplicates original then closes it to preserve it
	run("Duplicate...", " ");
	fullScale = getImageID();
	selectImage(original);
	close();
	
	//sets measurements
	selectImage(fullScale);
	
	//scales down image
	run("Scale...",  "x=" + scaleFactorInverse + " y=" + scaleFactorInverse + " interpolation=Bilinear average create");
	scaled_down = getImageID();
	
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
	
/////updates the results and summary ///////
	
//	//updates results
//	for(j = startRow; j < nResults; j++){
//		insectNum = j - startRow + 1;
//		print(insectNum);
//		print(j);
//		print(startRow);
//		setResult("Number", j, insectNum);
//	
//		//converts pixels to cms
//		areaInPixels = getResult("Area", j);
//		print("Area in pixels" + areaInPixels);
//		areaInMM = areaInPixels * (pixelToMM * pixelToMM);
//		setResult("Area mm", j, areaInMM);
//		
//		//adds result to table
//		selectWindow("Summary");
//		if(areaInMM < 0.1){
//			initalCount = Table.get("Super Small Bug or Error", iteration);
//			Table.set("Super Small Bug or Error", iteration, initalCount + 1);
//		} else if(areaInMM < 1){
//			initalCount = Table.get("Small Count", iteration);
//			Table.set("Small Count", iteration, initalCount + 1);
//		} else if(areaInMM < 3){
//			initalCount = Table.get("Medium Count", iteration);
//			Table.set("Medium Count", iteration, initalCount + 1);
//		} else if(areaInMM < 8){
//			initalCount = Table.get("Large Count", iteration);
//			Table.set("Large Count", iteration, initalCount + 1);
//		} else {
//			initalCount = Table.get("Moth", iteration);
//			Table.set("Moth", iteration, initalCount + 1);
//		} 
//	}
	
	//gets offset from results for next one
	updateResults();
	close();
	
	//updates summary
//	selectWindow("Summary");
//	Table.set("Slice", iteration, filename);
//	Table.set("Date", iteration, fileNameSplit[0]);
//	Table.set("Post", iteration, fileNameSplit[1]);
//	Table.set("Direction", iteration, fileNameSplit[2]);
	
	//updates results to mms
	//replace this with set measurement in future
//	averageSizePixels = Table.get("Average Size", iteration);
//	Table.set("Average Size", iteration, averageSizePixels * (pixelToMM * pixelToMM));
//	totalAreaPixels = Table.get("Total Area", iteration);
//	Table.set("Total Area", iteration, totalAreaPixels * (pixelToMM * pixelToMM));
//	

	//closes images and resets roiManger for next image
	if (isOpen(fullScale)){
		selectImage(fullScale);
		close();
	}
	roiManager("deselect");
	roiManager("delete");
}