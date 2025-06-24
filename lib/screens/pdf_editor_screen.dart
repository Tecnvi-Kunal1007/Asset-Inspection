import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../services/supabase_service.dart';

class PdfEditorScreen extends StatefulWidget {
  final String pdfUrl;
  final String areaName;
  final String areaId;

  const PdfEditorScreen({
    super.key,
    required this.pdfUrl,
    required this.areaName,
    required this.areaId,
  });

  @override
  State<PdfEditorScreen> createState() => _PdfEditorScreenState();
}

class _PdfEditorScreenState extends State<PdfEditorScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _editedPdfPath;
  final _commentController = TextEditingController();
  List<String> _comments = [];
  late PdfDocument _document;
  final _pdfViewerKey = GlobalKey<SfPdfViewerState>();
  final _imagePicker = ImagePicker();
  final _supabaseService = SupabaseService();
  List<Map<String, dynamic>> _annotations = [];
  bool _isDrawing = false;
  Offset? _startPoint;
  List<Offset> _currentDrawing = [];
  Color _selectedColor = Colors.red;
  double _strokeWidth = 2.0;
  bool _isHighlighting = false;
  bool _isAddingSignature = false;
  bool _isErasing = false;
  bool _isRepositioning = false;
  int _currentPage = 0;
  Uint8List? _currentPdfBytes;
  Offset? _dragStartPosition;
  Rect? _selectedElementRect;
  Map<String, dynamic>? _selectedElement;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _document.dispose();
    super.dispose();
  }

  Future<void> _loadPdf() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final response = await http.get(Uri.parse(widget.pdfUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to download PDF');
      }

      _document = PdfDocument(inputBytes: response.bodyBytes);
      _currentPdfBytes = Uint8List.fromList(response.bodyBytes);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading PDF: $e')));
    }
  }

  Future<void> _addImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );
      if (image == null) return;

      final bytes = await image.readAsBytes();
      final imageData = PdfBitmap(bytes);

      // Create a new document with the image
      final newDocument = PdfDocument(inputBytes: _currentPdfBytes!);
      final page = newDocument.pages[_currentPage];
      final graphics = page.graphics;

      // Add image to the current page with a unique ID
      final imageId = DateTime.now().millisecondsSinceEpoch.toString();
      graphics.drawImage(imageData, Rect.fromLTWH(50, 50, 300, 200));

      _annotations.add({
        'id': imageId,
        'type': 'image',
        'rect': Rect.fromLTWH(50, 50, 300, 200),
        'data': bytes,
      });

      // Save the modified document
      final modifiedBytes = await newDocument.save();
      newDocument.dispose();

      setState(() {
        _currentPdfBytes = Uint8List.fromList(modifiedBytes);
        _document = PdfDocument(inputBytes: _currentPdfBytes!);
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Image added successfully')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error adding image: $e')));
    }
  }

  Future<void> _addText() async {
    if (_commentController.text.isEmpty) return;

    try {
      // Create a new document with the text
      final newDocument = PdfDocument(inputBytes: _currentPdfBytes!);
      final page = newDocument.pages[_currentPage];
      final graphics = page.graphics;

      // Add text to the current page with a unique ID
      final textId = DateTime.now().millisecondsSinceEpoch.toString();
      final brush = PdfSolidBrush(
        PdfColor(_selectedColor.red, _selectedColor.green, _selectedColor.blue),
      );
      final font = PdfStandardFont(PdfFontFamily.helvetica, 12);
      graphics.drawString(
        _commentController.text,
        font,
        brush: brush,
        bounds: Rect.fromLTWH(50, 50, 500, 100),
      );

      _annotations.add({
        'id': textId,
        'type': 'text',
        'text': _commentController.text,
        'rect': Rect.fromLTWH(50, 50, 500, 100),
        'color': _selectedColor,
      });

      // Save the modified document
      final modifiedBytes = await newDocument.save();
      newDocument.dispose();

      setState(() {
        _currentPdfBytes = Uint8List.fromList(modifiedBytes);
        _document = PdfDocument(inputBytes: _currentPdfBytes!);
        _commentController.clear();
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Text added successfully')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error adding text: $e')));
    }
  }

  Future<void> _eraseElement() async {
    if (_selectedElement == null) return;

    try {
      // Create a new document without the selected element
      final newDocument = PdfDocument(inputBytes: _currentPdfBytes!);
      final page = newDocument.pages[_currentPage];
      final graphics = page.graphics;

      // Redraw all elements except the selected one
      for (final annotation in _annotations) {
        if (annotation['id'] != _selectedElement!['id']) {
          if (annotation['type'] == 'text') {
            final brush = PdfSolidBrush(
              PdfColor(
                annotation['color'].red,
                annotation['color'].green,
                annotation['color'].blue,
              ),
            );
            final font = PdfStandardFont(PdfFontFamily.helvetica, 12);
            graphics.drawString(
              annotation['text'],
              font,
              brush: brush,
              bounds: annotation['rect'],
            );
          } else if (annotation['type'] == 'image') {
            final imageData = PdfBitmap(annotation['data']);
            graphics.drawImage(imageData, annotation['rect']);
          }
        }
      }

      // Remove the selected element from annotations
      _annotations.removeWhere((a) => a['id'] == _selectedElement!['id']);

      // Save the modified document
      final modifiedBytes = await newDocument.save();
      newDocument.dispose();

      setState(() {
        _currentPdfBytes = Uint8List.fromList(modifiedBytes);
        _document = PdfDocument(inputBytes: _currentPdfBytes!);
        _selectedElement = null;
        _selectedElementRect = null;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Element erased successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error erasing element: $e')));
    }
  }

  Future<void> _reorderPages() async {
    try {
      if (_document.pages.count <= 1) return;

      // Show a dialog to select pages to reorder
      final result = await showDialog<Map<String, int>>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Reorder Pages'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: 'Move Page'),
                    items: List.generate(
                      _document.pages.count,
                      (index) => DropdownMenuItem(
                        value: index,
                        child: Text('Page ${index + 1}'),
                      ),
                    ),
                    onChanged: (value) {
                      Navigator.pop(context, {'from': value!});
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: 'To Position'),
                    items: List.generate(
                      _document.pages.count,
                      (index) => DropdownMenuItem(
                        value: index,
                        child: Text('Position ${index + 1}'),
                      ),
                    ),
                    onChanged: (value) {
                      Navigator.pop(context, {'to': value!});
                    },
                  ),
                ],
              ),
            ),
      );

      if (result == null) return;

      // Create a new document with reordered pages
      final newDocument = PdfDocument();
      for (int i = 0; i < _document.pages.count; i++) {
        if (i == result['from']) continue;
        final page = newDocument.pages.add();
        final template = _document.pages[i].createTemplate();
        page.graphics?.drawPdfTemplate(template, Offset.zero);
      }

      // Insert the moved page at the new position
      final movedPage = newDocument.pages.insert(result['to']!);
      final movedTemplate = _document.pages[result['from']!].createTemplate();
      movedPage.graphics?.drawPdfTemplate(movedTemplate, Offset.zero);

      // Save the modified document
      final modifiedBytes = await newDocument.save();
      newDocument.dispose();

      setState(() {
        _currentPdfBytes = Uint8List.fromList(modifiedBytes);
        _document = PdfDocument(inputBytes: _currentPdfBytes!);
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pages reordered successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error reordering pages: $e')));
    }
  }

  Future<void> _addSignature() async {
    try {
      final XFile? signature = await _imagePicker.pickImage(
        source: ImageSource.camera,
      );
      if (signature == null) return;

      final bytes = await signature.readAsBytes();
      final imageData = PdfBitmap(bytes);

      // Create a new document with the signature
      final newDocument = PdfDocument(inputBytes: _currentPdfBytes!);
      final page = newDocument.pages[_currentPage];
      final graphics = page.graphics;

      // Add signature to the current page with a unique ID
      final signatureId = DateTime.now().millisecondsSinceEpoch.toString();
      graphics.drawImage(imageData, Rect.fromLTWH(50, 50, 200, 100));

      _annotations.add({
        'id': signatureId,
        'type': 'image',
        'rect': Rect.fromLTWH(50, 50, 200, 100),
        'data': bytes,
      });

      // Save the modified document
      final modifiedBytes = await newDocument.save();
      newDocument.dispose();

      setState(() {
        _currentPdfBytes = Uint8List.fromList(modifiedBytes);
        _document = PdfDocument(inputBytes: _currentPdfBytes!);
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signature added successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error adding signature: $e')));
    }
  }

  Future<void> _saveChanges() async {
    try {
      setState(() {
        _isSaving = true;
      });

      // Save to temporary file
      final tempDir = await getTemporaryDirectory();
      final editedFile = File('${tempDir.path}/edited_${widget.areaName}.pdf');
      await editedFile.writeAsBytes(_currentPdfBytes!);

      // Upload to Supabase
      await _supabaseService.uploadAreaReport(widget.areaId, editedFile);

      setState(() {
        _editedPdfPath = editedFile.path;
        _isSaving = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Changes saved successfully')),
      );
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving changes: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit PDF Report', style: GoogleFonts.poppins()),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isSaving ? null : _saveChanges,
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      border: Border(
                        bottom: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.text_fields),
                            onPressed: _addText,
                            tooltip: 'Add Text',
                          ),
                          IconButton(
                            icon: const Icon(Icons.image),
                            onPressed: _addImage,
                            tooltip: 'Add Image',
                          ),
                          IconButton(
                            icon: const Icon(Icons.draw),
                            onPressed: () {
                              setState(() {
                                _isDrawing = !_isDrawing;
                              });
                            },
                            tooltip: 'Draw',
                            color: _isDrawing ? Colors.blue : null,
                          ),
                          IconButton(
                            icon: const Icon(Icons.highlight),
                            onPressed: () {
                              setState(() {
                                _isHighlighting = !_isHighlighting;
                              });
                            },
                            tooltip: 'Highlight',
                            color: _isHighlighting ? Colors.blue : null,
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_document),
                            onPressed: _addSignature,
                            tooltip: 'Add Signature',
                          ),
                          IconButton(
                            icon: const Icon(Icons.reorder),
                            onPressed: _reorderPages,
                            tooltip: 'Reorder Pages',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: _isErasing ? null : _eraseElement,
                            tooltip: 'Erase',
                            color: _isErasing ? Colors.blue : null,
                          ),
                          IconButton(
                            icon: const Icon(Icons.open_with),
                            onPressed: () {
                              setState(() {
                                _isRepositioning = !_isRepositioning;
                              });
                            },
                            tooltip: 'Reposition',
                            color: _isRepositioning ? Colors.blue : null,
                          ),
                          IconButton(
                            icon: const Icon(Icons.color_lens),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder:
                                    (context) => AlertDialog(
                                      title: const Text('Select Color'),
                                      content: SingleChildScrollView(
                                        child: ColorPicker(
                                          pickerColor: _selectedColor,
                                          onColorChanged: (color) {
                                            setState(() {
                                              _selectedColor = color;
                                            });
                                          },
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed:
                                              () => Navigator.pop(context),
                                          child: const Text('Done'),
                                        ),
                                      ],
                                    ),
                              );
                            },
                            tooltip: 'Color',
                          ),
                          IconButton(
                            icon: const Icon(Icons.line_weight),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder:
                                    (context) => AlertDialog(
                                      title: const Text('Select Line Width'),
                                      content: Slider(
                                        value: _strokeWidth,
                                        min: 1,
                                        max: 10,
                                        divisions: 9,
                                        label: _strokeWidth.round().toString(),
                                        onChanged: (value) {
                                          setState(() {
                                            _strokeWidth = value;
                                          });
                                        },
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed:
                                              () => Navigator.pop(context),
                                          child: const Text('Done'),
                                        ),
                                      ],
                                    ),
                              );
                            },
                            tooltip: 'Line Width',
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onPanStart: (details) {
                        if (_isRepositioning && _selectedElement != null) {
                          _dragStartPosition = details.localPosition;
                        }
                      },
                      onPanUpdate: (details) {
                        if (_isRepositioning &&
                            _selectedElement != null &&
                            _dragStartPosition != null) {
                          final dx =
                              details.localPosition.dx - _dragStartPosition!.dx;
                          final dy =
                              details.localPosition.dy - _dragStartPosition!.dy;

                          setState(() {
                            _selectedElementRect = Rect.fromLTWH(
                              _selectedElementRect!.left + dx,
                              _selectedElementRect!.top + dy,
                              _selectedElementRect!.width,
                              _selectedElementRect!.height,
                            );
                            _dragStartPosition = details.localPosition;
                          });
                        }
                      },
                      onPanEnd: (details) {
                        if (_isRepositioning && _selectedElement != null) {
                          _dragStartPosition = null;
                          // Update the element's position in the PDF
                          _updateElementPosition();
                        }
                      },
                      child: SfPdfViewer.memory(
                        _currentPdfBytes!,
                        key: _pdfViewerKey,
                        enableDoubleTapZooming: true,
                        enableTextSelection: true,
                        canShowScrollHead: true,
                        canShowScrollStatus: true,
                        enableDocumentLinkAnnotation: true,
                        onPageChanged: (PdfPageChangedDetails details) {
                          setState(() {
                            _currentPage = details.newPageNumber - 1;
                          });
                        },
                      ),
                    ),
                  ),
                  if (!_isDrawing)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            spreadRadius: 1,
                            blurRadius: 3,
                            offset: const Offset(0, -1),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _commentController,
                              decoration: InputDecoration(
                                hintText: 'Add a comment...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              maxLines: 2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.send),
                            onPressed: _addText,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
    );
  }

  Future<void> _updateElementPosition() async {
    if (_selectedElement == null || _selectedElementRect == null) return;

    try {
      // Create a new document with the updated element position
      final newDocument = PdfDocument(inputBytes: _currentPdfBytes!);
      final page = newDocument.pages[_currentPage];
      final graphics = page.graphics;

      // Update the element's position in annotations
      final index = _annotations.indexWhere(
        (a) => a['id'] == _selectedElement!['id'],
      );
      if (index != -1) {
        _annotations[index]['rect'] = _selectedElementRect;
      }

      // Redraw all elements with updated positions
      for (final annotation in _annotations) {
        if (annotation['type'] == 'text') {
          final brush = PdfSolidBrush(
            PdfColor(
              annotation['color'].red,
              annotation['color'].green,
              annotation['color'].blue,
            ),
          );
          final font = PdfStandardFont(PdfFontFamily.helvetica, 12);
          graphics.drawString(
            annotation['text'],
            font,
            brush: brush,
            bounds: annotation['rect'],
          );
        } else if (annotation['type'] == 'image') {
          final imageData = PdfBitmap(annotation['data']);
          graphics.drawImage(imageData, annotation['rect']);
        }
      }

      // Save the modified document
      final modifiedBytes = await newDocument.save();
      newDocument.dispose();

      setState(() {
        _currentPdfBytes = Uint8List.fromList(modifiedBytes);
        _document = PdfDocument(inputBytes: _currentPdfBytes!);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating element position: $e')),
      );
    }
  }
}

class ColorPicker extends StatelessWidget {
  final Color pickerColor;
  final Function(Color) onColorChanged;

  const ColorPicker({
    super.key,
    required this.pickerColor,
    required this.onColorChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
          [
            Colors.red,
            Colors.orange,
            Colors.yellow,
            Colors.green,
            Colors.blue,
            Colors.indigo,
            Colors.purple,
            Colors.black,
          ].map((color) {
            return GestureDetector(
              onTap: () => onColorChanged(color),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: pickerColor == color ? Colors.white : Colors.grey,
                    width: 2,
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }
}
