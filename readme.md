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
- tree.p4: the current p4 pgram from decision tree model
- train_dump_decision_tree.py: the training script that dumps each decision node. 
- iisy_decision_tree.p4: the IIsy decision tree data plane for NetFPGA.
- iisy_sample_decision_tree.p4: the IIsy decision data plane, simplified version.

## Make commands:
- `make`: build the p4 program for test.p4
- `make run`: run the compiled p4 program (in the docker)
- `make docker-build`: build the docker image
- `make docker-run`: run the docker image
- `make docker-bash`: spawn a shell for the docker instance
- `make docker-stop`: stop and remove the docker instance
- `make train`: run the training script

