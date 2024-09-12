function createCSVTest(){
	outputDir=getDirectory("Choose Output Directory ");

	
	blankArray = newArray(0);
	sampleFileNames = newArray("file1", "file2", "file3", "file4");
	sampleValues = newArray(6.4, 3.2, 2.2, 6.7);
	Table.create("Table");
	
	//mimic how it will be done in the acutal macro
	Table.setColumn("Image" , sampleFileNames);
	Table.setColumn("Value", blankArray);
	for(i = 0; i < sampleFileNames.length; i++){
		Table.set("Value", i, sampleValues[i]);
	}
	
	Table.save(outputDir + "Test.csv");
	
}


function fromCSVTest(){
	//test
	#@ File (label="Select a image", style="file") inputCSV
	
	//Open csv as string
	x = File.openAsString(inputCSV);
	
	//Get File List
	fileList = getFileList("FolderWithCSV");
	
	//Separate file into rows
	rows = split(x,"\n");

	
	//Row Position in csv file
	//Add the position of csv row with the file names
	rowPos = 0; 
	
	//Iterate through csv list
	for(i = 0; i< rows.length; i++){
		//makes single row into a array
	    rowDataPoints = split(rows[i],",");
		
		print(rowDataPoints[0]);
		print(rowDataPoints[1]);
	}
}


//takes a csv file and converts it to a table for easy manipulation
//assumes first row is name of columns
function csvToTable(csvFile, name){
	Table.create(name);
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
}





function writeOnImageTest(){
	newImage("test", "8-bit white", 400, 400, 1);
	
	
	for(i = 0; i < 20; i++){
		setFont("SansSerif", i + 1);
		drawString("text", 50, i * 15);
		
	}
}



function skeletonTests(threshold, original){
	selectImage(threshold);
	setOption("BlackBackground", true);
	run("Convert to Mask");
	run("Skeletonize");

	run("Analyze Skeleton (2D/3D)", "prune=[shortest branch] calculate show");
	
	//overlays skeleton onto original
	imageCalculator("Transparent-zero create", original,"Longest shortest paths");
	overlayedOriginal = getImageID();
	
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
}

//skeletonTests("maskOfFishies-1-1.tif", "DSCF0426-1.jpg");
//#@ File (label="Select a image", style="file") inputCSV
//csvToTable(inputCSV, "Table Test");

function newSegmentation(){
		input = "C:/URSA/invertabrate_tests/smallerSizeTest";
		inputList = getFileList(input);
		inputFile = inputList[0];
		
		call("trainableSegmentation.Weka_Segmentation.applyClassifier", input, inputFile, 
		"showResults=true", "storeResults=false", "probabilityMaps=false", "");
		
		setOption("BlackBackground", false);
		selectImage("Classification result");
		run("8-bit");
		run("Convert to Mask");
		
		
}

function getThesholdFromClassifier(inputDir, inputFile, outputDir){
	
	selectWindow("Trainable Weka Segmentation v3.3.4");
	
	call("trainableSegmentation.Weka_Segmentation.applyClassifier", input, inputFile, 
		"showResults=true", "storeResults=false", "probabilityMaps=false", "");
		
	setOption("BlackBackground", false);
	selectImage("Classification result");
	run("8-bit");
	run("Convert to Mask");
	
	//saves theshold
	saveAs(".tiff", outputDir + inputFile);
	close();
	
}

//
//inputDir = "C:/URSA/invertabrate_tests/smallerSizeTest";
//inputList = getFileList(inputDir);
//inputFile = inputList[0];
//
//getThesholdFromClassifier(inputDir, inputFile, inputDir);


function removeFileEnding(fileName){
	typeStart = lastIndexOf(fileName, ".");
		if(typeStart != -1){
			fileName = substring(fileName, 0, typeStart);
		}
	return fileName;
}

//remove file ending tests
//print(removeFileEnding("test.jpg"));			//test
//print(removeFileEnding("test"));				//test
//print(removeFileEnding("coolPlace.com.jpg"));	//coolPlace.com


//will save result to output directory with same file name
//min and max by pixels
//reusable
function filterParticlesBySize(inputDir, inputFile, outputDir, min, max){
	print("inputDir: " + inputDir);
	print("File: " + inputFile);
	setOption("BlackBackground", true);
	open(inputDir + inputFile);
	originalImg = getImageID();
	run("Convert to Mask");
	run("8-bit");
	run("Fill Holes");
	run("Analyze Particles...", "size=" +min +"-" + max + "Infinity show=Masks");
	saveAs(".tiff", outputDir + inputFile);
	close();
	selectImage(originalImg);
	close();
}

inputDir = "C:/URSA/invertabrate_tests/2. lengthsOutput/Thresholds/";
fileList = getFileList(inputDir);

for(i = 0; i < fileList.length; i++){
		
	filterParticlesBySize(inputDir, fileList[i], inputDir, 2000, "Infinity");
}


//setOption("BlackBackground", false);














