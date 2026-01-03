import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/input_fields.dart';

/// Search bar สำหรับค้นหาโพส
class PostSearchBar extends StatefulWidget {
  final String initialQuery;
  final ValueChanged<String> onSearch;
  final VoidCallback? onClear;
  final FocusNode? focusNode;

  const PostSearchBar({
    super.key,
    this.initialQuery = '',
    required this.onSearch,
    this.onClear,
    this.focusNode,
  });

  @override
  State<PostSearchBar> createState() => _PostSearchBarState();
}

class _PostSearchBarState extends State<PostSearchBar> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleClear() {
    _controller.clear();
    widget.onSearch('');
    widget.onClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: SearchField(
        controller: _controller,
        hintText: 'ค้นหาโพส...',
        isDense: true,
        focusNode: widget.focusNode,
        onChanged: widget.onSearch,
        onClear: _handleClear,
      ),
    );
  }
}
