import 'package:equatable/equatable.dart';
import 'package:formz/formz.dart';

import '../../domain/entities/org_member.dart';
import '../../domain/failures/users_failure.dart';

/// Estado del sheet de reset — solo orquesta el submit (mismo molde
/// que `LinkUserState`): los campos viven en el `State` del widget,
/// validados por el VO `TempPassword`.
class ResetPasswordState extends Equatable {
  final FormzSubmissionStatus status;
  final OrgMember? resetMember;
  final UsersFailure? failure;

  const ResetPasswordState({
    this.status = FormzSubmissionStatus.initial,
    this.resetMember,
    this.failure,
  });

  @override
  List<Object?> get props => [status, resetMember, failure];
}
