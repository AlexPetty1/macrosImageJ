//#@ String (label = "Name of output CSV file", persist=false, value = "Circle_Results") outputName


///// PARAMETERS //////////////////////////////////////////////////////

var scaleFactor = 12;			// scale factor is needed otherwise hollow circle transform will crash
								//    scales images by this factor aim for around 500pixels or less
var maxToMinRatio = 0.5;		// sets lower bound for size for circle relative to smallest axis
var waitTimeUntilRetry = 100;   // time to wait until retrying 
var threshold = 0.5;			// threshold value for hough circle transform
								//    a
var outputType = "tiff"; 		// tiff is better than jpg for image analysis

//////////////////////////////////////////////////////////////////////////////


var scaleFactorInverse = 1/scaleFactor;

main();

function main(){
	inputDir=getDirectory("Choose Source Directory ");
	outputDir=getDirectory("Choose Output Directory ");
	inputFiles = getFileList(inputDir);
	
	print("Program started ");
	
	notFound =  newArray(0);
	
	//loops through all the images
	for (i = 0; i < inputFiles.length; i++){
		
		//moves to next file, if file already in output
		if(isFileInDirectory(outputDir, inputFiles[i], true) == true){
			continue;
		}
	
		print("");
		print("Image: " + inputFiles[i] + " identifying" );
		
		//circle identifier often breaks
		//so it tries 3 times
		for(try = 0; try < 3; try++){
			success = createCircle(inputDir, outputDir, inputFiles[i], i);	
			
			if(success == 1){
				print("succuessfully identified");
				break;	
			}
		
			print("Could not dectect petri trying again ");
			if(try == 2){
				print("Could not find petri dish for " + inputFiles[i]);
				notFound = Array.concat(notFound, inputFiles[i]);
			}
		}
	}
	   
	
	
	print("Program Finished");
	
	if(notFound.length == 0){
		print("All petri dishes found");
	} else {
		print("Could not find petri dishes: ");
		for(i = 0; i < notFound.length; i++){
			print(notFound[i]);
		}
	}
}


//Returns 1 if image created, 0 if had error
//identifies a circle on the image and saves it
//		petri dishes are circles
function createCircle(inputDir, outputDir, filename, i){
	run("Clear Results");

	open(inputDir + filename);
	original = getImageID();
	
	//duplicates orginial to not modify it
	run("Duplicate...", " ");
	step1 = getImageID();
	selectImage(original);
	close();
	
	//scales image as running hough transform at normal resolution will run out of ram
	run("8-bit");
	run("Scale...", "x=" + scaleFactorInverse + " y=" + scaleFactorInverse + " interpolation=Bilinear average create title=circle-scale.JPG");
	scaledImage = getImageID();
	selectImage(step1);
	close();
	
	//gets min radius and max for use in hough circle transform
	selectImage(scaledImage);
	widthScaled = getWidth();
	heightScaled = getHeight();
	maxRadius = minOf(widthScaled, heightScaled) / 2;
	minRadius = maxRadius * maxToMinRatio;
	
	minRadius = round(minRadius);
	maxRadius = round(maxRadius);
	
	//finds circle in image - petri dishes are circles
	run("Find Edges");
	setAutoThreshold("Default dark no-reset");
	run("Convert to Mask");
	run("Hough Circle Transform","minRadius=" + minRadius +", maxRadius=" + maxRadius + ", inc=1, minCircles=1, maxCircles=65535, threshold=" + threshold + ", resolution=1000, ratio=1.0, bandwidth=10, local_radius=10,  reduce show_mask results_table");
	
	//waits until hough circle transform is done
	currentNImages = nImages;
	counter = 0;
	wait(1000);
	close();
	while((nImages== (currentNImages-1)) && (counter < waitTimeUntilRetry)){
		wait(100);
		counter++;	
	}
	
	//checks if time out occurs meaning no image was found
	if(nResults == 0){
		close("*");
		return 0;
	}
	
	//gets values from results
	x = getResult("X (pixels)", 0);
	y = getResult("Y (pixels)", 0);
	radius = getResult("Radius (pixels)", 0);
	
	//gets location and dimension of petridish
	diameter = radius * 2  * scaleFactor;
	xCorner = (x - radius) * scaleFactor;
	yCorner = (y - radius) * scaleFactor;
	
	//makes circle on original image
	open(inputDir + filename);
	makeOval(xCorner, yCorner, diameter, diameter);
	
	//verifies make oval works
	if(is("area") == false){
		wait(10);
		makeOval(xCorner, yCorner, diameter, diameter);
		
		if(is("area") == false){
		
			close("*");
			return 0;
		}
	}
	
	//makes back ground white
	setBackgroundColor(255, 255, 255);
	run("Clear Outside");
	
	//duplicates image to crop out extra background
	notCropped = getImageID();
	run("Duplicate...", " ");
	saveAs(outputType, outputDir + filename);
	
	close("*");
	return 1;
}


//returns if a array has a string
function arrayHasString(array, string){
 	for (i = 0; i < array.length; i++) {
 		if(array[i] == string){
			return true;
 		} 		
 	}	
 	
 	return false;
 }
 
 
 //returns if a file is a directory
 //		ignoreType - will ignore file type if enabled
 //			ex: test.jpg -> test
 function isFileInDirectory(dir, file, ignoreType){
	files = getFileList(dir);
	
	//removes the type at end example: test.jpg -> test
	if(ignoreType == true){
		typeStart = lastIndexOf(file, ".");
		if(typeStart != -1){
			file = substring(file, 0, typeStart);
		}
	}
 	
 	for (i = 0; i < files.length; i++) {
 		dirFile = files[i];
 		
 		if(ignoreType == true){
			typeStart = lastIndexOf(dirFile, ".");
			if(typeStart != -1){
				dirFile = substring(dirFile, 0, typeStart);
			}
		}
 		
 		if(dirFile == file){
			return true;
 		} 		
 	}
 	
 	return false;
}
 
 