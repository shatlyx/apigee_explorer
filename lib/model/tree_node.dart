import 'package:flutter/material.dart';

class TreeNode<T> {
  final String key;
  final T? data;
  final Widget widget;
  final Iterable<TreeNode>? children;

  TreeNode({required this.key, this.data, required this.widget, this.children});
}