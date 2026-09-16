---
name: token-saving-tools-policy
description: Política de uso de herramientas de exploración para ahorrar tokens (cuándo leer directo vs. usar el grafo codebase-memory) en Quesivo App
allowed-tools:
  - read
  - grep
  - glob
triggers:
  - user
  - model
---

Política de uso de herramientas de exploración de **Quesivo App**, para minimizar el
consumo de tokens por sesión.

1. **Ruta conocida o patrón puntual → leer directo.** Si ya se sabe qué archivo hay que abrir
   (porque el usuario lo mencionó, aparece en el skill `flutter-architecture`, o ya se leyó antes
   en la misma sesión), usar `read`/`grep` directamente. No pasar por el grafo (codebase-memory)
   para esto — es más caro y no aporta nada que no dé una lectura directa.
2. **Ubicación desconocida o relación entre capas/features → ahí sí, grafo.** El proyecto ya está
   indexado en `codebase-memory-mcp` (proyecto `C-Users-Usuario-Documents-DHC30-app-quesera`).
   Reservar `search_graph`, `trace_path`, `query_graph` para cuando de verdad no se sabe dónde vive
   algo, o se necesita trazar quién llama a qué a través de varias capas (`domain` → `data` →
   `presentation`, o quién usa un Use Case/Cubit específico). `get_architecture` solo para un
   panorama general nuevo, no repetirlo si ya se pidió en la sesión.
3. **No re-indexar sin necesidad.** `index_repository` se corre una vez por sesión (o cuando el
   usuario pide explícitamente refrescar el índice tras cambios grandes), no antes de cada
   pregunta.
4. **Archivos grandes → `offset`/`limit`.** Si se sabe qué sección interesa (ej. un método
   específico dentro de un archivo largo como `setup_di.dart`), pedir solo ese rango de líneas en
   vez del archivo completo.
5. **Batch de lecturas independientes.** Cuando se necesitan varios archivos sin dependencia entre
   sí (ej. leer un Use Case y su test correspondiente, o los 3 `.arb` a la vez), pedirlos en
   paralelo en una sola tanda, no uno por uno.
6. **No repetir contenido ya mostrado.** En las respuestas, no volver a pegar el contenido completo
   de un archivo/propuesta ya mostrado antes en la conversación salvo que haya cambiado o el
   usuario lo pida explícitamente — referenciarlo por nombre/ruta (o con `<ref_file>`/
   `<ref_snippet>`) alcanza.
7. **No repetir `flutter analyze`/`flutter test` innecesariamente.** Correrlos una vez al final de
   un lote de cambios relacionados (ver skill `production-checklist`), no después de cada edición
   individual si se sabe que varias ediciones van a aplicarse en la misma ronda.
8. **`flutter gen-l10n` solo cuando cambian los `.arb`.** No ejecutarlo especulativamente ni
   repetirlo si ya se corrió después del último cambio a los diccionarios de i18n.
9. **`flutter pub get` solo cuando cambia `pubspec.yaml`.** No correrlo por rutina en cada
   verificación si las dependencias no se tocaron desde la última corrida.
