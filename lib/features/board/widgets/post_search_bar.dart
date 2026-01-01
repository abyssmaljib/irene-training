import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// Search bar สำหรับค้นหาโพส
class PostSearchBar extends StatefulWidget {
  final String initialQuery;
  final ValueChanged<String> onSearch;
  final VoidCallback? onClear;

  const PostSearchBar({
    super.key,
    this.initialQuery = '',
    required this.onSearch,
    this.onClear,
  });

  @override
  State<PostSearchBar> createState() => _PostSearchBarState();
}

class _PostSearchBarState extends State<PostSearchBar> {
  late TextEditingController _controller;
  bool _showClear = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    _showClear = widget.initialQuery.isNotEmpty;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final query = _controller.text.trim();
    widget.onSearch(query);
  }

  void _handleClear() {
    _controller.clear();
    setState(() => _showClear = false);
    widget.onSearch('');
    widget.onClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _controller,
        decoration: InputDecoration(
          hintText: 'ค้นหาโพส...',
          hintStyle: AppTypography.body.copyWith(color: AppColors.secondaryText),
          prefixIcon: Icon(Iconsax.search_normal, color: AppColors.secondaryText),
          suffixIcon: _showClear
              ? IconButton(
                  icon: Icon(Iconsax.close_circle, color: AppColors.secondaryText),
                  onPressed: _handleClear,
                )
              : null,
          filled: true,
          fillColor: AppColors.background,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide(color: AppColors.primary, width: 1),
          ),
        ),
        style: AppTypography.body,
        textInputAction: TextInputAction.search,
        onChanged: (value) {
          setState(() => _showClear = value.isNotEmpty);
        },
        onSubmitted: (_) => _handleSubmit(),
      ),
    );
  }
}
