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

  Widget _buildStatusToggleButtons() {
    return Container(
      height: 35,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Stack(
        children: [
          // Animated background
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color:
                  currentStatus == 'Working'
                      ? Colors.green.shade400
                      : currentStatus == 'Not Working'
                      ? Colors.red.shade400
                      : Colors.orange.shade400,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          // Toggle buttons
          Row(
            children: [
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      bottomLeft: Radius.circular(8),
                    ),
                    onTap: () {
                      setState(() {
                        currentStatus = 'Working';
                      });
                      widget.onStatusChanged('Working');
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(
                            color: Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Working',
                          style: GoogleFonts.poppins(
                            color:
                                currentStatus == 'Working'
                                    ? Colors.white
                                    : Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        currentStatus = 'Not Working';
                      });
                      widget.onStatusChanged('Not Working');
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(
                            color: Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Not\nWorking',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color:
                                currentStatus == 'Not Working'
                                    ? Colors.white
                                    : Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                    onTap: () {
                      setState(() {
                        currentStatus = 'Missing';
                      });
                      widget.onStatusChanged('Missing');
                    },
                    child: Center(
                      child: Text(
                        'Missing',
                        style: GoogleFonts.poppins(
                          color:
                              currentStatus == 'Missing'
                                  ? Colors.white
                                  : Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
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
          color: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and Delete Button Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          if (widget.subtitle != null)
                            Text(
                              widget.subtitle!,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete,
                        color: Colors.red,
                        size: 20,
                      ),
                      onPressed: widget.onDelete,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Status Label
                Text(
                  'Status:',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 4),

                // Status Toggle Buttons
                _buildStatusToggleButtons(),

                const SizedBox(height: 8),

                // Note Section
                if (currentNote != null) ...[
                  Text(
                    'Note: $currentNote',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],

                // Edit Note Button
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
          ),
        );
      },
    );
  }
}
