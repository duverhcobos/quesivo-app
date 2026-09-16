# Propuesta: Rediseño del ShellHeader — iniciales, firma de marca, affordance y esquinas redondeadas

**Estado: aplicada y auditada** — `flutter analyze` 0 issues, `flutter test`
77/77, `dart format` limpio. Revisor: sin bloqueantes; se aplicaron sus 2
recomendaciones — `customBorder: CircleBorder()` en el InkWell de la
hamburguesa (el ripple saldría cuadrado sin él) y comentario stale del
Divider en `main_layout.dart` actualizado a "banda navy". Nota pendiente
del revisor: verificar en pantalla chica si el círculo de marca solapa la
hamburguesa (estimación geométrica, se dibuja detrás). yaml en 1.4.0.

**Ampliaciones posteriores aprobadas por el usuario (yaml 1.4.1):**
avatar unificado via `UserInitialAvatar` compartido (header 44px con
anillo, drawer 56px sin anillo — el avatar del menú dejó `Icons.person`),
firma de queso del drawer igualada a la del header (96px, -36) y el ✕ del
drawer en la posición exacta de la hamburguesa (40px/22, inset
`width*0.075`, +2px) — el mismo toque abre y cierra el menú.

Aprobada por el usuario sobre el plan presentado en sesión. Solo toca
`shell_header.dart` + yaml — misma banda navy, mismo alto, mismas
responsabilidades (identidad + trigger del drawer).

## Cambios

| Archivo | Acción |
|---------|--------|
| `lib/features/shell/presentation/widgets/shell_header.dart` | Rediseño completo del build |
| `../Design/quesivo-design-system.yaml` | Spec + changelog 1.4.0 |

## Detalle

### 1. Avatar con iniciales (reemplaza `Icons.person`)

El círculo amarillo 44 pasa a mostrar las iniciales del usuario (máx. 2
letras, mayúsculas) — identidad real en vez de ícono genérico. Helper
privado en el mismo archivo:

```dart
String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}
```

Contenido del círculo:
```dart
Text(
  _initials(displayName),
  style: const TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.quesivoNavy,
  ),
)
```

El anillo blanco 20% se conserva. Cuando el backend traiga foto, se
reemplaza el `Text` por `CircleAvatar`/imagen en el mismo círculo.

### 2. Subtítulo correcto

La segunda línea hoy repite `displayName` (duplicado visible). Pasa a
`l10n.orgName` — nombre arriba, quesera abajo (igual que la tarjeta de
identidad del drawer).

### 3. Firma de marca en la banda

`DrawerBrandDecoration` amarillo con huecos asomando recortado por la
esquina superior-derecha de la banda navy — reutiliza el widget del
drawer. Requiere `import 'drawer/drawer_brand_decoration.dart';`.

Estructura nueva (la banda pasa de `ColoredBox` plano a `ClipRRect` +
`Stack`):

```dart
return ClipRRect(
  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
  child: ColoredBox(
    color: AppColors.quesivoNavy,
    child: Stack(
      children: [
        // Firma de marca — la porción de queso asoma recortada por la
        // esquina superior-derecha, detrás del contenido (misma técnica
        // del drawer y del diálogo de logout).
        const Positioned(
          top: -36,
          right: -36,
          child: DrawerBrandDecoration(
            diameter: 96,
            color: AppColors.quesivoYellow,
            withCheeseHoles: true,
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding( ... Row idéntico al actual ... ),
        ),
      ],
    ),
  ),
);
```

El `Divider` inferior desaparece — el borde curvo ya delimita la banda.

### 4. Hamburguesa con affordance de círculo

El `IconButton` suelto pasa a un círculo con borde blanco 20% (hermana del
✕ navy del drawer, en versión sobre navy):

```dart
Material(
  color: Colors.transparent,
  shape: CircleBorder(
    side: BorderSide(
      color: AppColors.quesivoWhite.withValues(alpha: 0.2),
    ),
  ),
  clipBehavior: Clip.antiAlias,
  child: InkWell(
    onTap: () => Scaffold.of(context).openEndDrawer(),
    child: SizedBox(
      width: 40,
      height: 40,
      child: Icon(
        Icons.menu,
        size: 22,
        color: AppColors.quesivoWhite.withValues(alpha: 0.85),
      ),
    ),
  ),
)
```

### 5. Esquinas inferiores redondeadas

`BorderRadius.vertical(bottom: Radius.circular(20))` en el `ClipRRect` —
la banda deja de ser una franja plana y corona la pantalla como tarjeta.
El `Divider` exterior se elimina (ya no hace falta).

## Doc comment

Actualizar el del widget: avatar con iniciales, subtítulo orgName, firma
de marca, círculo de la hamburguesa y esquinas redondeadas.

## Verificación

`flutter analyze` + `flutter test` + `dart format` en el archivo tocado.
yaml → 1.4.0.
