# PAM-Array-Calibration
Example code showing the data processing required to calibrate a Passive Acoustic Mapping (PAM) array with the substitution method described by [Gray &amp; Coussios (2018)](http://doi.org/10.1109/tuffc.2018.2866171).

## Purpose
This example code is intended to help first-time experimenters understand the processing steps needed to create a finished PAM array calibration from raw hydrophone and array signals captured in a substitution experiment. It includes example data captured for a standard L11-5v probe at Oxford University's BUBBL lab.

This code is NOT intended to be a one-click solution to perfectly do any array calibration for you. I have done my best to make it generalizable, but you should consider it a starting point for writing your own code rather than a complete piece of software. 

The example data is provided purely to show how the code works, and is not suitable for use with any L11-5v array other than the specific unit measured in Oxford.

## Installing and Running
If you're not familiar with git & github, just download this repository as a .zip file (Code > Download ZIP). If you move any of the provided .mat files out of the folder with the main code in it, make sure their new locations are added to the MATLAB path.

All of the code is contained in the file ArrayCalibrationScript.m. This code is written in sections that you can run one at a time with ctrl+enter (cmd+enter on mac). Each section ends with a check step that displays the result of what the last bit of code has done, so you can keep track of what it's doing. On your first time through, I recommend leaving checkSteps on and running each section one at a time.

## Files

## Citation
If you do use this code as a basis for published work, please reference this presentation as the original source: D. M. Dunn-Lawless, C. C. Coussios, M. D. Gray (2025) "Practical considerations in the calibration of array probes for quantitative cavitation imaging: lessons learned from 16 attempts" 188th Meeting of the Acoustical Society of America. (DOI coming soon)
