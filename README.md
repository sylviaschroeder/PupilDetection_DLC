# PupilDetection_DLC
This repo contains (1) a trained neural network (trained with [DeepLabCut](https://github.com/DeepLabCut)) to detect edges of the pupil and the eye lids in videos of mouse eyes, and (2) Matlab code to determine pupil position and diameter (even if parts of the pupil are covered) and episodes of blinks (eye closures).

Refer to the [Wiki](https://github.com/sylviaschroeder/PupilDetection_DLC/wiki) to learn how to use this repo. In short: install DeepLabCut, adapt the configuration file to your data, and run the network on your data. Retrain the network if you are not happy with the results. Run the Matlab script to determine pupil position and diameter, and blinks.
