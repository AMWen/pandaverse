import 'package:flutter/material.dart';

class SearchBarWidget extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final String searchQuery;
  final Function(String) onChanged;

  const SearchBarWidget({
    super.key,
    required this.controller,
    required this.hintText,
    required this.searchQuery,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.onSurfaceVariant),
          suffixIcon: searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          contentPadding: EdgeInsets.zero,
        ),
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        onChanged: onChanged,
      ),
    );
  }
}
