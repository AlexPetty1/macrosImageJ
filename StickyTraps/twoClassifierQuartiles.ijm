#@ File (label="Select a classifier for insect", description="Select the Weka model to apply") classifierBug
#@ File (label="Select a classifier for moths", description="Select the Weka model to apply") classifierMoth

inputDir=getDirectory("Choose Source Directory ");
outputDir=getDirectory("Choose folder for output");

main();

function main(){
	//gets input files list
	inputList = getFileList(inputDir);
	inputDirLen = inputList.length;
	
	
	//creates directories
	scaledImages = outputDir + "scaledImages" + "/";				// images scaled to 
	mothTemp = outputDir + "mothTemp" + "/";						// moth threshold images before size filter
	mothThresholds = outputDir + "mothThresholds" + "/";			// moth thresholds
	bugThresholds = outputDir + "bugThresholds" + "/";				// 
	combinedThresholds = outputDir + "combinedThresholds" + "/";	// results of combination of the two thresholds
	finalOverlay = outputDir + "finalOverlay" + "/";				// shows images of threshold overlayed upon the original
	csvResults = outputDir + "csvResults" + "/";					// where the csv files are stored
	
	if(File.exists(scaledImages) == 0){
		File.makeDirectory(scaledImages);
	}
	if(File.exists(mothThresholds) == 0){
		File.makeDirectory(mothThresholds);
	}
	if(File.exists(bugThresholds) == 0){
		File.makeDirectory(bugThresholds);
	}
	if(File.exists(combinedThresholds) == 0){
		File.makeDirectory(combinedThresholds);
	}
	if(File.exists(finalOverlay) == 0){
		File.makeDirectory(finalOverlay);
	}
	if(File.exists(csvResults) == 0){
		File.makeDirectory(csvResults);
	}
	if(File.exists(mothTemp) == 0){
		File.makeDirectory(mothTemp);
	}
	
	//gets rid of scaled down if it exists
	if(File.exists(inputDir + "scaledDown.tif")){
		File.delete(inputDir + "scaledDown.tif");	
	}
	
	wait(20);
	
	
	//scales images
	scaledImagesList = getFileList(scaledImages);
	scaledImagesDirLen = scaledImagesList.length;
	
	if(scaledImagesDirLen < inputDirLen){
		
		for(i = scaledImagesDirLen; i < inputDirLen; i++) {
			scaleAndSave(inputDir, inputList[i], scaledImages, 2);
		}
	}
	
	
	//get moth threshold
	mothTempList = getFileList(mothTemp);
	mothTempDirLen = mothTempList.length;
	scaledImagesList = getFileList(scaledImages);
	scaledImagesDirLen = scaledImagesList.length;
	
	print(mothTempDirLen);
	print(inputDirLen);
	if(mothTempDirLen < inputDirLen){
		//wekka needs a image open for some reason to open
		open(scaledImages + scaledImagesList[0]);
		tempImage = getImageID();
		
		run("Trainable Weka Segmentation");
		wait(3000);
		selectWindow("Trainable Weka Segmentation v3.3.4");
		call("trainableSegmentation.Weka_Segmentation.loadClassifier", classifierMoth);
		
		for (i = mothTempDirLen; i < inputDirLen; i++) {
			getThesholdFromClassifier(scaledImages, scaledImagesList[i], mothTemp);
		}
		
		safeClose(tempImage);
		safeClose("Trainable Weka Segmentation v3.3.4");
	}
	
	//scales moth threshold
	mothList = getFileList(mothThresholds);
	mothDirLen = mothList.length;
	mothTempList = getFileList(mothTemp);
	
	if(mothDirLen != inputDirLen){
		for (i = mothDirLen; i < inputDirLen; i++) {
			filterParticlesBySize(mothTemp, mothTempList[i], mothThresholds, 100, "Infinity");
		}
		run("Clear Results");
	}
	
	
	//get bug threshold
	bugList = getFileList(bugThresholds);
	bugDirLen = bugList.length;
	scaledImagesList = getFileList(scaledImages);
	scaledImagesDirLen = scaledImagesList.length;
	
	Array.print(scaledImagesList);
	
	if(bugDirLen != inputDirLen){
		open(scaledImages + scaledImagesList[0]);
		tempImage = getImageID();
		
		run("Trainable Weka Segmentation");
		wait(3000);
		selectWindow("Trainable Weka Segmentation v3.3.4");
		call("trainableSegmentation.Weka_Segmentation.loadClassifier", classifierBug);
		
		for (i = bugDirLen; i < inputDirLen; i++) {
			getThesholdFromClassifier(scaledImages, scaledImagesList[i], bugThresholds);
		}
		
		safeClose(tempImage);
		safeClose("Trainable Weka Segmentation v3.3.4");
	}


	//combines the thesholds
	combinedList = getFileList(combinedThresholds);
	combinedDirLen = combinedList.length;
	bugList = getFileList(bugThresholds);
	mothList = getFileList(mothThresholds);
	
	if(combinedDirLen != inputDirLen){
		for (i = combinedDirLen; i < inputDirLen; i++) {
			combineTwoThesholds(bugThresholds, bugList[i], mothThresholds, 
				mothList[i], combinedThresholds);	
		}
	}

	
	//results from thesholds
	//can not do this section in parts
	if(isOpen("Results")){
		run("Clear Results");	
	}
	combinedList = getFileList(combinedThresholds);
	inputList = getFileList(inputDir);
	rowNum = 0;
	for(i = 0; i < inputDirLen; i++){
			
		resultsFromThesholds(combinedThresholds, combinedList[i], inputDir, 
			inputList[i], finalOverlay, rowNum, i);
		rowNum = nResults;
		wait(50);
	}
	
	addQuartiles();
	
	selectWindow("Results");
	saveAs("Results", csvResults + "Results.csv");
	
	selectWindow("Summary");
	Table.save(csvResults + "Summary.csv");

	close("Results");
	close("Summary");
	close("ROI Manager");
	print("Program Successful");
}

//takes a image, runs a classifier on it, saves output to outputdir
//returns image at same size
//closes all images opened
//assumptions:
//		classifier is already open
function getThesholdFromClassifier(inputDir, inputFile, outputDir){
	
	selectWindow("Trainable Weka Segmentation v3.3.4");
	
	call("trainableSegmentation.Weka_Segmentation.applyClassifier", inputDir, inputFile, 
		"showResults=true", "storeResults=false", "probabilityMaps=false", "");
	
	inputOne = getImageID();
	close();
	
	//rescales image and runs rgb color to get threshold
	selectImage("Classification result");
	run("RGB Color");
	temp = getImageID();
	
	//selects just green and uses it as threshold
	run("Split Channels");
	wait(50);
	safeClose("Classification result-1 (blue)");
	safeClose("Classification result-1 (red)");
	safeClose("Classification result (blue)");
	safeClose("Classification result (red)");
	safeClose("Classification result");

	safeSelect("Classification result (green)");
	safeSelect("Classification result-1 (green)");
	
	//saves theshold
	saveAs(".tiff", outputDir + inputFile);
	close();
	
	//closes all files opened
	safeClose("Classification result (green)");
	safeClose("Classification result-1 (green)");
	safeClose(inputOne);
	safeClose(temp);
}


//will save result to output directory with same file name
//min and max by pixels
//reusable
function filterParticlesBySize(inputDir, inputFile, outputDir, min, max){
	setOption("BlackBackground", true);
	open(inputDir + inputFile);
	originalImg = getImageID();
	run("Convert to Mask");
	run("8-bit");
	run("Fill Holes");
	run("Analyze Particles...", "size=1500-Infinity show=Masks");
	saveAs(".tiff", outputDir + inputFile);
	close();
	safeClose(originalImg);
}


//combines two thresholds into one
function combineTwoThesholds(dirA, fileA, dirB, fileB, outputDir){
	open(dirA + fileA);
	run("8-bit");
	imageA = getImageID();
	open(dirB + fileB);
	run("8-bit");
	imageB = getImageID();
	
	imageCalculator("AND create", imageA, imageB);
	saveAs(".tiff", outputDir + fileA);
	close("*");
}


//takes a thresholded image, 
//		then outputs highlights of all the particles onto the original image
//		outputs to results
function resultsFromThesholds(thesholdInDir, thesholdFile, originalInDir, originalFile, overlayOutput, startRow, iter){
	open(thesholdInDir + thesholdFile);
	threshold = getImageID();
	
	open(originalInDir + originalFile);
	original = getImageID();
	
	run("Duplicate...", " ");
	originalCentered = getImageID();
	
	safeClose(original);
	
	//analyses the particles of threshold
	safeSelect(threshold);
	run("Scale...", "x=2 y=2 interpolation=Bilinear average create");
	thesholdScaledUp = getImageID();
	
	//analyzes the particles and adds to results
	run("8-bit");
	run("Convert to Mask");
	run("Analyze Particles...", "size=17-Infinity display exclude summarize overlay add");
	pixelToMM = 150 / getWidth();
	safeClose(thesholdScaledUp);
	safeClose(threshold);
	
	//creates a outline of bugs on original image
	safeSelect(originalCentered);
	for (i=0; i<roiManager("count"); ++i) {
		roiManager("Select", i);
		roiManager("update");
	}
	run("Flatten");
	saveAs(".jpg", overlayOutput + originalFile);	//saved as jpg as no future analysis is done on it
	close();
	
	
	//splits the file name - 0: date, 1: post, 2: direction
	fileNameSplit = split(originalFile, "-");
	//gets rid of .jpg or .tiff so its just direction
	fileNameSplit[2] = substring(fileNameSplit[2], 0, 1);
	
	//adds columns if first iteration
	if(iter == 0){
		blankArray = newArray(1);
		blankArray[0] = 0;
		selectWindow("Summary");
		Table.setColumn("Date", blankArray);
		Table.setColumn("Post", blankArray);
		Table.setColumn("Direction", blankArray);
	}
	
	//updates results
	number = 1;
	for(j = startRow; j < nResults; j++){
		
		//converts pixels to cms
		areaInPixels = getResult("Area", j);
		areaInMM = areaInPixels * (pixelToMM * pixelToMM);
		setResult("AreaInMM", j, areaInMM);
		setResult("AreaInPixels", j, areaInPixels);
		setResult("Number", j, number);
		setResult("Label", j, originalFile);
		
		number++;
	}
	
	close();
	
	//updates summary
	selectWindow("Summary");
	Table.set("Slice", iter, originalFile);
	Table.set("Date", iter, fileNameSplit[0]);
	Table.set("Post", iter, fileNameSplit[1]);
	Table.set("Direction", iter, fileNameSplit[2]);
	
	//updates results to cms
	averageSizePixels = Table.get("Average Size", iter);
	Table.set("Average Size", iter, averageSizePixels * (pixelToMM * pixelToMM));
	totalAreaPixels = Table.get("Total Area", iter);
	Table.set("Total Area", iter, totalAreaPixels * (pixelToMM * pixelToMM));
	Table.update;
	updateResults();
	
	roiManager("deselect");
	roiManager("delete");
}

//scales all images in a directory then, saves it
function scaleAndSave(inputDir, inputFile, outputDir, scaleFactor){
	scaleFactorInverse = 1/scaleFactor;
	
	open(inputDir + inputFile);
	original = getImageID();
	
	run("Duplicate...", " ");
	fullScale = getImageID();
	selectImage(original);
	close();
	
	selectImage(fullScale);
	run("Scale...", "x=" + scaleFactorInverse + " y=" + scaleFactorInverse + " interpolation=Bilinear average create");
	
	saveAs(".tiff", outputDir + inputFile);
	close();
	safeClose(fullScale);
}


//updates summary to have quartiles of bug sizes
//	- must be done after results from threshold as it need overall 
//		q1, q3, and median insect
//	- results and summary must be open
function addQuartiles(){
	
	//creates a array of area results
	selectWindow("Results");
	sizes = newArray(nResults);
	for (i=0; i<sizes.length; i++){
		sizes[i] = getResult("AreaInMM", i);	//change to normal area for me reusability
	}
	
	//gets the quartiles 
	Array.sort(sizes);
	q1 = sizes[1 *  sizes.length / 4];
	q2 = sizes[2 *  sizes.length / 4];
	q3 = sizes[3 *  sizes.length / 4];
	
	sumNum = 0;
	
	selectWindow("Summary");
	Table.setColumn("Q1 Count", blankArray);
	Table.setColumn("Q2 Count", blankArray);
	Table.setColumn("Q3 Count", blankArray);
	Table.setColumn("Q4 Count", blankArray);
	
	//loops through all bugs and adds to quartile
	for (i = 0; i<nResults; i++){
		//selectWindow("Results");
		areaInMM = getResult("AreaInMM", i);
		label = getResultString("Label", i);
		sumOn = Table.getString("Slice", sumNum);
		
		//moves to next petri if mismatching names
		if (sumOn != label){
			sumNum = sumNum + 1;
			sumOn = Table.get("Slice", sumOn);
		}
		
		//adds and tests to quartile
		if(areaInMM <= q1){
			curr = Table.get("Q1 Count", sumNum);
			Table.set("Q1 Count", sumNum, curr + 1);
		} else if(areaInMM <= q2){
			curr = Table.get("Q2 Count", sumNum);
			Table.set("Q2 Count", sumNum, curr + 1);
		} else if(areaInMM <= q3){
			curr = Table.get("Q3 Count", sumNum);
			Table.set("Q3 Count", sumNum, curr + 1);
		} else {
			curr = Table.get("Q4 Count", sumNum);
			Table.set("Q4 Count", sumNum, curr + 1);
		} 
	}	
}

//Designed to not crash if file is not open
function safeClose(file){
	if(isOpen(file)){
		selectImage(file);	
		close();
		return;
	}
	
	wait(20);
	
	if(isOpen(file)){
		selectImage(file);	
		close();
		return;
	}
}

//Designed to not crash if the 
function safeSelect(file){
	if (isOpen(file)){
		selectImage(file);	
		return;
	}
	
	wait(20);
	
	if (isOpen(file)){
		selectImage(file);	
		return;
	}
}