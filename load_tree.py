from __future__ import print_function
import sys

from numpy.core.getlimits import _discovered_machar
sys.path.append("/usr/local/lib/python3.6/site-packages")
import argparse
import math
from segment import getPrefix

from runtime_CLI import RuntimeAPI, get_parser, thrift_connect, load_json_config

fieldDict = {"frame_len": 0,
            "eth_type": 1,
            "ip_proto": 2,
            "ip_flags": 3,
            "srcport": 4,
            "dstport": 5}
fieldList = ["frame_len", "eth_type", "ip_proto", "ip_flags", "srcport", "dstport"]

maxDict = {"frame_len": 0xFFFFFFFF,
            "eth_type": 0xFFFF,
            "ip_proto": 0xFF,
            "ip_flags": 0x7,
            "srcport": 0xFFFF,
            "dstport": 0xFFFF}

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
        featureDict[feature] = {-1, maxDict[feature]} # init with lower bound & upper bound

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
            featureDict[info["feature"]].add(float(info["threshold"]))

    # sort each feature's threshold list
    featureCodes = dict()
    for feature in featureDict.keys():
        featureDict[feature] = sorted(list(featureDict[feature]))
        featureCodes[feature] = {}

        for i, element in enumerate(featureDict[feature]):
            featureCodes[feature][element] = i

            # install feature tables at the same time
            if i < len(featureDict[feature]) - 1:
                cmd = "lookup_{field} set_{field}_code {start}->{stop} => {code} 0".format(field=feature, code = i, 
                            start=int(math.ceil(element+0.01)), stop=int(featureDict[feature][i + 1]))
                logFile.write("table_add %s\n" % cmd)
                p4RT.do_table_add(cmd)
    

    def generate_Code(prefix, lookup_code, current_feature_index):
        if current_feature_index != len(fieldList):
            for i in range(len(featureDict[fieldList[current_feature_index]]) - 1):
                generate_Code(prefix + [i], (lookup_code << 5) + i, current_feature_index + 1)
        else:
            # use right side
            sample = [int(math.ceil(featureDict[fieldList[i]][e]+0.01)) for i, e in enumerate(prefix)]
            run_node = '0'
            # print(sample, lookup_code)
            # print(run_node)
            while nodeDict[run_node]['type'] == 'split':
                sample_value = sample[feature_to_fieldno(nodeDict[run_node]['feature'])]
                if sample_value <= float(nodeDict[run_node]['threshold']):
                    run_node = nodeDict[run_node]['left']
                else:
                    run_node = nodeDict[run_node]['right']
                # print(run_node)
            # leaf
            sample_class = nodeDict[run_node]['class']
            logFile.write("table_add lookup_code set_class %d => %s\n" % (lookup_code, sample_class))
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
        
        leftRange = getPrefix(0, int(math.floor(float(info["threshold"]))))
        rightRange = getPrefix(int(math.ceil(float(info["threshold"])+0.01)), 0xffffffff)
        leftCmd = ""
        rightCmd = ""

        for leftPrefix in leftRange:
            prefixStr = "0x%x/%d" % leftPrefix
            if nodeDict[info["left"]]["type"] == "split":
                # left child is a split node
                actionName = "to_next_level"
                leftCmd = "{table} {action} {node} {range} => {leftChild} {nextField}".format(table=tableName, action=actionName, node=node, range=prefixStr, leftChild=info["left"], nextField=feature_to_fieldno(nodeDict[info["left"]]["feature"]))
            else:
                # left child is a leaf node
                actionName = "set_class"
                leftCmd = "{table} {action} {node} {range} => {label}".format(table=tableName, action=actionName, node=node, range=prefixStr, label=nodeDict[info["left"]]["class"])
            logFile.write("table_add %s\n" % leftCmd)
            p4RT.do_table_add(leftCmd)

        for rightPrefix in rightRange:
            prefixStr = "0x%x/%d" % rightPrefix
            if nodeDict[info["right"]]["type"] == "split":
                # right child is a split node
                actionName = "to_next_level"

                rightCmd = "{table} {action} {node} {range} => {rightChild} {nextField}".format(table=tableName, action=actionName, node=node, range=prefixStr, rightChild=info["right"], nextField=feature_to_fieldno(nodeDict[info["right"]]["feature"]))
            else:
                # right child is a leaf node
                actionName = "set_class"

                rightCmd = "{table} {action} {node} {range} => {label}".format(table=tableName, action=actionName, node=node, range=prefixStr, label=nodeDict[info["right"]]["class"])
            logFile.write("table_add %s\n" % rightCmd)
            p4RT.do_table_add(rightCmd)


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
