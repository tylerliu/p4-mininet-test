# P4 Decision Tree Model

## Required Packages for Training:
- scikit-learn

## Files:
- mininet-run: script for running mininet simulation with p4
- csv_files.zip: the training feature data
- Dockerfile: the dockerfile for creating the p4 reference software router with mininet. 
- iot_decision_tree.py: the training scirpt based on IIsy paper's training script. 
- tree.p4: the current p4 program from decision tree model.
- test_config_tree.sh: the test table configuration for `tree.p4` - should be supplied by training script. 
- tree_hyper.p4: the current p4 program from decision tree model with dual feature selection.
- test_config_hyper.sh: the test table configuration for `tree-hyper.p4` - should be supplied by training script. 
- train_dump_decision_tree.py: the training script that dumps each decision node. 
- iisy_decision_tree.p4: the IIsy decision tree data plane, refitted from the NetFPGA version.

### Versions:
We currently have 3 versions of p4 programs:
- tree.p4: A decision tree with a maximum of 5 level nodes. Each node can select from 1 features. 
- hyper.p4: A hypercut-like decision tree with a maximum of 5 level nodes. Each node can selection from 2 festures. 
- iisy.p4: A iisy-implementation like decision tree. It uses a node for each feature, then perform a single final match for all features. 

### Archive:
- test.p4: the preliminary p4 program for decision tree model. 
- iisy_sample_decision_tree.p4: the IIsy decision data plane, simplified version with less features.

## Make commands:
- `make`: build the p4 programs
- `make run`: run the compiled p4 program (in the docker)
- `make run-hyper`: run the compiled hyper p4 program (in the docker)
- `make run-iisy`: run the compiled iisy p4 program (in the docker)
- `make docker-build`: build the docker image
- `make docker-run`: run the docker image
- `make docker-bash`: spawn a shell for the docker instance
- `make docker-stop`: stop and remove the docker instance
- `make train`: run the training script

