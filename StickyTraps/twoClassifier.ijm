#@ File (label="Select a classifier for insect", description="Select the Weka model to apply") classifierBug
#@ File (label="Select a classifier for moths", description="Select the Weka model to apply") classifierMoth

inputDir=getDirectory("Choose Source Directory ");
outputDir=getDirectory("Choose folder for output");



//////////////////|| INPUT PARAMETERS    ||/////////////////////////

scaleFactor = 3;			// amount the image is scaled down by 
							// example of 2:   3000 / 2 -> 1500
							// do same as when classifying
							// make sure it is under 1500ish
							
petriDishSizeMM = 150;		// size of petri dish in mms

minMothSizeMMs = 5;		// 

minInsectSizeMMs = 0.05;

////////////////////////////////////////////////////////////////


main();

function main(){
	//gets input files list
	inputList = getFileList(inputDir);
	inputDirLen = inputList.length;



	///// Error checking /////
	
	//checks if there are anyfiles
	if(inputDirLen == 0){
		print("Your input folder is empty!!");
		print("Please specify the correct folder or fill the current folder");
		return;
	}
	
	// checks if the input and output folders are the same
	if(inputDir == outputDir){
		print("The input and output directory needs to be different!!");
		return;
	}
	//////////////////////////////
	
	
	
	// background should always be white, 
	//		prevents cases of white = 0 one image and another 255 messing up image calculator 
	setOption("BlackBackground", false);
	
	//creates directory strings
	scaledImages = outputDir + "1._Scaled_Images" + "/";				// images scaled down
	mothTemp = outputDir + "2.1a_Moth_Unfiltered_Thresholds" + "/";		// moth threshold images before size filter
	mothThresholds = outputDir + "2.1b_Moth_Thresholds" + "/";			// moth thresholds
	bugThresholds = outputDir + "2.2_Bug_Thresholds" + "/";				// 
	combinedThresholds = outputDir + "3._combinedThresholds" + "/";	// results of combination of the two thresholds
	finalOverlay = outputDir + "4._Final_Overlay" + "/";				// shows images of threshold overlayed upon the original
	csvResults = outputDir + "5._CSV_Results" + "/";					// where the csv files are stored
	
	//creates directories
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
	
	//scales all images
	scaledImagesList = getFileList(scaledImages);
	scaledImagesDirLen = scaledImagesList.length;
	
	if(scaledImagesDirLen < inputDirLen){
		for(i = scaledImagesDirLen; i < inputDirLen; i++) {
			scaleAndSave(inputDir, inputList[i], scaledImages, scaleFactor);
		}
	}
	
	
	//gets moth threshold
	mothTempList = getFileList(mothTemp);
	mothTempDirLen = mothTempList.length;
	scaledImagesList = getFileList(scaledImages);
	scaledImagesDirLen = scaledImagesList.length;
	
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
	
	//filters moth threshold by size
	mothList = getFileList(mothThresholds);
	mothDirLen = mothList.length;
	mothTempList = getFileList(mothTemp);
	if(mothDirLen != inputDirLen){
		for (i = mothDirLen; i < inputDirLen; i++) {
			filterParticlesBySize(mothTemp, mothTempList[i], mothThresholds, minMothSizeMMs, "Infinity");
		
			//places a pixel to prevent convert to mask will break from breaking with a blank image
			// Kind of scuffed but it should be filtered out on a later step
			open(mothThresholds + mothTempList[i]);
			setPixel(3, 0, 0);
			setPixel(4, 0, 255);
			saveAs(".tiff", mothThresholds + mothTempList[i]);
			close();
		}
		run("Clear Results");
	}
	
	
	//get bug threshold
	bugList = getFileList(bugThresholds);
	bugDirLen = bugList.length;
	scaledImagesList = getFileList(scaledImages);
	scaledImagesDirLen = scaledImagesList.length;
	
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

	close("ROI Manager");
	print("Program Successful");
}



// description:
//		runs a image through the classifier and saves it to a output directory
//		weka segmentation and the classifier must already be opened
//arguments:
//		inputDir - directory where the input file is 
//		inputfile - name of the of the thresholded file
//		outputDir - directory where output is stored
// assumptions:
//		classifier must be open already
//		image should be scaled down to under 1500 px, this function may crash if you dont do this
//		output saved as a tiff for further analysis
// sideffects:
//		thresholded image(black and white image) is saved inside the output directory  
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

// description:
//		will take a thresholded image a filter the particles by size
//		in it.
//arguments:
//		inputDir - directory where the input file is 
//		inputfile - name of the of the thresholded file
//		outputDir - directory where output is stored
//		min - minimum size of particle in pixels
//		max - maximum size of particle in pixels: it can be "Infinity"
// assumptions:
//		inputfile is a binary black and white file
// sideffects:
//		filtered image will be in output directory
//		returns counted particles for error checking later
function filterParticlesBySize(inputDir, inputFile, outputDir, min, max){
	setOption("BlackBackground", false);
	open(inputDir + inputFile);
	
	//sets scale so units are not in pixels
	petriWidthMM = getWidth();
	run("Set Scale...", "distance=" + petriWidthMM + " known=" + petriDishSizeMM + " unit=mm");
	
	originalImg = getImageID();
	run("Convert to Mask");
	run("8-bit");
	run("Fill Holes");
	run("Analyze Particles...", "size=" +min +"-" + max + " show=Masks");	
	saveAs(".tiff", outputDir + inputFile);
	close();
	safeClose(originalImg);
}


// description:
//		takes two thresholded images and combines them, then saves it
//arguments:
//		dirA - directory where image of threshold A is
//		fileA - name of threshold A
//		dirB - directory where image of threshold B is
//		fileA - name of threshold B
//		outputDir - directory where the combined threshold output is stored
// assumptions:
//		dirA, dirB, and outputDir must all exist
// sideffects:
//		image will be saved in outputDirectory and take the name of fileA
function combineTwoThesholds(dirA, fileA, dirB, fileB, outputDir){
	setOption("BlackBackground", false);
	open(dirA + fileA);
	run("Convert to Mask");
	imageA = getImageID();
	open(dirB + fileB);
	run("Convert to Mask");
	imageB = getImageID();
	
	imageCalculator("OR create", imageA, imageB);
	saveAs(".tiff", outputDir + fileA);
	close();
	safeClose(imageA);
	safeClose(imageB);
}



// description:
//		takes a thresholded image, 
//		then outputs highlights of all the particles onto the original image,
//		outputs the results on onto a summary csv of whole image,
//		and adds label, sizeInPixels, and number to results csv
//arguments:
//		thesholdInDir - directory the thresholded image is stored in
//		thesholdFile -	name of the thresholded image that will be analysed
//		originalInDir - directory the original unedited image is stored in
//		originalFile - name of the original image
//		overlayOutput - directory where the output will be stored
//		startRow - row the results column is on for repeated calls
//		iter - what row the summary is on for repeated calls
// assumptions:
//		- threshold file is a binary threshold
// sideffects:
//		- 
function resultsFromThesholds(thesholdInDir, thesholdFile, originalInDir, originalFile, overlayOutput, startRow, iter){
	
	open(thesholdInDir + thesholdFile);
	threshold = getImageID();
	
	open(originalInDir + originalFile);
	original = getImageID();
	
	run("Duplicate...", " ");
	originalCentered = getImageID();
	
	safeClose(original);
	
	//scales threshold back to original size
	safeSelect(threshold);
	run("Scale...", "x=" + scaleFactor +" y=" + scaleFactor + " interpolation=Bilinear average create");
	thesholdScaledUp = getImageID();
	
	//sets scale so units are not in pixels
	petriWidthMM = getWidth();
	run("Set Scale...", "distance=" + petriWidthMM + " known=" + petriDishSizeMM + " unit=mm");
	
	//analyzes the particles and adds to results
	run("8-bit");
	run("Convert to Mask");
	run("Analyze Particles...", "size="+ minInsectSizeMMs + "-Infinity display exclude summarize overlay add");
	safeClose(thesholdScaledUp);
	safeClose(threshold);
	
	//creates a outline of bugs on original image
	safeSelect(originalCentered);
	for (i=0; i<roiManager("count"); ++i) {
		roiManager("Select", i);
		roiManager("update");
	}
	//prevents it from breaking if no insects are detected
	if(roiManager("count") > 0){
		run("Flatten");
	} else {
		run("Duplicate...", " "); //creates a fake flatten in order to not break later steps
	}
	
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
	
	//stores conversion
	mmToPixel = getWidth() / petriDishSizeMM;
	
	//updates results
	number = 1;
	for(j = startRow; j < nResults; j++){
		
		//converts pixels to cms
		areaInMM = getResult("Area", j);
		areaInPixels = round(areaInMM * (mmToPixel * mmToPixel));
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
	Table.update;
	updateResults();
	
	if(roiManager("count") > 0){
		roiManager("deselect");
		roiManager("delete");
	}	
}



// description:
//		takes a file and scales it
//		designed to be used in a loop to 
//arguments:
//		inputDir - directory the input file is in
//		inputFile - file name
//		outputDir - directory to save scaled down image
//		scaleFactor - amount the scale is scaled down by. ex of 2: 1500 -> 750
// assumptions:
//		file will be named the same in the outputDir as input directory
//		input, output, and input file must all exist
// sideffects:
//		saves a scaled down version of the file in the output directory
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


// description:
//		updates summary to have quartiles of results sizes
//arguments:
//		- none
// assumptions:
//		- must be done after results from threshold as it needs all results to get quartiles
//		- results and summary must be open
//		- results has a label and slice column
// sideffects:
//		- the summary table has 4 new quartile columns
function addQuartiles(){
	
	//creates a array of area results
	selectWindow("Results");
	sizes = newArray(nResults);
	for (i=0; i<sizes.length; i++){
		sizes[i] = getResult("AreaInMM", i);	//change to normal area for reusability
	}
	
	//gets the quartiles 
	Array.sort(sizes);
	q1 = sizes[1 *  sizes.length / 4];
	q2 = sizes[2 *  sizes.length / 4];
	q3 = sizes[3 *  sizes.length / 4];
	
	sumNum = 0;					//name of summary
	blankArray = newArray(1);
	blankArray[0] = 0;

	
	//adds columns to summary
	selectWindow("Summary");
	Table.setColumn("Q1 Count", blankArray);
	Table.setColumn("Q2 Count", blankArray);
	Table.setColumn("Q3 Count", blankArray);
	Table.setColumn("Q4 Count", blankArray);
	
	print("Nresults: " + nResults);
	//loops through all bugs and adds to quartile
	for (i = 0; i<nResults; i++){
		selectWindow("Summary");
		
		//gets insect information
		areaInMM = getResult("AreaInMM", i);
		label = getResultString("Label", i);
		summaryOnName = Table.getString("Slice", sumNum);
		
		//moves to next petri if mismatching names
		if (summaryOnName != label){
			sumNum = sumNum + 1;
			
			Table.set("Q1 Count", sumNum, 0);
			Table.set("Q2 Count", sumNum, 0);
			Table.set("Q3 Count", sumNum, 0);
			Table.set("Q4 Count", sumNum, 0);
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


// description:
//		closes the file and does not crash if it does not exist
//arguments:
//		- image or file you want to close
// assumptions:
//		- none
// sideffects:
//		- file will be closed
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

// description:
//		selects the file and does not crash if it does not exist
//arguments:
//		- image or file you want to select
// assumptions:
//		- none
// sideffects:
//		- file will be selected
// 
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