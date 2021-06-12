from __future__ import print_function
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
fieldList = ["frame_len", "eth_type", "ip_proto", "ip_flags", "srcport", "dstport"]

maxDict = {"frame_len": 0x100000000,
            "eth_type": 0x10000,
            "ip_proto": 0x100,
            "ip_flags": 0x8,
            "srcport": 0x10000,
            "dstport": 0x10000}

def feature_to_fieldno(feature):
    return fieldDict[feature]

def fieldno_to_feature(fieldno):
    for feature in fieldDict.keys():
        if fieldDict[feature] == fieldno:
            return feature

def load_tree_by_features(p4RT, configFile, logFile):
    featureDict = dict()
    # init feature dictionary
    for feature in fieldDict.keys():
        featureDict[feature] = [0, maxDict[feature]] # init with lower bound & upper bound

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
        if info["type"] == "split":
            featureDict[info["feature"]].append(int(float(info["threshold"])))

    # sort each feature's threshold list
    featureCodes = dict()
    for feature in featureDict.keys():
        featureDict[feature] = sorted(featureDict[feature])
        featureCodes[feature] = {}

        for i, element in enumerate(featureDict[feature]):
            featureCodes[feature][element] = i

            # install feature tables at the same time
            if i < len(featureDict[feature]) - 1:
                cmd = "lookup_{field} set_{field}_code {start}->{stop} => {code} 0".format(field=feature, code = i, start=element, stop=featureDict[feature][i + 1] - 1)
                outputFile.write("table_add %s\n" % cmd)
                print(cmd, file=logFile)
    

    def generate_Code(prefix, lookup_code, current_feature_index):
        if current_feature_index != len(fieldList):
            for i in range(len(featureDict[fieldList[current_feature_index]]) - 1):
                generate_Code(prefix + [i], (lookup_code << 5) + i, current_feature_index + 1)
        else:
            sample = [featureDict[fieldList[i]][e] for i, e in enumerate(prefix)]
            run_node = '0'
            while nodeDict[run_node]['type'] == 'split':
                sample_value = sample[feature_to_fieldno(nodeDict[run_node]['feature'])]
                if sample_value <= int(float(nodeDict[run_node]['threshold'])):
                    run_node = nodeDict[run_node]['left']
                else:
                    run_node = nodeDict[run_node]['right']
            # leaf
            sample_class = nodeDict[run_node]['class']
            outputFile.write("table_add lookup_code set_class %d => %s\n" % (lookup_code, sample_class))
            p4RT.do_table_add("lookup_code set_class %d => %s" % (lookup_code, sample_class))


    generate_Code([], 0, 0)

def load_tree_by_layers(p4RT, configFile, logFile):
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
