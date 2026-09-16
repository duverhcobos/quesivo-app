---
name: production-checklist
description: Checklist final antes de considerar terminado un cambio en Quesivo (proyecto camino a producción)
allowed-tools:
  - read
  - grep
  - glob
  - exec
triggers:
  - user
  - model
---

**Quesivo** es la app real en desarrollo activo con destino a producción, no un repo de
prueba. Antes de considerar terminado cualquier cambio (propio o de un cambio previamente
aplicado), correr este checklist:

1. `flutter analyze` sin errores/warnings nuevos.
2. `flutter test` en verde.
3. Sin `print()`, sin literales de texto/color/URL hardcodeados nuevos (ver skill
   `i18n-workflow` y `solid-clean-architecture` para el detalle de cada regla).
4. Sin secretos ni URLs de prueba filtrados fuera de `dev` (ver skill `environments-secrets`).
5. Traducciones actualizadas en los tres `.arb` si se agregó texto visible (ver skill
   `i18n-workflow`).
6. Si el cambio tocó `AuthGuard`, `AuthInterceptor`, `RefreshTokenInterceptor`,
   `SecureLocalAuthDataSourceImpl` o cualquier flujo de sesión/token: se explicó su impacto de
   seguridad al usuario antes o al momento de aplicarlo.
7. Antes de dar por terminado un cambio en `features/auth` u otras features críticas (login,
   sesión, pagos si existieran), revisar manualmente que el flujo afectado siga funcionando, no
   solo que los tests pasen.
8. Si el cambio requería backend/infra real (URLs de stg/prod, contratos de API todavía no
   confirmados) y se dejó algo temporal/provisional, se declaró explícitamente al usuario — nunca
   de forma implícita.

No hacer commits ni push sin que el usuario lo pida explícitamente, incluso después de pasar todo
este checklist.
