import 'package:equatable/equatable.dart';

import '../../domain/failures/organization_failure.dart';

/// Estado de la pantalla "¿Cómo se llama tu quesera?" (propuesta 71).
///
/// `isSubmitting` congela el form y cambia la columna de acciones por el
/// loader (patrón de los sheets); `failure` dispara el toast de error —
/// se guarda el failure TIPADO, no un string, para que la pantalla lo
/// mapee a su clave l10n (offline vs genérico).
class OrgNameSetupState extends Equatable {
  final bool isSubmitting;
  final OrganizationFailure? failure;

  const OrgNameSetupState({this.isSubmitting = false, this.failure});

  OrgNameSetupState copyWith({
    bool? isSubmitting,
    OrganizationFailure? failure,
    bool clearFailure = false,
  }) {
    return OrgNameSetupState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [isSubmitting, failure];
}
