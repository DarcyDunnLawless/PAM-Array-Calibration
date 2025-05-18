# PAM-Array-Calibration
Example code of the data processing needed to calibrate a Passive Acoustic Mapping (PAM) array as described by [Gray &amp; Coussios (2018)](http://doi.org/10.1109/tuffc.2018.2866171).

## Purpose
This code is intended to help first-time experimenters understand the processing steps required to turn raw hydrophone and array signals into a finished array calibration. It includes example data captured for a standard L11-5v probe at Oxford University's BUBBL lab.

This code is not supposed to be a one-click solution for calibrating arrays - you should consider it a starting point for writing your own code rather than a complete piece of software. That said, I have done my best to make it generalizable, and to write it in a clear way for easy modification

The example data is provided purely to show how the code works, and is not suitable for use with any L11-5v array other than the specific unit measured in Oxford.

## Installation
If you're not familiar with git & github, just download this repository as a .zip file (Code > Download ZIP). If you move any of the provided .mat files out of the folder with the main code in it, make sure their new locations are added to the MATLAB path.

## Running the Code
All of the code is contained in the file `ArrayCalibrationScript.m`. This code is written in sections that you can run one at a time with `ctrl+enter` (`cmd+enter` on mac). Each section ends with a check step that displays the result of what the last bit of code has done, so you can keep track of what it's doing. On your first time through, I recommend leaving `checkSteps` on and running each section one at a time.

## Files
Each file of the example data contains a `...Info` structure that describes exactly what each variable inside it is.

### Code
`ArrayCalibrationScript.m`

All the code needed is in here.

### Example Data
`HydrophoneXScan`

Un-calibrated voltage signals produced by scanning the hydrophone through the locations of each of the array's elements. 
  
`HydroPhoneYScan`

Un-calibrated voltage signals produced by scanning the hydrophone over the height of the array elements in the elevation (_y_) direction.

`ArrayRecording`

Voltage signals produced by each element in the array.

### Hydrophone Specs for Example Data
`HydrophoneSensitivity`

Plane wave sensitivity of the hydrophone used to create the example data.

`HydrophoneDirectivity`

Directivity of the hydrophone used to create the example data.

## Citation
If you do use this code as a basis for published work, please reference this presentation as the original source: D. M. Dunn-Lawless, C. C. Coussios, M. D. Gray (2025) "Practical considerations in the calibration of array probes for quantitative cavitation imaging: lessons learned from 16 attempts" 188th Meeting of the Acoustical Society of America. (DOI coming soon)
