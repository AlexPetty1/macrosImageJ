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





function writeOnImageTest(){
	newImage("test", "8-bit white", 400, 400, 1);
	
	
	for(i = 0; i < 20; i++){
		setFont("SansSerif", i + 1);
		drawString("text", 50, i * 15);
		
	}
}

//writeOnImageTest();
createCSVTest();
