# ESCAQUE · GDD v0.1 · Anexo A — Análisis de Chess 2

**Versión:** 0.1  
**Estado:** ANÁLISIS / PROPUESTO  
**Objeto:** evaluar qué reglas de *Chess 2* (reglamento v2.4, `rulebook.pdf`) pueden incorporarse a ESCAQUE, cuáles requieren desarrollo adicional y con qué alcance.  
**Fecha:** 30 de septiembre de 2026  
**Relación con el GDD:** no modifica ninguna decisión del GDD v0.1. Las propuestas que contradicen decisiones cerradas (§17) se señalan expresamente.

---

## A.0. Criterio de filtrado

*Chess 2* modifica el ajedrez en cuatro capas: condición de victoria (Invasión de la línea media), recurso secundario con información oculta (duelos con piedras), ejércitos asimétricos (seis) y reglas sueltas (promoción, tablas, ausencia de ahogado).

ESCAQUE P0 parte de decisiones distintas que actúan como filtro:

- **sin jaque** (§6.6, §6.9);
- **determinismo e información completa** como control experimental (§3.5);
- **varias activaciones por turno** mediante PA (§6.4–6.8).

Por tanto: lo que depende del jaque no es trasladable sin reintroducirlo; lo que introduce información oculta o simultaneidad debe tratarse como rama experimental; lo que otorga acciones extra puede quedar ya absorbido por la economía de PA.

**Niveles de clasificación**

| Nivel | Definición |
|---|---|
| 1 · Directo | Sólo datos (`escaque_rules.json`) o código trivial; no contradice el GDD. |
| 2 · Desarrollo acotado | Código nuevo dentro de módulos existentes + tests; conserva determinismo e información completa. |
| 3 · Desarrollo mayor | Sistema nuevo o ruptura de un principio del GDD; requiere rama experimental propia. |
| 4 · No recomendado | Incompatible con el núcleo o de valor bajo frente a su coste. |

---

## A.1. Nivel 1 · Incorporación directa

| Elemento de Chess 2 | Traducción a ESCAQUE | Coste |
|---|---|---|
| Piezas de movimiento estándar: Dama, Alfil, reina de Empowered (mueve como Rey) | Patrones `slider` / `leaper` ya soportados por `MoveGenerator` | Sólo JSON; queda por decidir su coste en PA |
| Dos Reyes (sin Remolino) | Dos piezas `royal` en la colocación; `VictorySystem` ya termina la partida al capturar cualquier pieza real | Cero código |
| Turno extra de Rey (Dos Reyes) | Innecesario: la economía de PA ya permite activar ambos Reyes en un turno (2 + 2 PA) | — |

**Observación:** *Chess 2* necesita un turno adicional para permitir dos acciones de Rey; ESCAQUE lo obtiene de forma nativa. Es un indicio a favor de la economía de PA como mecanismo general frente a excepciones por ejército.

---

## A.2. Nivel 2 · Desarrollo acotado

### A.2.1. Victoria por Invasión de la línea media

**Regla original:** se gana si el Rey propio alcanza la fila 5 (para Blancas) sin estar en jaque.

**Pertinencia:** responde a la pregunta abierta §16 «¿capturar al Rey sin jaque genera finales legibles?» y reduce empates por bloqueo. El §12 ya contempla modificar la condición de victoria en la Fase 1.

**Problema de traducción:** ESCAQUE no tiene jaque. Opciones:

1. victoria inmediata al alcanzar la fila;
2. victoria al alcanzarla si la casilla no está atacada;
3. victoria si el Rey sigue vivo en la fila al inicio del siguiente turno propio.

**Propuesta:** opción 3. Concede al rival un turno completo de PA para responder y convierte la Reserva en recurso defensivo, no sólo de ataque en ráfaga.

**Ritmo estimado:** el Rey empieza encerrado (e1 rodeado por d1, f1, d2, e2, f2) y sólo puede activarse una vez por turno; necesita del orden de 5 turnos para invadir. Carrera medible con la telemetría.

**Alcance:**

- `VictorySystem`: nueva condición (~50 líneas);
- JSON: selector de condiciones de victoria activas, p. ej. `"victory": ["king_capture", "midline"]`;
- UI: marcar la línea media;
- log: nuevo `end_reason`;
- tests.

### A.2.2. Tablas automáticas

**Regla original:** repetición triple, regla de 50 jugadas sin captura ni movimiento de peón, material insuficiente.

**Pertinencia:** sustituye el empate experimental manual (§6.10) y reduce la subjetividad de la primera batería (§15.3).

**Adaptaciones necesarias:**

- el estado que se compara debe incluir jugador activo y Reservas (la misma posición con 0 o 2 PA reservados no es equivalente);
- la regla de las 50 se expresa en turnos de jugador, no en jugadas.

**Alcance:** ~80 líneas + tests.

### A.2.3. Sin ahogado: sin jugadas = derrota

**Regla original:** si un jugador no tiene movimientos legales, pierde.

**Adaptación:** distinguir «sin movimiento legal» de «sin PA suficientes»; la comprobación se hace al inicio del turno.

**Alcance:** ~10 líneas. **Propuesta:** opción de configuración, no regla fija.

### A.2.4. Adyacencia potenciadora (ejército Empowered)

**Regla original:** Caballo, Alfil y Torre adyacentes ortogonalmente se prestan sus patrones de movimiento.

**Pertinencia:** es la mecánica de mayor encaje conceptual. En ESCAQUE, activar una pieza altera los poderes de sus vecinas a mitad de turno: el orden de activación pasa a ser decisivo. Alimenta directamente **H-P0-3 · Secuenciación**.

**Alcance:**

- cálculo dinámico del movimiento a partir de vecinas ortogonales (~60 líneas);
- UI que muestre los poderes adquiridos;
- tests.

**Encaje:** «formaciones» (§4, fila *Reglas*). **Propuesta:** experimento propio, no como ejército.

### A.2.5. Ampliación de patrones de movimiento (Animals, Reaper, Nemesis)

Extensiones de `MoveGenerator` y del esquema JSON:

| Capacidad | Ejemplo en Chess 2 |
|---|---|
| Multipatrón | Reina de Animals: Torre o Caballo |
| Alcance máximo | Tigre (2 en diagonal), Elefante (3 ortogonal) |
| Captura de piezas propias | Caballo salvaje |
| No capturar / no ser capturada / bloquear | Nemesis (sólo capturable por el Rey), torres fantasma |
| Teletransporte | Fantasma (casilla vacía), Reaper (captura fuera de la última fila) |
| Captura sin desplazamiento | Tigre (vuelve a su casilla) |
| Movimiento dependiente del estado | Peón Nemesis (hacia el Rey enemigo) |

Cada capacidad es pequeña (horas con tests). **Excepción:** la estampida del Elefante (multicaptura obligatoria recorriendo su alcance máximo, captura de piezas propias, inmunidad frente a atacantes a más de 2 casillas) es la más costosa: la inmunidad obliga a comprobar distancias en toda la generación de capturas.

**Coste real:** no está en el código, sino en asignar un coste en PA a cada pieza. Con PA, el teletransporte es extremadamente fuerte.

### A.2.6. Promoción obligatoria

**Choque con el GDD:** contradice §17 DECIDIDO («sin promoción»). Sólo procede si se revisa esa decisión.

**Alcance:** bajo (selector de pieza en la UI). Resolvería los peones inmovilizados en la última fila.

---

## A.3. Nivel 3 · Desarrollo mayor

### A.3.1. Duelos (piedras y puja secreta simultánea)

**Choque con el GDD:** rompe determinismo e información completa (§3.5) y modifica la captura determinista (§6.7: si gana el defensor, se pierden ambas piezas).

**Variante propuesta:** pujar con PA de la Reserva en lugar de piedras. La Reserva adquiriría una función defensiva, lo que podría neutralizar el riesgo **§9.1 · Burst dominante**.

**Alcance:**

- flujo de UI que interrumpe el turno del atacante para consultar al defensor;
- pantalla de ocultación para hotseat («pasa el dispositivo»);
- reglas de farol, empate a favor del atacante y jugador sin recursos;
- registro de pujas en el log.

**Riesgo:** varias capturas por turno implican varios duelos por turno; agrava **§9.5 · Complejidad combinatoria**.

**Propuesta:** rama experimental propia (provisionalmente **E7 · DUEL**), de calibre similar a E4 · FOG.

### A.3.2. Ejércitos asimétricos

**Choque con el GDD:** §2.3 excluye de P0 facciones asimétricas y metajuego.

**Alcance:**

- esquema de ejércitos en JSON (piezas, colocación, costes);
- reglas por jugador (actualmente la configuración es común);
- pantalla de selección;
- matriz de balance (6 ejércitos → 21 emparejamientos), que multiplica la carga de pruebas.

**Palanca propia de ESCAQUE:** costes de PA distintos por ejército.

**Propuesta:** empezar con dos ejércitos, no seis.

### A.3.3. Habilidades activas (Remolino de Dos Reyes)

**Choque con el GDD:** §2.3 excluye habilidades activas de P0.

**Alcance:** generalizar la activación a {movimiento | habilidad}; afecta a `TurnController`, UI (selección de tipo de acción) y esquema del log. Encaja con PA: la habilidad cuesta PA.

---

## A.4. Nivel 4 · No recomendado

- **Reglas dependientes del jaque:** no mover a jaque, jaque mate, «sin estar en jaque» literal de la línea media. Reintroducir jaque con varias activaciones por turno obliga a decidir cuándo se evalúa (tras cada activación o al final del turno) y multiplica la complejidad.
- **Captura al paso:** excluida en §17 y ambigua con activaciones múltiples (qué movimiento rival cuenta como «último»).
- **Enroque:** excluido en §17 e inaplicable a la colocación de P0.
- **Elección doble ciega de ejército:** sólo tiene sentido si existen ejércitos.

---

## A.5. Orden de incorporación propuesto

| Paso | Contenido | Fase del GDD (§12) |
|---|---|---|
| 1 | Tablas automáticas + opción «sin jugadas = derrota» | Fase 0 (infraestructura de pruebas) |
| 2 | Invasión de la línea media como variante configurable de victoria | Fase 1 · P0.2 |
| 3 | Adyacencia potenciadora como experimento de secuenciación | Tras Fase 1 |
| 4 | Ampliación de patrones, pieza a pieza con coste asignado | Según necesidad |
| 5 | Ejércitos, duelos, habilidades | Ramas propias, sólo con evidencia favorable según §18 |

---

## A.6. Hechos, inferencias y propuestas

- **Hechos:** reglas de *Chess 2* según `rulebook.pdf` v2.4; capacidades actuales de la implementación P0 (patrones `pawn`/`leaper`/`slider`, piezas `royal`, parámetros en JSON).
- **Inferencias:** estimaciones de líneas de código y de ritmo de la Invasión (≈5 turnos); efectos previstos sobre H-P0-3, §9.1 y §9.5. No verificadas con partidas.
- **Propuestas:** opción 3 para la línea media; puja con PA; rama E7 · DUEL; orden de incorporación.

## A.7. Nota sobre propiedad intelectual

El repositorio es público. Se recomienda no reutilizar los nombres de ejércitos ni el texto del reglamento de *Chess 2* y usar denominaciones propias de ESCAQUE. Las mecánicas en sí no suelen estar protegidas, pero esto no constituye asesoramiento legal.

**Fin · Anexo A · GDD ESCAQUE v0.1 · ANÁLISIS / PROPUESTO**
