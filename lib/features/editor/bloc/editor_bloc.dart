import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:image_editor/image_editor.dart';
import 'package:flutter_bicubic_resize/flutter_bicubic_resize.dart';

// Events
abstract class EditorEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadImageEvent extends EditorEvent {
  final String imagePath;
  LoadImageEvent(this.imagePath);
  
  @override
  List<Object?> get props => [imagePath];
}

class ApplyEditEvent extends EditorEvent {
  final ImageEditorOption option;
  ApplyEditEvent(this.option);
  
  @override
  List<Object?> get props => [option];
}

class UndoEvent extends EditorEvent {}
class RedoEvent extends EditorEvent {}

class ResetEvent extends EditorEvent {}

// States
class EditorState extends Equatable {
  final Uint8List? originalImage; // High-res image
  final Uint8List? currentImage;  // Display-scale image (e.g. 1200px)
  final List<Uint8List> history;
  final List<Uint8List> redoStack;
  final bool isLoading;
  final String? error;

  const EditorState({
    this.originalImage,
    this.currentImage,
    this.history = const [],
    this.redoStack = const [],
    this.isLoading = false,
    this.error,
  });

  EditorState copyWith({
    Uint8List? originalImage,
    Uint8List? currentImage,
    List<Uint8List>? history,
    List<Uint8List>? redoStack,
    bool? isLoading,
    String? error,
  }) {
    return EditorState(
      originalImage: originalImage ?? this.originalImage,
      currentImage: currentImage ?? this.currentImage,
      history: history ?? this.history,
      redoStack: redoStack ?? this.redoStack,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  @override
  List<Object?> get props => [originalImage, currentImage, history, redoStack, isLoading, error];
}

// BLoC
class EditorBloc extends Bloc<EditorEvent, EditorState> {
  EditorBloc() : super(const EditorState()) {
    on<LoadImageEvent>(_onLoadImage);
    on<ApplyEditEvent>(_onApplyEdit);
    on<UndoEvent>(_onUndo);
    on<RedoEvent>(_onRedo);
    on<ResetEvent>(_onReset);
  }

  Future<void> _onLoadImage(LoadImageEvent event, Emitter<EditorState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final bytes = await File(event.imagePath).readAsBytes();
      
      // OPTIMIZATION: Create a "Working Image" at 1200px max for editing performance
      // Using BicubicResizer for high-quality downscaling
      final displayBytes = await BicubicResizer.resizeJpegAsync(
        jpegBytes: bytes,
        outputWidth: 1200, 
        outputHeight: 1200,
        quality: 90,
      );

      emit(state.copyWith(
        originalImage: bytes,
        currentImage: displayBytes,
        history: [displayBytes],
        redoStack: [],
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: 'Failed to load image: ${e.toString()}'));
    }
  }

  void _onReset(ResetEvent event, Emitter<EditorState> emit) {
    if (state.history.isNotEmpty) {
      final original = state.history.first;
      emit(state.copyWith(
        currentImage: original,
        history: [original],
        redoStack: [],
      ));
    }
  }

  Future<void> _onApplyEdit(ApplyEditEvent event, Emitter<EditorState> emit) async {
    if (state.currentImage == null) return;
    
    emit(state.copyWith(isLoading: true));
    try {
      final Uint8List? result = await ImageEditor.editImage(
        image: state.currentImage!,
        imageEditorOption: event.option,
      );
      
      if (result != null) {
        final newHistory = List<Uint8List>.from(state.history)..add(result);
        emit(state.copyWith(
          currentImage: result,
          history: newHistory,
          redoStack: [],
          isLoading: false,
        ));
      } else {
        emit(state.copyWith(isLoading: false, error: 'Edit failed.'));
      }
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  void _onUndo(UndoEvent event, Emitter<EditorState> emit) {
    if (state.history.length > 1) {
      final newHistory = List<Uint8List>.from(state.history);
      final current = newHistory.removeLast();
      final previous = newHistory.last;
      
      final newRedoStack = List<Uint8List>.from(state.redoStack)..add(current);
      
      emit(state.copyWith(
        currentImage: previous,
        history: newHistory,
        redoStack: newRedoStack,
      ));
    }
  }

  void _onRedo(RedoEvent event, Emitter<EditorState> emit) {
    if (state.redoStack.isNotEmpty) {
      final newRedoStack = List<Uint8List>.from(state.redoStack);
      final redoImage = newRedoStack.removeLast();
      
      final newHistory = List<Uint8List>.from(state.history)..add(redoImage);
      
      emit(state.copyWith(
        currentImage: redoImage,
        history: newHistory,
        redoStack: newRedoStack,
      ));
    }
  }
}
