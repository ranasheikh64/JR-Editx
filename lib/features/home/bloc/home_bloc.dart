import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:equatable/equatable.dart';
import 'package:photo_manager/photo_manager.dart';

// Events
abstract class HomeEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class PickImageEvent extends HomeEvent {
  final ImageSource source;
  PickImageEvent(this.source);

  @override
  List<Object?> get props => [source];
}

class LoadGalleryImagesEvent extends HomeEvent {}

class ClearSelectionEvent extends HomeEvent {}

// States
class HomeState extends Equatable {
  final List<AssetEntity> assets;
  final bool isLoading;
  final String? error;
  final String? selectedImagePath; // To trigger navigation

  const HomeState({
    this.assets = const [],
    this.isLoading = false,
    this.error,
    this.selectedImagePath,
  });

  HomeState copyWith({
    List<AssetEntity>? assets,
    bool? isLoading,
    String? error,
    String? selectedImagePath,
  }) {
    return HomeState(
      assets: assets ?? this.assets,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedImagePath: selectedImagePath,
    );
  }

  @override
  List<Object?> get props => [assets, isLoading, error, selectedImagePath];
}

// BLoC
class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final ImagePicker _picker = ImagePicker();

  HomeBloc() : super(const HomeState()) {
    on<PickImageEvent>(_onPickImage);
    on<LoadGalleryImagesEvent>(_onLoadGallery);
    on<ClearSelectionEvent>(
      (event, emit) => emit(state.copyWith(selectedImagePath: null)),
    );
  }

  Future<void> _onLoadGallery(
    LoadGalleryImagesEvent event,
    Emitter<HomeState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    try {
      final PermissionState ps = await PhotoManager.requestPermissionExtend();
      
      // On Android 14+ (API 34), users can grant partial access ('limited')
      if (ps.isAuth) {
        // If limited, we might want to show a message, but for now we just load what we can
        final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
          type: RequestType.image,
          filterOption: FilterOptionGroup(
            imageOption: const FilterOption(
              sizeConstraint: SizeConstraint(ignoreSize: true),
            ),
          ),
        );

        if (paths.isNotEmpty) {
          final List<AssetEntity> assets = await paths.first.getAssetListRange(
            start: 0,
            end: 80, // Increased to 80 for better UX
          );
          emit(state.copyWith(assets: assets, isLoading: false, error: ps == PermissionState.limited ? 'Limited access granted: showing only some photos' : null));
        } else {
          emit(state.copyWith(isLoading: false));
        }
      } else {
        emit(state.copyWith(isLoading: false, error: 'Permission denied. Please enable gallery access in settings.'));
      }
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: 'Gallery Error: ${e.toString()}'));
    }
  }

  Future<void> _onPickImage(
    PickImageEvent event,
    Emitter<HomeState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    try {
      final XFile? image = await _picker.pickImage(source: event.source);
      if (image != null) {
        emit(state.copyWith(selectedImagePath: image.path, isLoading: false));
      } else {
        emit(state.copyWith(isLoading: false));
      }
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }
}
