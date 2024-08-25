//test
#@ File (label="Select a image", style="file") inputCSV

//Open csv as string
x = File.openAsString(inputCSV);

//Get File List
fileList = getFileList("FolderWithCSV");

//Separate file into rows
rows = split(x,"\n");
print("test");
print("X: " + x);
print("Row 1: " + rows[0]);

//Row Position in csv file
//Add the position of csv row with the file names
rowPos = 0; 

//Iterate through csv list
for(i = 0; i< rows.length; i++){
    rowDataPoints = split(rows[i],",");

	print(rowDataPoints[0]);
	print(rowDataPoints[1]);
}