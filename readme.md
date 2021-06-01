# P4 Decision Tree Model

## Required Packages for Training:
- scikit-learn

## Files:
- mininet-run: script for running mininet simulation with p4
- csv_files.zip: the training feature data
- Dockerfile: the dockerfile for creating the p4 reference software router with mininet. 
- iot_decision_tree.py: the training scirpt based on IIsy paper's training script. 
- test_config.sh: the test table configuration - should be supplied by training script. 
- test.p4: the preliminary p4 program for decision tree model. 
- train_dump_decision_tree.py: the training script that dumps each decision node. 

## Make commands:
- `make`: build the p4 program for test.p4
- `make run`: run the compiled p4 program (in the docker)
- `make docker-build`: build the docker image
- `make docker-run`: run the docker image
- `make docker-bash`: spawn a shell for the docker instance
- `make docker-stop`: stop and remove the docker instance
- `make train`: run the training script

