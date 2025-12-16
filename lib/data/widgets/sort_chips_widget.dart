import 'package:flutter/material.dart';

class SortChipsWidget extends StatelessWidget {
  final String currentSortBy;
  final bool isAscending;
  final Function(String, bool) onSortChanged;

  const SortChipsWidget({
    super.key,
    required this.currentSortBy,
    required this.isAscending,
    required this.onSortChanged,
  });

  Widget _buildSortChip(BuildContext context, String label, String sortBy) {
    final isSelected = currentSortBy == sortBy;

    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (isSelected) ...[
            const SizedBox(width: 4),
            Icon(
              isAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 14,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ],
        ],
      ),
      selected: isSelected,
      showCheckmark: false,
      onSelected: (selected) {
        // If clicking the same chip (already selected), toggle direction
        if (currentSortBy == sortBy) {
          onSortChanged(sortBy, !isAscending);
        } else if (selected) {
          // If selecting a new chip, default to ascending
          onSortChanged(sortBy, true);
        }
      },
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
      labelStyle: TextStyle(
        color: isSelected
            ? Theme.of(context).colorScheme.onPrimaryContainer
            : Theme.of(context).colorScheme.onSurface,
      ),
      visualDensity: VisualDensity.compact,
      labelPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          const Text('Sort by: ', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          _buildSortChip(context, 'Title', 'title'),
          const SizedBox(width: 8),
          _buildSortChip(context, 'Author', 'author'),
          const SizedBox(width: 8),
          _buildSortChip(context, 'Date', 'date'),
        ],
      ),
    );
  }
}
