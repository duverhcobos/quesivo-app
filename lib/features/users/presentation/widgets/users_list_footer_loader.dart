import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Spinner al pie del listado mientras `UsersScreen` "carga" la
/// siguiente tanda (scroll paginado local, §43). Última fila de
/// `ListView.separated` cuando `_isLoadingMore` es true.
class UsersListFooterLoader extends StatelessWidget {
  const UsersListFooterLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            color: AppColors.quesivoNavy,
          ),
        ),
      ),
    );
  }
}
