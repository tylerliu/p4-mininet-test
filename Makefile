COMPILER=p4c
FLAGS=--target bmv2 --arch v1model --std p4-16

DOCKER_NAME=bt

all: tree.p4i tree-hyper.p4i iisy_decision_tree.p4i

tree.p4i tree.json: tree.p4
	$(COMPILER) $(FLAGS) $^

tree-hyper.p4i tree-hyper.json: tree-hyper.p4
	$(COMPILER) $(FLAGS) $^

iisy_decision_tree.p4i iisy_decision_tree.json: iisy_decision_tree.p4
	$(COMPILER) $(FLAGS) $^

run: tree.p4i test_config_tree.sh
	./mininet-run/single_switch_mininet.py  \
	--behavioral-exe simple_switch \
	--json tree.json \
        --log-file switch_log_tree.txt \
	--switch-config test_config_tree.sh

run-hyper: tree-hyper.p4i test_config_hyper.sh
	./mininet-run/single_switch_mininet.py  \
	--behavioral-exe simple_switch \
	--json tree-hyper.json \
        --log-file switch_log_tree_hyper.txt \
	--switch-config test_config_hyper.sh

run-iisy: tree-hyper.p4i test_config_iisy.sh
	./mininet-run/single_switch_mininet.py  \
	--behavioral-exe simple_switch \
	--json iisy_decision_tree.json \
        --log-file switch_log_tree_iisy.txt \
	--switch-config test_config_iisy.sh

docker-build: Dockerfile
	docker build -t p4-decision-tree .

docker-run: 
	xhost + $$(hostname)
	docker run -d \
	-e DISPLAY=$$(hostname):0 -v /tmp/.X11-unix:/tmp/.X11-unix \
	--name $(DOCKER_NAME) --privileged p4-decision-tree

docker-bash: 
	docker exec -it $(DOCKER_NAME) bash

docker-stop: 
	docker stop $(DOCKER_NAME)
	docker rm $(DOCKER_NAME)

train: iot_decision_tree.py csv_files.zip
	python3 iot_decision_tree.py -z csv_files.zip -i csv_files/16-09-23-labeled.csv -t csv_files/16-09-24-labeled.csv -o a.txt

clean: 
	rm -f *.json *.p4i