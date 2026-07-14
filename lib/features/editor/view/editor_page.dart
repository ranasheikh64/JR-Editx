import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:extended_image/extended_image.dart';
import 'package:image_editor/image_editor.dart';
import '../bloc/editor_bloc.dart';
import 'package:saver_gallery/saver_gallery.dart';
import '../../../core/utils/filter_utils.dart';
import 'package:flutter_bicubic_resize/flutter_bicubic_resize.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'dart:ui' as ui;

class EditorPage extends StatelessWidget {
  final String? imagePath;
  const EditorPage({super.key, this.imagePath});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final bloc = EditorBloc();
        if (imagePath != null) {
          bloc.add(LoadImageEvent(imagePath!));
        }
        return bloc;
      },
      child: const EditorView(),
    );
  }
}

class EditorView extends StatefulWidget {
  const EditorView({super.key});

  @override
  State<EditorView> createState() => _EditorViewState();
}

class _EditorViewState extends State<EditorView> {
  final GlobalKey<ExtendedImageEditorState> _editorKey = GlobalKey<ExtendedImageEditorState>();
  String _currentTool = 'none';
  double _brightness = 1.0;
  double _contrast = 1.0;

  // Drawing state
  final List<List<Offset?>> _points = [];
  Color _drawColor = Colors.red;
  double _strokeWidth = 5.0;

  double? _cropAspectRatio;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          BlocBuilder<EditorBloc, EditorState>(
            builder: (context, state) {
              return Row(
                children: [
                   IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => context.read<EditorBloc>().add(ResetEvent()),
                  ),
                  IconButton(
                    icon: const Icon(Icons.undo),
                    onPressed: state.history.length > 1
                        ? () => context.read<EditorBloc>().add(UndoEvent())
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.redo),
                    onPressed: state.redoStack.isNotEmpty
                        ? () => context.read<EditorBloc>().add(RedoEvent())
                        : null,
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _saveImage,
                    child: const Text('SAVE NOW', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: BlocBuilder<EditorBloc, EditorState>(
              builder: (context, state) {
                if (state.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.currentImage == null) {
                  return const Center(child: Text('No image loaded'));
                }

                Widget imageWidget;
                if (_currentTool == 'crop') {
                  imageWidget = ExtendedImage.memory(
                    state.currentImage!,
                    fit: BoxFit.contain,
                    mode: ExtendedImageMode.editor,
                    extendedImageEditorKey: _editorKey,
                    initEditorConfigHandler: (state) {
                      return EditorConfig(
                        maxScale: 8.0,
                        cropRectPadding: const EdgeInsets.all(20.0),
                        hitTestSize: 20.0,
                        initialCropAspectRatio: _cropAspectRatio,
                      );
                    },
                  );
                } else {
                  imageWidget = ExtendedImage.memory(
                    state.currentImage!,
                    fit: BoxFit.contain,
                    mode: ExtendedImageMode.gesture,
                  );
                }

                return Stack(
                  children: [
                    imageWidget,
                    if (_currentTool == 'draw')
                      GestureDetector(
                        onPanStart: (details) {
                          setState(() {
                            _points.add([details.localPosition]);
                          });
                        },
                        onPanUpdate: (details) {
                          setState(() {
                            _points.last.add(details.localPosition);
                          });
                        },
                        onPanEnd: (_) {
                          setState(() {
                            _points.last.add(null);
                          });
                        },
                        child: CustomPaint(
                          painter: DrawingPainter(
                            points: _points,
                            color: _drawColor,
                            strokeWidth: _strokeWidth,
                          ),
                          size: Size.infinite,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          _buildToolbar(),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_currentTool == 'filters') _buildFilterControls(),
            if (_currentTool == 'draw') _buildDrawControls(),
            if (_currentTool == 'adjust') _buildAdjustControls(),
            if (_currentTool == 'crop') _buildCropControls(),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _toolButton(Icons.crop_rotate, 'Crop', 'crop'),
                  _toolButton(Icons.filter_hdr, 'Filters', 'filters'),
                  _toolButton(Icons.tune, 'Adjust', 'adjust'),
                  _toolButton(Icons.text_fields, 'Text', 'text_tap'),
                  _toolButton(Icons.brush, 'Draw', 'draw'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolButton(IconData icon, String label, String toolId) {
    final isSelected = _currentTool == toolId;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () {
          if (toolId == 'text_tap') {
            _showTextDialog();
            return;
          }
          setState(() {
            _currentTool = isSelected ? 'none' : toolId;
          });
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 12, color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white)),
          ],
        ),
      ),
    );
  }


  Widget _buildFilterControls() {
    return BlocBuilder<EditorBloc, EditorState>(
      builder: (context, state) {
        if (state.currentImage == null) return const SizedBox();
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: FilterUtils.allFilters.entries.map((entry) {
              return GestureDetector(
                onTap: () => _applyFilter(entry.value),
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  child: Column(
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24, width: 2),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ColorFiltered(
                          colorFilter: ColorFilter.matrix(entry.value.isEmpty ? FilterUtils.none : entry.value),
                          child: Image.memory(state.currentImage!, fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(entry.key, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildDrawControls() {
     return Padding(
       padding: const EdgeInsets.symmetric(horizontal: 16),
       child: Row(
         children: [
           GestureDetector(
             onTap: _showColorPicker,
             child: Container(
               width: 30,
               height: 30,
               decoration: BoxDecoration(color: _drawColor, shape: BoxShape.circle, border: Border.all(color: Colors.white)),
             ),
           ),
           Expanded(
             child: Slider(
               value: _strokeWidth,
               min: 1,
               max: 20,
               onChanged: (v) => setState(() => _strokeWidth = v),
             ),
           ),
           IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => setState(() => _points.clear())),
         ],
       ),
     );
  }

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pick a color'),
        content: SingleChildScrollView(
          child: BlockPicker(
            pickerColor: _drawColor,
            onColorChanged: (color) {
              setState(() => _drawColor = color);
              Navigator.of(context).pop();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAdjustControls() {
    return Column(
      children: [
        _adjustmentSlider(label: 'Brightness', value: _brightness, min: 0.0, max: 2.0, onChanged: (v) => setState(() => _brightness = v), onFinished: _applyAdjustments),
        _adjustmentSlider(label: 'Contrast', value: _contrast, min: 0.0, max: 2.0, onChanged: (v) => setState(() => _contrast = v), onFinished: _applyAdjustments),
      ],
    );
  }

  Widget _adjustmentSlider({required String label, required double value, required double min, required double max, required ValueChanged<double> onChanged, required VoidCallback onFinished}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 12))),
          Expanded(
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
              onChangeEnd: (_) => onFinished(),
            ),
          ),
          SizedBox(width: 30, child: Text(value.toStringAsFixed(1), style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  void _applyFilter(List<double> matrix) {
    if (matrix.isEmpty) {
      context.read<EditorBloc>().add(ResetEvent());
      return;
    }
    final option = ImageEditorOption();
    option.addOption(ColorOption(matrix: matrix));
    context.read<EditorBloc>().add(ApplyEditEvent(option));
  }

  void _applyAdjustments() {
     final option = ImageEditorOption();
     ColorOption colorOption = ColorOption.brightness(_brightness);
     colorOption = colorOption.concat(ColorOption.contrast(_contrast));
     
     option.addOption(colorOption);
     context.read<EditorBloc>().add(ApplyEditEvent(option));
  }

  Widget _buildCropControls() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _cropActionChip('Free', null),
          _cropActionChip('1:1', 1.0),
          _cropActionChip('16:9', 16 / 9),
          _cropActionChip('4:3', 4 / 3),
          const SizedBox(width: 8, height: 30, child: VerticalDivider()),
          IconButton(icon: const Icon(Icons.rotate_left), onPressed: () => _editorKey.currentState?.rotate(degree: -90)),
          IconButton(icon: const Icon(Icons.rotate_right), onPressed: () => _editorKey.currentState?.rotate(degree: 90)),
          const SizedBox(width: 8),
          ElevatedButton(onPressed: _applyCrop, child: const Text('APPLY')),
        ],
      ),
    );
  }

  Widget _cropActionChip(String label, double? ratio) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 10)),
        onPressed: () {
          setState(() {
            _cropAspectRatio = ratio;
          });
        },
      ),
    );
  }

  void _applyCrop() async {
    final state = _editorKey.currentState;
    if (state == null) return;

    final cropRect = state.getCropRect();
    if (cropRect == null) return;
    
    final action = ClipOption(
      x: cropRect.left.toInt(),
      y: cropRect.top.toInt(),
      width: cropRect.width.toInt(),
      height: cropRect.height.toInt(),
    );

    final option = ImageEditorOption();
    option.addOption(action);

    context.read<EditorBloc>().add(ApplyEditEvent(option));
    setState(() => _currentTool = 'none');
  }

  void _showTextDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Text'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter text here'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (controller.text.isNotEmpty) {
                _applyText(controller.text);
              }
            },
            child: const Text('ADD'),
          ),
        ],
      ),
    );
  }

  void _applyText(String text) {
    final option = ImageEditorOption();
    option.addOption(AddTextOption()
      ..addText(EditorText(
        text: text,
        offset: const Offset(100, 100),
        fontSizePx: 50,
        textColor: Colors.white,
      )));
    context.read<EditorBloc>().add(ApplyEditEvent(option));
  }

  void _saveImage() async {
    final state = context.read<EditorBloc>().state;
    if (state.currentImage == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Use the edited current image from state for export
      final exportBytes = state.currentImage!;
      
      // Decode image dimensions to preserve aspect ratio
      final ui.Codec codec = await ui.instantiateImageCodec(exportBytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final double aspectRatio = frameInfo.image.width / frameInfo.image.height;
      
      int targetWidth, targetHeight;
      const int maxDimension = 2500;

      if (aspectRatio > 1) {
        targetWidth = maxDimension;
        targetHeight = (maxDimension / aspectRatio).round();
      } else {
        targetHeight = maxDimension;
        targetWidth = (maxDimension * aspectRatio).round();
      }
      
      final bytes = await BicubicResizer.resizeJpegAsync(
        jpegBytes: exportBytes,
        outputWidth: targetWidth, 
        outputHeight: targetHeight,
        quality: 95,
        filter: BicubicFilter.catmullRom,
      );

      final result = await SaverGallery.saveImage(
        bytes,
        quality: 100,
        fileName: "photo_editor_${DateTime.now().millisecondsSinceEpoch}.jpg",
        skipIfExists: false,
      );

      if (mounted) Navigator.of(context).pop();

      if (result.isSuccess) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image saved to gallery!')));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save image')));
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}

class DrawingPainter extends CustomPainter {
  final List<List<Offset?>> points;
  final Color color;
  final double strokeWidth;

  DrawingPainter({required this.points, required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    for (final line in points) {
      final paint = Paint()
        ..color = color
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke;

      for (int i = 0; i < line.length - 1; i++) {
        if (line[i] != null && line[i + 1] != null) {
          canvas.drawLine(line[i]!, line[i + 1]!, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant DrawingPainter oldDelegate) => true;
}
