//#@ String (label = "Name of output CSV file", persist=false, value = "Circle_Results") outputName

var scaleFactor = 10;		//scale factor is needed otherwise hollow circle transform will crash
var maxToMinRatio = 0.8;	//sets lower bound for size check
var waitTimeUntilRetry = 50;     //in ms
var scaleFactorInverse = 1/scaleFactor;

var outputType = "tiff"; //tiff is better than jpg for image analysis
						//if original image is jpg than use jpg
						//as you can not reverse loss of quality

main();
print("Program done");

function main(){
	inputDir=getDirectory("Choose Source Directory ");
	outputDir=getDirectory("Choose Output Directory ");
	list = getFileList(inputDir);
	
	listLen = list.length;
	print("Program started " + listLen);
	
	//loops through all the images
	for (i = 0; i < listLen; i++){
		print("Image: " + i + "identifying" );
		
		//circle identifier often breaks for no reason
		//so it tries again
		for(try = 0; try < 3; try++){
			success = createCircle(inputDir, outputDir, list[i], i);	
			
			if(success == 1){
				break;	
			}
		
			print("Could not dectect petri trying again");
			if(try == 2){
				print("Could not find petri dish for " + list[i]);	
			}
		}
	}
	   
	
	//	saveAs("results", outputDir + outputName + ".csv");
	print("Program successful");
}


//Returns 1 if image created, 0 if had error
//identifies a circle on the image and saves it
//		petri dishes are circles
function createCircle(inputDir, outputDir, filename, i){
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
	minRadius = maxRadius * 0.8;
	
	minRadius = round(minRadius);
	maxRadius = round(maxRadius);
	
	print("Min Radius: " + minRadius);
	print("Max Radius: " + maxRadius);
	
	wait(10);
	
	//finds circle in image - petri dishes are circles
	run("Find Edges");
	setAutoThreshold("Default dark no-reset");
	run("Convert to Mask");
	run("Hough Circle Transform","minRadius=" + minRadius +", maxRadius=" + maxRadius + ", inc=1, minCircles=1, maxCircles=65535, threshold=0.4, resolution=1000, ratio=1.0, bandwidth=10, local_radius=10,  reduce show_mask results_table");
	
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
	if(counter >= waitTimeUntilRetry){
		print("Returned 0");
		return 0;
	}
	
	close();
	wait(50);
	
	//gets values from results
	x = getResult("X (pixels)", 0);
	y = getResult("Y (pixels)", 0);
	radius = getResult("Radius (pixels)", 0);
	
	diameter = radius * 2  * scaleFactor;
	xCorner = (x - radius) * scaleFactor;
	yCorner = (y - radius) * scaleFactor;
	
	//makes circle on original image
	open(inputDir + filename);
	makeOval(xCorner, yCorner, diameter, diameter);
	setBackgroundColor(0, 0, 0);
	run("Clear Outside");
	run("Clear Results");
	
	notCropped = getImageID();
	run("Duplicate...", " ");
	saveAs(outputType, outputDir + filename);
	
	close();
	selectImage(notCropped);
	close();
	return 1;
}
