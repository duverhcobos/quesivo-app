import 'package:equatable/equatable.dart';
import 'package:formz/formz.dart';

import '../../domain/entities/org_member.dart';
import '../../domain/failures/users_failure.dart';

/// Estado del sheet de vinculación — solo orquesta el submit: los
/// campos viven en el `State` del widget (validados por el VO de
/// dominio). Sin `copyWith`: cada transición emite el estado completo
/// (3 campos).
class LinkUserState extends Equatable {
  final FormzSubmissionStatus status;
  final OrgMember? linkedMember;
  final UsersFailure? failure;

  const LinkUserState({
    this.status = FormzSubmissionStatus.initial,
    this.linkedMember,
    this.failure,
  });

  @override
  List<Object?> get props => [status, linkedMember, failure];
}
