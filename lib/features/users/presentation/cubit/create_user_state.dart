import 'package:equatable/equatable.dart';
import 'package:formz/formz.dart';

import '../../domain/entities/org_member.dart';
import '../../domain/failures/users_failure.dart';

/// Estado del sheet de creación — solo orquesta el submit: los campos
/// viven en el `State` del widget (validados por los VOs de dominio).
/// Sin `copyWith`: cada transición emite el estado completo (3 campos).
class CreateUserState extends Equatable {
  final FormzSubmissionStatus status;
  final OrgMember? createdMember;
  final UsersFailure? failure;

  const CreateUserState({
    this.status = FormzSubmissionStatus.initial,
    this.createdMember,
    this.failure,
  });

  @override
  List<Object?> get props => [status, createdMember, failure];
}
