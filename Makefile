COMPILER=p4c
FLAGS=--target bmv2 --arch v1model --std p4-16

DOCKER_NAME=bt

all: p4_build/tree.p4i p4_build/tree-hyper.p4i p4_build/iisy_decision_tree.p4i

p4_build/tree.p4i p4_build/tree.json: src/tree.p4 src/headers.p4
	$(COMPILER) $(FLAGS) -o p4_build $<

p4_build/tree-hyper.p4i p4_build/tree-hyper.json: src/tree-hyper.p4 src/headers.p4
	$(COMPILER) $(FLAGS) -o p4_build $<

p4_build/iisy_decision_tree.p4i p4_build/iisy_decision_tree.json: src/iisy_decision_tree.p4 src/headers.p4
	$(COMPILER) $(FLAGS) -o p4_build $<

run: p4_build/tree.p4i example_command_config/test_config_tree.sh
	./mininet-run/single_switch_mininet.py  \
	--behavioral-exe simple_switch \
	--json p4_build/tree.json \
    --log-file example_command_config/switch_log_tree.txt \
	--switch-config example_command_config/test_config_tree.sh

run-hyper: p4_build/tree-hyper.p4i example_command_config/test_config_hyper.sh
	./mininet-run/single_switch_mininet.py  \
	--behavioral-exe simple_switch \
	--json p4_build/tree-hyper.json \
    --log-file switch_log_tree_hyper.txt \
	--switch-config example_command_config/test_config_hyper.sh

run-iisy: p4_build/iisy_decision_tree.p4i example_command_config/test_config_iisy.sh
	./mininet-run/single_switch_mininet.py  \
	--behavioral-exe simple_switch \
	--json p4_build/iisy_decision_tree.json \
    --log-file switch_log_tree_iisy.txt \
	--switch-config example_command_config/test_config_iisy.sh

docker-build: Dockerfile
	docker build -t p4-decision-tree .

docker-run: 
	xhost + $$(hostname)
	docker run -d \
	-e DISPLAY=$$(hostname):0 \
	--name $(DOCKER_NAME) --privileged p4-decision-tree

docker-bash: 
	docker exec -it $(DOCKER_NAME) bash

docker-stop: 
	docker stop $(DOCKER_NAME)
	docker rm $(DOCKER_NAME)

train: iot_decision_tree.py csv_files.zip
	python3 iot_decision_tree.py -z csv_files.zip -i csv_files/16-09-23-labeled.csv -t csv_files/16-09-24-labeled.csv -o a.txt

clean: 
	rm -rf p4_build/
