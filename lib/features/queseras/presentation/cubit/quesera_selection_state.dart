import 'package:equatable/equatable.dart';

/// Estado del tap en una quesera de la capa personal.
/// `selectingId` = qué card está resolviendo select-organization
/// (muestra su spinner y bloquea los demás taps).
class QueseraSelectionState extends Equatable {
  final String? selectingId;
  final String? errorMessage;

  const QueseraSelectionState({this.selectingId, this.errorMessage});

  bool get isSelecting => selectingId != null;

  QueseraSelectionState copyWith({
    String? selectingId,
    String? errorMessage,
    bool clearSelection = false,
    bool clearError = false,
  }) {
    return QueseraSelectionState(
      selectingId: clearSelection ? null : (selectingId ?? this.selectingId),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [selectingId, errorMessage];
}
