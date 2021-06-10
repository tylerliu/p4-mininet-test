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

import sys
import numpy as np
import pandas as pd
import argparse
from sklearn.tree import DecisionTreeClassifier
from sklearn.metrics import *
from matplotlib import pyplot as plt
from sklearn.tree import export_graphviz

from sklearn import tree

parser = argparse.ArgumentParser()

# Add argument
parser.add_argument('-i', required=True, help='path to training dataset')
parser.add_argument('-o', default=sys.stdout, help='file to output the decision tree')
args = parser.parse_args()

input = args.i
if args.o != sys.stdout:
    outputFile = open(args.o, "w") 


def convert_to_int(x: str):
    if isinstance(x, int):
        return x

    return int(x, 16)


Set1 = pd.read_csv(input)
Set1['eth_type'] = Set1['eth_type'].apply(convert_to_int)
Set1['ip_flags'] = Set1['eth_type'].apply(convert_to_int)
Set1['tcp_flags'] = Set1['eth_type'].apply(convert_to_int)
Set1['ip_proto'] = Set1[['ip_proto', 'ipv6_nxt']].max(axis=1)
Set1.insert(6, 'srcport', Set1[['tcp_srcport', 'udp_srcport']].max(axis=1))
Set1.insert(7, 'dstport', Set1[['tcp_dstport', 'udp_dstport']].max(axis=1))
Set1 = Set1.drop(
    columns=['tcp_srcport', 'udp_srcport', 'tcp_dstport', 'udp_dstport', 'ipv6_opt', 'tcp_flags', 'ipv6_nxt'])
print(Set1.columns)

Set = Set1.values.tolist()
X = [i[0:6] for i in Set]
Y = [i[6] for i in Set]
class_names = ['smart-static', 'sensor', 'audio', 'video', 'else']
feature_names = ['frame_len', 'eth_type', 'ip_proto', 'ip_flags', 'srcport',
                 'dstport', 'tcp_flags']

# prepare training and testing set
X = np.array(X)
Y = np.array(Y)

# decision tree fit

dt = DecisionTreeClassifier(max_depth=5)
dt.fit(X, Y)
Predict_Y = dt.predict(X)
print(np.mean(Predict_Y == Y))

fig = plt.gcf()
fig.set_size_inches(35.5, 20.5)
tree.plot_tree(dt, fontsize=10)

plt.show()

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
    else:
        is_leaves[node_id] = True

print("The binary tree structure has {n} nodes and has "
      "the following tree structure:".format(n=n_nodes))
for i in range(n_nodes):
    if is_leaves[i]:
        print("node={node} type=leaf depth={depth} class={cls}".format(
            depth=node_depth[i], node=i), file=outputFile, cls=class_names[np.argmax(value[i])])
    else:
        print("node={node} type=split depth={depth} feature={feature} "
              "threshold={threshold} left={left} right={right}".format(
                  depth=node_depth[i],
                  node=i,
                  left=children_left[i],
                  feature=feature_names[feature[i]],
                  threshold=threshold[i],
                  right=children_right[i]), file=outputFile)

# for i in range(n_nodes):
#     if is_leaves[i]:
#         """print("{space}node={node} is a leaf node. Parent = {parent}. value={value}。".format(
#             space=node_depth[i] * "\t",
#             node=i,
#             parent=node_parent[i],
#             value=class_names[np.argmax(value[i])]))"""
#         # print(
#         #    f"node={i},depth={node_depth[i]},parent={node_parent[i]},class={class_names[np.argmax(value[i])]},ParentNodeFeatureRange={node_parentRangeStr[i]}")
#         print(
#             f"table_add dt_level{node_depth[i]} action_for_class_{class_names[np.argmax(value[i])]} {node_parent[i]} {node_parentRangeStr[i]} => class={np.argmax(value[i])} 0"
#         )
#     else:
#         """print("{space}node={node} is a split node: "
#               "go to node {left} if X[:, {feature}] <= {threshold} "
#               "else to node {right}. Parent={parent}.".format(
#             space=node_depth[i] * "\t",
#             node=i,
#             left=children_left[i],
#             feature=feature[i],
#             threshold=threshold[i],
#             right=children_right[i],
#             parent=node_parent[i]))"""
#         # print(
#         #    f"node={i},depth={node_depth[i]},parent={node_parent[i]},featureCurrentNode={feature_names[feature[i]]},ParentNodeFeatureRange={node_parentRangeStr[i]}")
#         if (node_depth[i] == 0):
#             print(
#                 f"table_set_default dt_level{node_depth[i]} to_next_level => {i} {feature[i]} 0"
#             )
#             continue
#         print(
#             f"table_add dt_level{node_depth[i]} to_next_level {node_parent[i]} {node_parentRangeStr[i]} => {i} {feature[i]} 0"
#         )
