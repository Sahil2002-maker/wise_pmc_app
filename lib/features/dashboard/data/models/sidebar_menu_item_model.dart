import 'package:flutter/material.dart';

class SidebarMenuItemModel {
  final IconData icon;
  final String title;
  final bool active;
  final VoidCallback? onTap;
  final List<SidebarMenuItemModel> children;
  final bool initiallyExpanded;

  const SidebarMenuItemModel({
    required this.icon,
    required this.title,
    this.active = false,
    this.onTap,
    this.children = const [],
    this.initiallyExpanded = false,
  });

  bool get hasChildren => children.isNotEmpty;

  SidebarMenuItemModel copyWith({
    IconData? icon,
    String? title,
    bool? active,
    VoidCallback? onTap,
    List<SidebarMenuItemModel>? children,
    bool? initiallyExpanded,
  }) {
    return SidebarMenuItemModel(
      icon: icon ?? this.icon,
      title: title ?? this.title,
      active: active ?? this.active,
      onTap: onTap ?? this.onTap,
      children: children ?? this.children,
      initiallyExpanded: initiallyExpanded ?? this.initiallyExpanded,
    );
  }
}