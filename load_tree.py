import sys

from numpy.core.getlimits import _discovered_machar
sys.path.append("/usr/local/lib/python3.6/site-packages")
import argparse
import math

from runtime_CLI import RuntimeAPI, get_parser, thrift_connect, load_json_config

fieldDict = {"frame_len": 0,
            "eth_type": 1,
            "ip_proto": 2,
            "ip_flags": 3,
            "srcport": 4,
            "dstport": 5}

def feature_to_fieldno(feature: str):
    return fieldDict[feature]

def fieldno_to_feature(fieldno):
    for feature in fieldDict.keys():
        if fieldDict[feature] == fieldno:
            return feature

def load_tree_by_features(p4RT: RuntimeAPI, configFile, logFile):
    featureDict = dict()
    # init feature dictionary
    for feature in fieldDict.keys():
        featureDict[feature] = [0, 0xffffffff] # init with lower bound & upper bound

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

    # compute features' splitting threshold
    for node in nodeDict.keys():
        info = nodeDict[node]
        featureDict[info["feature"]].append(int(info["threshold"]))

    # sort each feature's threshold list
    featureCodes = dict()
    for feature in featureDict.keys():
        featureDict[feature] = sorted(featureDict[feature])

        for i in range(0, len(featureDict[feature])):
            featureCodes[feature][featureDict[feature][i]] = i

            # install feature tables at the same time
            if i < len(featureDict[feature]) - 1:
                cmd = "lookup_{field} set_{field}_code {start}->{stop} => {code} 0".format(field=feature, code = i, start=featureDict[feature][i], stop=featureDict[feature][i + 1])
                p4RT.do_table_add(cmd)
                print(cmd, file=logFile)

    # recursively depth-first traverse decision-tree
    def DfsDT(p4RT: RuntimeAPI, node: str, splitPoints: list(), directions:list(), logFile):
        info = nodeDict[node]
        if info["type"] == "leaf":
            # leaf node, add a corresponding entry
            cmd = "lookup_code set_class "
            for i in range(0, len(splitPoints)):
                # iterate on features
                if directions[i] == 1:
                    # greater than or equal
                    cmd += "{start}->0xffffffff ".format(start=featureDict[fieldno_to_feature(i)][splitPoints])
                else:
                    # less than
                    cmd += "0->{stop} ".format(stop=featureDict[fieldno_to_feature(i)][splitPoints] - 1)

            cmd += "=> {label} 0".format(label=info["class"])
            p4RT.do_table_add(cmd)
            print(cmd, file=logFile)
        else:
            # split node
            splitPoints[feature_to_fieldno(info["feature"])] = featureCodes[info["feature"]][int(info["threshold"])]
            directions[feature_to_fieldno(info["feature"])] = 0
            DfsDT(p4RT, info["left"], nodeDict, featureDict, splitPoints, directions, logFile)
            directions[feature_to_fieldno(info["feature"])] = 1
            DfsDT(p4RT, info["right"], nodeDict, featureDict, splitPoints, directions, logFile)

            # recover
            splitPoints[feature_to_fieldno(info["feature"])] = 0
            directions[feature_to_fieldno(info["feature"])] = 0

    splits = [0] * len(featureDict.keys())
    directs = [0] * len(featureDict.keys())
    DfsDT(p4RT, "0", splitPoints=splits, directions=directs, logFile=logFile)

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
elif args.m == "features":
    load_tree_by_features(p4RT, inputFile, outputFile)
