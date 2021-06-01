#!/usr/bin/env python
#################################################################################
#
# Copyright (c) 2019 Zhaoqi Xiong, Noa Zilberman
# All rights reserved.
#
#
# @NETFPGA_LICENSE_HEADER_START@
#
# Licensed to NetFPGA C.I.C. (NetFPGA) under one or more contributor
# license agreements.  See the NOTICE file distributed with this work for
# additional information regarding copyright ownership.  NetFPGA licenses this
# file to you under the NetFPGA Hardware-Software License, Version 1.0 (the
# "License"); you may not use this file except in compliance with the
# License.  You may obtain a copy of the License at:
#
#   http://www.netfpga-cic.org
#
# Unless required by applicable law or agreed to in writing, Work distributed
# under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
# CONDITIONS OF ANY KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations under the License.
#
# @NETFPGA_LICENSE_HEADER_END@
#
################################################################################# 

import numpy as np
import pandas as pd
import argparse
from sklearn.tree import DecisionTreeClassifier
from sklearn.metrics import *
from matplotlib import pyplot as plt
from sklearn.tree import export_graphviz
import pydotplus

from sklearn import tree

parser = argparse.ArgumentParser()

# Add argument
parser.add_argument('-i', required=True, help='path to training dataset')
#parser.add_argument('-o', required=True, help='path to outputfile')
#parser.add_argument('-t', required=True, help='path to test dataset')
args = parser.parse_args()

input = args.i
#test = args.t
#outputfile = args.o


def convert_to_int(x: str):
    if isinstance(x, int):
        return x

    return int(x, 16)


def get_lineage(tree, feature_names, file):
    frame_len = []
    eth_type = []
    ip_proto = []
    ip_flags = []
    ipv6_nxt = []
    ipv6_opt = []
    tcp_srcport = []
    tcp_dstport = []
    tcp_flags = []
    udp_srcport = []
    udp_dstport = []
    left = tree.tree_.children_left
    right = tree.tree_.children_right
    threshold = tree.tree_.threshold
    features = [feature_names[i] for i in tree.tree_.feature]
    value = tree.tree_.value
    le = '<='
    g = '>'
    # get ids of child nodes
    idx = np.argwhere(left == -1)[:, 0]

    def recurse(left, right, child, lineage=None):
        if lineage is None:
            lineage = [child]
        if child in left:
            parent = np.where(left == child)[0].item()
            split = 'l'
        else:
            parent = np.where(right == child)[0].item()
            split = 'r'

        lineage.append((parent, split, threshold[parent], features[parent]))
        if parent == 0:
            lineage.reverse()
            return lineage
        else:
            return recurse(left, right, parent, lineage)

    for j, child in enumerate(idx):
        clause = ' when '
        for node in recurse(left, right, child):
            if len(str(node)) < 3:
                continue
            i = node

            if i[1] == 'l':
                sign = le
            else:
                sign = g
            clause = clause + i[3] + sign + str(i[2]) + ' and '

        a = list(value[node][0])
        ind = a.index(max(a))
        clause = clause[:-4] + ' then ' + str(ind)
        file.write(clause)
        file.write(";\n")


Set1 = pd.read_csv(input)
Set1['eth_type'] = Set1['eth_type'].apply(convert_to_int)
Set1['ip_flags'] = Set1['eth_type'].apply(convert_to_int)
Set1['tcp_flags'] = Set1['eth_type'].apply(convert_to_int)

Set = Set1.values.tolist()
X = [i[0:10] for i in Set]
Y = [i[11] for i in Set]
class_names = ['smart-static', 'sensor', 'audio', 'video', 'else']
feature_names = ['frame_len', 'eth_type', 'ip_proto', 'ip_flags', 'ipv6_nxt', 'ipv6_opt', 'tcp_srcport', 'tcp_dstport',
                 'tcp_flags', 'udp_srcport', 'udp_dstport']

# debug = open("debug.txt","w+")
# debug.write("Y = ")
# debug.write(str(Y))
# debug.write(";\n")
# debug.close()


# prepare training and testing set
X = np.array(X)
Y = np.array(Y)

# print(X)

# decision tree fit

dt = DecisionTreeClassifier(max_depth=5)
dt.fit(X, Y)
Predict_Y = dt.predict(X)
#print(accuracy_score(Y, Predict_Y))
# print("\tBrier: %1.3f" % (clf_score))
#print("\tPrecision: %1.3f" % precision_score(Y, Predict_Y, average='weighted'))
#print("\tRecall: %1.3f" % recall_score(Y, Predict_Y, average='weighted'))
#print("\tF1: %1.3f\n" % f1_score(Y, Predict_Y, average='weighted'))

# Test set
#Set2 = pd.read_csv(test)
#Set2['eth_type'] = Set2['eth_type'].apply(convert_to_int)
#Set2['ip_flags'] = Set2['eth_type'].apply(convert_to_int)
#Set2['tcp_flags'] = Set2['eth_type'].apply(convert_to_int)
#Set_t = Set2.values.tolist()
#Xt = [i[0:10] for i in Set_t]
#Yt = [i[11] for i in Set_t]

#Predict_Yt = dt.predict(Xt)
fig = plt.gcf()
fig.set_size_inches(35.5, 20.5)
tree.plot_tree(dt, fontsize=10)

plt.show()
#print(accuracy_score(Yt, Predict_Yt))
# print("\tBrier: %1.3f" % (clf_score))
#print("\tPrecision: %1.3f" % precision_score(Yt, Predict_Yt, average='weighted'))
#print("\tRecall: %1.3f" % recall_score(Yt, Predict_Yt, average='weighted'))
#print("\tF1: %1.3f\n" % f1_score(Yt, Predict_Yt, average='weighted'))

#print(confusion_matrix(Yt, Predict_Yt))

# output
clf = dt
n_nodes = clf.tree_.node_count
children_left = clf.tree_.children_left
children_right = clf.tree_.children_right
feature = clf.tree_.feature
threshold = clf.tree_.threshold
value = clf.tree_.value

node_depth = np.zeros(shape=n_nodes, dtype=np.int64)
node_parent = np.zeros(shape=n_nodes, dtype=np.int64)
node_parentRangeStr = ["N/A"] * n_nodes
is_leaves = np.zeros(shape=n_nodes, dtype=bool)

stack = [(0, 0)]  # start with the root node id (0) and its depth (0)
while len(stack) > 0:
    # `pop` ensures each node is only visited once
    node_id, depth = stack.pop()
    node_depth[node_id] = depth

    # If the left and right child of a node is not the same we have a split
    # node
    is_split_node = children_left[node_id] != children_right[node_id]
    # If a split node, append left and right children and depth to `stack`
    # so we can loop through them
    if is_split_node:
        stack.append((children_left[node_id], depth + 1))
        stack.append((children_right[node_id], depth + 1))
        node_parent[children_left[node_id]] = node_id
        node_parent[children_right[node_id]] = node_id
        f = feature_names[feature[node_id]]
        node_parentRangeStr[children_left[node_id]] = f"{f} <= {threshold[node_id]}"
        node_parentRangeStr[children_right[node_id]] = f"{f} > {threshold[node_id]}"
    else:
        is_leaves[node_id] = True

print("The binary tree structure has {n} nodes and has "
      "the following tree structure:\n".format(n=n_nodes))
for i in range(n_nodes):
    if is_leaves[i]:
        """print("{space}node={node} is a leaf node. Parent = {parent}. value={value}。".format(
            space=node_depth[i] * "\t",
            node=i,
            parent=node_parent[i],
            value=class_names[np.argmax(value[i])]))"""
        print(f"node={i},depth={node_depth[i]},parent={node_parent[i]},class={class_names[np.argmax(value[i])]},ParentNodeFeatureRange={node_parentRangeStr[i]}")
    else:
        """print("{space}node={node} is a split node: "
              "go to node {left} if X[:, {feature}] <= {threshold} "
              "else to node {right}. Parent={parent}.".format(
            space=node_depth[i] * "\t",
            node=i,
            left=children_left[i],
            feature=feature[i],
            threshold=threshold[i],
            right=children_right[i],
            parent=node_parent[i]))"""
        print(f"node={i},depth={node_depth[i]},parent={node_parent[i]},featureCurrentNode={feature_names[feature[i]]},ParentNodeFeatureRange={node_parentRangeStr[i]}")
