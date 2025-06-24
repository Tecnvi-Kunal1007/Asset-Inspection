import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ComponentItem extends StatefulWidget {
  final String title;
  final String? subtitle;
  final String status;
  final String? note;
  final List<String> statusOptions;
  final Function(String) onStatusChanged;
  final Function(String?) onNoteChanged;
  final Function() onDelete;

  const ComponentItem({
    super.key,
    required this.title,
    this.subtitle,
    required this.status,
    this.note,
    required this.statusOptions,
    required this.onStatusChanged,
    required this.onNoteChanged,
    required this.onDelete,
  });

  @override
  State<ComponentItem> createState() => _ComponentItemState();
}

class _ComponentItemState extends State<ComponentItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _colorAnimation;
  late String currentStatus;
  String? currentNote;
  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    currentStatus = widget.status;
    currentNote = widget.note;
    _noteController.text = widget.note ?? '';
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _colorAnimation = ColorTween(
      begin: Colors.blue.shade100,
      end: Colors.transparent,
    ).animate(_controller);

    _controller.forward();
  }

  @override
  void didUpdateWidget(ComponentItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      setState(() {
        currentStatus = widget.status;
      });
      _controller.reset();
      _controller.forward();
    }
    if (oldWidget.note != widget.note) {
      setState(() {
        currentNote = widget.note;
        _noteController.text = widget.note ?? '';
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _showEditNoteDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Edit Note', style: GoogleFonts.poppins()),
            content: TextField(
              controller: _noteController,
              decoration: InputDecoration(
                hintText: 'Enter note',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              maxLines: 3,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final newNote =
                      _noteController.text.isEmpty
                          ? null
                          : _noteController.text;
                  setState(() {
                    currentNote = newNote;
                  });
                  widget.onNoteChanged(newNote);
                  Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _colorAnimation,
      builder: (context, child) {
        return Card(
          color: _colorAnimation.value,
          child: ListTile(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title),
                if (widget.subtitle != null)
                  Text(
                    widget.subtitle!,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                Text('Status: $currentStatus'),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (currentNote != null) ...[
                  Text('Note: $currentNote'),
                  const SizedBox(height: 4),
                ],
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      onPressed: _showEditNoteDialog,
                      icon: const Icon(Icons.edit_note, size: 16),
                      label: Text(
                        currentNote == null ? 'Add Note' : 'Edit Note',
                        style: GoogleFonts.poppins(fontSize: 12),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              itemBuilder:
                  (context) => [
                    ...widget.statusOptions.map(
                      (status) => PopupMenuItem(
                        value: status,
                        child: Text('Mark as $status'),
                      ),
                    ),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
              onSelected: (value) async {
                if (value == 'delete') {
                  widget.onDelete();
                } else {
                  setState(() {
                    currentStatus = value;
                  });
                  widget.onStatusChanged(value);
                }
              },
            ),
          ),
        );
      },
    );
  }
}
