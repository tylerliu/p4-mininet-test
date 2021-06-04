COMPILER=p4c
FLAGS=--target bmv2 --arch v1model --std p4-16

DOCKER_NAME=bt

all: test.p4i tree.p4i

test.p4i test.json: test.p4
	$(COMPILER) $(FLAGS) $^

tree.p4i tree.json: tree.p4
	$(COMPILER) $(FLAGS) $^

run-test: test.p4i test_config.sh
	./mininet-run/single_switch_mininet.py  \
	--behavioral-exe simple_switch \
	--json test.json \
        --log-file switch_log.txt \
	--switch-config test_config.sh

run: test.p4i test_config.sh
	./mininet-run/single_switch_mininet.py  \
	--behavioral-exe simple_switch \
	--json tree.json \
        --log-file switch_log.txt \
	--switch-config test_config.sh

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
