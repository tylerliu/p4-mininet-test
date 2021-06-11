# P4 Decision Tree Model

## Required Packages for Training:
- scikit-learn

## Required Packages for running docker on mac:
- Xquartz
  - Make sure xhost is accessible from the terminal
  - also make sure xquartz allows incoming network connection

## Files:

### src folder
- tree.p4: the current p4 program from decision tree model.
- tree_hyper.p4: the current p4 program from decision tree model with dual feature selection.
- iisy_decision_tree.p4: the IIsy decision tree data plane, refitted from the NetFPGA version.
- header.p4: The common header definitions.
  
### example_command_config folder
- test_config_tree.sh: the test table configuration for `tree.p4` - should be supplied by training script. 
- test_config_hyper.sh: the test table configuration for `tree-hyper.p4` - should be supplied by training script. 
- test_config_iisy.sh: the test table configuration for `iisy_decision_tree.p4` - should be supplied by training script. 

### Main directory
- mininet-run: script for running mininet simulation with p4
- csv_files.zip: the training feature data
- Dockerfile: the dockerfile for creating the p4 reference software router with mininet. 
- iot_decision_tree.py: the training scirpt based on IIsy paper's training script. 
- train_dump_decision_tree.py: the training script that dumps each decision node. 
- IIsy_Data_Processing.ipynb: the python notebook to pre-process the dataset. 

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

## Basic Usage

To download and build the input data, use `IIsy_Data_Processing.ipynb`. The end result is placed in `csv_file.zip`. 

The basic usage script is written in the make file. To run the basic decision tree program:
1. Build the docker image with `make docker-build`.
2. Run the docker instance in the background with `make docker-run`.
3. Start a shell in the docker instance with `make docker-bash`.
4. In the docker shell, run `make` to compile the p4 programs. 
5. To run the p4 program in the mininet, run `make run` in the docker shell. 
6. To stop the docker instance, run `make docker-stop`.