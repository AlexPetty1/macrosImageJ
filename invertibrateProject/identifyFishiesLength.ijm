// Basic overview
// 1. identify fishies with weka segmentation
// 2. get size to pixel from csv
// 3. run skeltonize and 
// 4. run analyze skeleton to get the length
// 5. overlay it on original
// 6. repeat from every image

//-----Parameters-------
var scaleFactor = 4;				//set to ratio between original and classified image size
var scaleFactorInverse = 1/ scaleFactor;
var knownDistance = 170;
var particleMinSize = 500;

//-----Parameters-------

//Inputs
#@ File (label="Select a classifier for invertibrates") classifierInvertibrates

#@ File (label="CSV of measurements") csvMeasurements

inputDir=getDirectory("Choose Source Directory ");
outputDir=getDirectory("Choose folder for output");


//Output Directories
thresholdDir = outputDir + "Thresholds" + "/";					// moth threshold images before size filter
finalOverlayDir = outputDir + "finalOverlay" + "/";				// shows images of threshold overlayed upon the original
csvResultsDir = outputDir + "csvResults" + "/";					// where the csv files are stored
temporaryDir = outputDir + "temporary" + "/"; 					// temporary file used for 

main();

function main(){
	//creates directories
	if(File.exists(thresholdDir) == false){
		File.makeDirectory(thresholdDir);
	}
	if(File.exists(finalOverlayDir) == false){
		File.makeDirectory(finalOverlayDir);
	}
	if(File.exists(csvResultsDir) == false){
		File.makeDirectory(csvResultsDir);
	}	
	
	if(File.exists(temporaryDir) == false){
		File.makeDirectory(temporaryDir);
	}
	
	
	
	//identifies the fishies section
	inputList = getFileList(inputDir);
	open(inputDir + inputList[0]);			//weka needs a image open to work
	
	//opens trainable weka segmentation
	run("Trainable Weka Segmentation");
	wait(3000);
	selectWindow("Trainable Weka Segmentation v3.3.4");
	call("trainableSegmentation.Weka_Segmentation.loadClassifier", classifierInvertibrates);
	
	//loops through every 
	for (i = 0; i < inputList.length; i++) {
		open(inputDir + inputList[i]);
		original = getImageID();
		
		//scales, so weka does not crash
		run("Scale...", "x=" + scaleFactorInverse + " y=" + scaleFactorInverse 
			+ " interpolation=Bilinear average create");
		scaled = getImageID();
		
		//saves file in temporary folder to use for classifier
		saveAs(".tiff", temporaryDir + inputList[i]);
		inputFileName = removeFileEnding(inputList[i]);
		inputFileName = inputFileName + ".tif";	
		getThesholdFromClassifier(temporaryDir, inputFileName, thresholdDir);
		
		//filters by size to eliminate particles we dont want
		thresholdList = getFileList(thresholdDir);
		filterParticlesBySize(thresholdDir, thresholdList[i], thresholdDir, particleMinSize, "Infinity");
		
		//clean up
		selectImage(original);
		close();
		selectImage(scaled);
		close();
		File.delete(temporaryDir + inputList[i]);
	}
	selectWindow("Trainable Weka Segmentation v3.3.4");
	close();
	File.delete(temporaryDir);
	
	
	//identifies length section
	measureTableName = "Ruler Measurements";
	lengthsTableName = "Lengths Table";
	csvToTable(csvMeasurements , measureTableName);
	thresholdList = getFileList(thresholdDir);
	originalList = getFileList(inputDir);
	
	blankArray = newArray(1);
	Table.create(lengthsTableName);
	Table.setColumn("Image", blankArray);
	Table.setColumn("Skeleton", blankArray);
	Table.setColumn("Length", blankArray);
	
	for (i = 0; i < thresholdList.length; i++) {
		setScaleFromTable(measureTableName, thresholdList[i], knownDistance, true);
		
		findLengthFromThreshold(thresholdDir, thresholdList[i], inputDir, originalList[i], lengthsTableName);
	}
	
	selectWindow(lengthsTableName);
	Table.save(csvResultsDir + "Lengths.csv");
}


//assumes first column is named: Image, 2nd: Value
function setScaleFromTable(tableName, imageName, knownDistance, ignoreEnding){
	if(ignoreEnding == true){
		imageName = removeFileEnding(imageName);
	}
	
	selectWindow(tableName);
	imageColumn = Table.getColumn("Image");
	valueColumn = Table.getColumn("Value");
	for(i = 0; i < imageColumn.length; i++){
		nameFromImageCol = imageColumn[i];
		if(ignoreEnding == true){
			nameFromImageCol = removeFileEnding(nameFromImageCol);
		}
	
		if(nameFromImageCol == imageName){
			newImage("tempImage", "8-bit", 1, 1, 1);
			tempImage = getImageID();
			run("Set Scale...", "distance=" + valueColumn[i] + " known=" + knownDistance + " unit=mm");
			
			selectImage(tempImage);
			close();
			return;
		}
		
	}
	print("----- Inside setScaleFromTable -----");
	print("----- No image matching file -----");
}



function csvToTable(inputCSV, tableName){
	Table.create(tableName);
	blankArray = newArray(1);
	
	csvString = File.openAsString(inputCSV);
	rows = split(csvString,"\n");
	nameRow = split(rows[0],",");
	
	//sets up columns names
	for (i = 0; i < nameRow.length; i++) {
		Table.setColumn(nameRow[i], blankArray);
	}
	
	for (rowOn = 1; rowOn < rows.length; rowOn++) {
		currentRow = split(rows[rowOn], ",");
		for (column = 0; column < currentRow.length; column++) {
			columnName = nameRow[column];
			Table.set(columnName, rowOn - 1, currentRow[column]);
		}
	}
	Table.update;
}


//
function getThesholdFromClassifier(inputDir, inputFile, outputDir){
	
	selectWindow("Trainable Weka Segmentation v3.3.4");
	
	call("trainableSegmentation.Weka_Segmentation.applyClassifier", inputDir, inputFile, 
		"showResults=true", "storeResults=false", "probabilityMaps=false", "");
		
	setOption("BlackBackground", false);
	selectImage("Classification result");
	run("8-bit");
	run("Convert to Mask");
	
	//saves theshold
	saveAs(".tiff", outputDir + inputFile);
	close();
	
}



function findLengthFromThreshold(thresholdDir, threshold, originalDir, original, lengthsTable){
	open(thresholdDir + threshold);
	thresholdImage = getImageID();
	
	open(originalDir + original);
	originalImage = getImageID();
	run("Scale...", "x=" + scaleFactorInverse + " y=" + scaleFactorInverse 
		+ " interpolation=Bilinear average create");
	scaledOriginalImage = getImageID();
	
	selectImage(thresholdImage);
	setOption("BlackBackground", false);
	run("Convert to Mask");
	run("Skeletonize");

	run("Analyze Skeleton (2D/3D)", "prune=[shortest branch] calculate show");
	
	//overlays skeleton onto original
	imageCalculator("Transparent-zero create", scaledOriginalImage,"Longest shortest paths");
	overlayedOriginal = getImageID();
	
	selectImage(overlayedOriginal);
	
	
	//displays the skeleton IDs on the overlay
	//will show the id over the top of the first branch in branch info
	selectWindow("Branch information");
	skeletonIDOn = 1;
	setFont("SansSerif", 15);
	
	skeletonIDArray = Table.getColumn("Skeleton ID");
	tableLength = skeletonIDArray.length;
	
	for(i = 0; i < tableLength; i++){
		id = Table.get("Skeleton ID", i);
		
		//skips iternation if not new ID
		if(id != skeletonIDOn){
			continue;
		}
		
		x = Table.get("V1 x", i);
		y = Table.get("V1 y", i) + 10; //plus 10 to show above branch
		
		//makes sure it does not write above the image
		if(y >= getWidth()){
			y = y - 20;
		}
		
		selectImage(overlayedOriginal);
		drawString(id, x, y, "white");
		
		skeletonIDOn = skeletonIDOn + 1;
	}
	
	selectWindow(lengthsTableName);
	imageColumn = Table.getColumn("Image");
	startIndex = imageColumn.length;
	
	for (i = 0; i < nResults; i++) {
		skeletonLength = getResult("Longest Shortest Path", i);
		Table.set("Image", startIndex + i, original);
		Table.set("Skeleton", startIndex + i, i + 1);
		Table.set("Length", startIndex + i, skeletonLength);
		Table.update;
	}
	
	
	//clean up
	selectImage(overlayedOriginal);
	saveAs(".jpg", finalOverlayDir + original);
	close();
	selectImage(thresholdImage);
	close();
	selectImage(originalImage);
	close();
	selectImage(scaledOriginalImage);
	close();
	selectImage("Longest shortest paths");
	close();
	selectImage("Tagged skeleton");
	close();
	close("Branch information");
}

//removes the ending type of a file ex: test.jpg -> test
function removeFileEnding(fileName){
	typeStart = lastIndexOf(fileName, ".");
		if(typeStart != -1){
			fileName = substring(fileName, 0, typeStart);
		}
	return fileName;
}

function filterParticlesBySize(inputDir, inputFile, outputDir, min, max){
	setOption("BlackBackground", true);
	open(inputDir + inputFile);
	originalImage = getImageID();
	run("Convert to Mask");
	run("8-bit");
	run("Fill Holes");
	run("Analyze Particles...", "size=" +min +"-" + max + "Infinity show=Masks");
	saveAs(".tiff", outputDir + inputFile);
	close();
	selectImage(originalImage);
	close();
}









