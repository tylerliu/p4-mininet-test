import sys
sys.path.append("/usr/local/lib/python3.6/site-packages")
import argparse
import math

from runtime_CLI import RuntimeAPI, get_parser, thrift_connect, load_json_config

def feature_to_fieldno(feature: str):
    fieldDict ={"frame_len": 0,
                "eth_type": 1,
                "ip_proto": 2,
                "ip_flags": 3,
                "srcport": 4,
                "dstport": 5}

    return fieldDict[feature]

def load_tree_by_layers(p4RT: RuntimeAPI, configFile, logFile):
    nodeDict = dict()
    # parse node information
    for line in configFile:
        content = line.strip()
        kvPairs = content.split(" ")
        nodeInfo = dict()

        for item in kvPairs:
            temp = item.split("=")
            nodeInfo[temp[0]] = temp[1]

        nodeDict[nodeInfo["node"]] = nodeInfo

    # install the initial entry at level 0 MAT(Match-Action Table)
    p4RT.do_table_add("dt_level0 to_next_level => 0 {}".format(feature_to_fieldno(nodeDict["0"]["feature"])))

    # process each node & install corresponding MAT entries
    for node in nodeDict.keys():
        info = nodeDict[node]
        if info["type"] == "leaf":
            continue
        tableName = "dt_level{}".format(int(info["depth"]) + 1)
        
        leftRange = "0->{}".format(int(math.ceil(float(info["threshold"]))))
        rightRange = "{}->0xffffffff".format(int(math.ceil(float(info["threshold"]))))
        leftCmd = ""
        rightCmd = ""

        if nodeDict[info["left"]]["type"] == "split":
            # left child is a split node
            actionName = "to_next_level"

            leftCmd = "{table} {action} {node} {range} => {leftChild} {nextField} 0".format(table=tableName, action=actionName, node=node, range=leftRange, leftChild=info["left"], nextField=feature_to_fieldno(nodeDict[info["left"]]["feature"]))
        else:
            # left child is a leaf node
            actionName = "set_class"

            leftCmd = "{table} {action} {node} {range} => {label} 0".format(table=tableName, action=actionName, node=node, range=leftRange, label=nodeDict[info["left"]]["class"])

        if nodeDict[info["right"]]["type"] == "split":
            # right child is a split node
            actionName = "to_next_level"

            rightCmd = "{table} {action} {node} {range} => {rightChild} {nextField} 0".format(table=tableName, action=actionName, node=node, range=rightRange, rightChild=info["right"], nextField=feature_to_fieldno(nodeDict[info["right"]]["feature"]))
        else:
            # right child is a leaf node
            actionName = "set_class"

            rightCmd = "{table} {action} {node} {range} => {label} 0".format(table=tableName, action=actionName, node=node, range=rightRange, label=nodeDict[info["right"]]["class"])

        p4RT.do_table_add(leftCmd)
        p4RT.do_table_add(rightCmd)
        print("Add two entries to {table}\nleft: {left}\nright: {right}".format(table=tableName, left=leftCmd, right=rightCmd), file=logFile)




# Parse argument
parser = get_parser()
parser.add_argument('-i', default="tree.p4rt", help='path to P4 runtime configuration')
parser.add_argument('-o', default=sys.stdout, help='log file')
parser.add_argument('-m', default="layers", help='mode of the underlying tree implementation, options: layers/features')
args = parser.parse_args()

# Handle I/O files
inputFile = open(args.i, "r")
outputFile = sys.stdout
if args.o != sys.stdout:
    outputFile = open(args.o, "w")

# Build the connection to p4 runtime
standard_client, mc_client = thrift_connect(
    args.thrift_ip, args.thrift_port,
    RuntimeAPI.get_thrift_services(args.pre)
)
load_json_config(standard_client, args.json)
p4RT = RuntimeAPI(args.pre, standard_client, mc_client)

if args.m == "layers":
    load_tree_by_layers(p4RT, inputFile, outputFile)
