# ESCAQUE · prototipo P0 / C0

Implementación digital mínima de **ESCAQUE P0** y del control **C0** según `ESCAQUE_GDD_v0_1.md` (§6, §7, §13, §14).
Godot 4.4 · GDScript · renderer Compatibility · hotseat 1v1 local.

## Abrir y jugar

1. Abre Godot 4.4 (o superior), pulsa **Importar** y elige `project.godot`.
2. **F5** para jugar.

| Acción | Control |
|---|---|
| Seleccionar pieza | clic izquierdo (también piezas rivales: muestra su alcance en azul, sólo consulta) |
| Mover / capturar | clic en un destino (punto verde = mover, anillo rojo = capturar) |
| Cancelar selección | clic derecho o `Esc` |
| Fin de turno | botón o `Espacio` / `Enter` |
| Cambiar P0 / C0 | desplegable + **Nueva partida** |
| Empate experimental (§6.10) | botón; pide la causa observada, que queda en el log |

**Lectura del tablero:** cada pieza lleva su inicial (P Peón, C Caballo, T Torre, R Rey) y su coste en la esquina.
Insignia dorada = activable con los PA que quedan; roja = PA insuficientes; gris = no es tu turno.
Aspa roja = pieza agotada este turno. En el panel, los círculos con anillo claro son los PA que guardarías como Reserva si terminases ahora.

## Parámetros (sin tocar código)

`data/escaque_rules.json` contiene: tamaño de tablero, colocación inicial, jugador inicial, costes y patrones de movimiento de cada pieza, y los modos (`base_ap`, `max_reserve`, `max_activations_per_piece`). Puedes añadir modos nuevos (p. ej. `"P0.2"` con otros valores) y aparecerán en el desplegable.

## Telemetría (§13.7)

Cada partida se guarda como JSON en la carpeta de datos de usuario de Godot (`%APPDATA%\Godot\app_userdata\ESCAQUE\logs` en Windows; botón **Abrir carpeta de logs**). Contiene:

- **partida:** modo, config usada, jugador inicial, ganador, motivo de final, duración (turnos de jugador y rondas);
- **turno:** PA iniciales, gastados, restantes, reservados, perdidos, nº de activaciones, secuencia de tipos, cómo terminó;
- **acción:** pieza, coste, origen, destino, captura y tipo capturado;
- **summary:** por jugador, media de activaciones y PA gastados, histograma de reserva (0/1/2), PA perdidos, frecuencia por tipo, secuencias de activación y capturas. Pensado para las pruebas de diseño §15.2 y los riesgos §9.

Las partidas interrumpidas (nueva partida o cerrar ventana) también se guardan, con `end_reason: "abandonada"`.

## Arquitectura (§13.3)

```
core/                  lógica pura (RefCounted), sin dependencias de UI
  rules_config.gd      datos de reglas cargados del JSON
  piece.gd             id, owner, piece_type, position, activation_cost, activated_this_turn
  board.gd             límites, ocupación, movimiento/captura
  move_generator.gd    patrones pawn / leaper / slider
  game_state.gd        turno, jugador activo, PA, Reserva, activaciones, victoria
  turn_controller.gd   inicio/fin de turno, costes, Reserva, C0
  victory_system.gd    captura del Rey, empate experimental
  match_logger.gd      log JSON + resumen
  match_controller.gd  fachada que usan la UI y los tests
ui/                    board_view (tablero dibujado por código), ap_meter, main
scenes/main.tscn
tests/test_rules.gd    59 comprobaciones de §14 y §15.1 + 300 partidas aleatorias
```

Tests: `godot --headless --path . -s res://tests/test_rules.gd`

## Interpretaciones tomadas donde el GDD no fija detalle

- **C0:** el turno termina automáticamente tras la única activación. Sólo se puede pasar si no hay ninguna activación legal.
- **P0:** se puede terminar el turno siempre, incluso sin activar nada (guarda min(PA, 2)).
- **Peón en la última fila:** sin promoción, queda sin movimientos.
- **Empate:** no se detecta automáticamente; se declara a mano con la causa (§6.10).
- **Orientación:** Blancas siempre abajo (sin girar el tablero entre turnos).
