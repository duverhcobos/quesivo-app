import 'package:flutter/material.dart';

import '../../../../core/widgets/quesivo_loader.dart';

/// Spinner al pie del listado mientras `UsersListCubit` trae la página
/// siguiente del `GET /auth/users` real (§49 — paginación server-side;
/// heredero del scroll paginado local de §43). Última fila del
/// `ListView.separated` cuando `state.isLoadingMore || state.hasMore`.
class UsersListFooterLoader extends StatelessWidget {
  const UsersListFooterLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      // Variante navy: momento menor y transitorio — el accent de marca
      // se reserva para cargas de pantalla. Sin semanticLabel: anunciar
      // "cargando" en cada página del scroll sería ruido en TalkBack.
      child: Center(
        child: QuesivoLoader(size: 22, variant: QuesivoLoaderVariant.navy),
      ),
    );
  }
}
