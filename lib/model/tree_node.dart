import 'package:flutter/material.dart';

class TreeNode<T> {
  final String key;
  final T? data;
  final Widget widget;
  List<TreeNode>? children;

  TreeNode({required this.key, this.data, required this.widget, this.children});

  void addChild({required TreeNode child}) {
    if (children == null) {
      children = [child];
    } else {
      children!.add(child);
    }
  }
}