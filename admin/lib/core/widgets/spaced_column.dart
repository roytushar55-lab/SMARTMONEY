import 'package:flutter/material.dart';

/// Inserts a fixed gap between each child — form dialogs kept listing
/// TextFormFields back-to-back with no spacing, which crammed labels into
/// the field above once the theme's input padding got tighter.
List<Widget> withGaps(List<Widget> children, {double gap = 14}) {
  final spaced = <Widget>[];
  for (var i = 0; i < children.length; i++) {
    if (i > 0) spaced.add(SizedBox(height: gap));
    spaced.add(children[i]);
  }
  return spaced;
}
