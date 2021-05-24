FROM p4lang/p4app

RUN apt-get update
RUN apt-get install -y --no-install-recommends \
    iproute2 \
    iputils-ping \
    net-tools \
    openvswitch-switch \
    openvswitch-testcontroller \
    vim \
    xterm

WORKDIR /root

COPY . .

ENTRYPOINT ["sleep", "infinity"]
