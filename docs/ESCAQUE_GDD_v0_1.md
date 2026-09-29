# ESCAQUE · Game Design Document

**Versión:** 0.1  
**Estado:** BORRADOR / PROPUESTO  
**Objeto:** concepto general de ESCAQUE, análisis de seis ramas de desarrollo y especificación de P0 para implementación inicial.  
**Fecha:** 29 de septiembre de 2026

---

## 0. Resumen ejecutivo

**ESCAQUE** es un concepto de videojuego táctico derivado de la estructura del ajedrez y de otros juegos de tablero deterministas, transformada mediante una economía de activaciones, especialización de piezas y posibles modificaciones posteriores del espacio, las reglas, la información y el control de las unidades.

La hipótesis de diseño central no es «ajedrez + RPG» como suma de características, sino la siguiente:

> Sustituir la alternancia uniforme de una jugada por turno por una economía de acciones con costes distintos por tipo de pieza y reserva limitada puede producir decisiones recurrentes sobre qué objetivos tácticos perseguir, qué unidades activar y cuánto potencial presente sacrificar para obtener capacidad futura.

La versión inicial **P0** aísla únicamente esa hipótesis. Las demás ideas del concepto se organizan como seis ramas experimentales independientes:

1. **E1 · TERRAIN** — terreno, alturas, obstáculos y casillas con propiedades.
2. **E2 · MORPH** — tablero irregular, teselaciones alternativas y topología mutable.
3. **E3 · LAW** — reglas o «leyes» variables durante la partida.
4. **E4 · FOG** — información incompleta y niebla de guerra.
5. **E5 · AUTO** — órdenes, comportamientos automáticos y control indirecto de unidades.
6. **E6 · DEFENCE** — colocación/configuración previa seguida de resolución parcial o totalmente automática.

Estas ramas no forman todavía un único diseño decidido. Son líneas de investigación derivadas de un núcleo común y deben probarse por separado antes de intentar combinarlas.

---

# 1. Identidad del proyecto

## 1.1. Nombre de trabajo

**ESCAQUE**

## 1.2. Descripción breve

Juego táctico por turnos sobre tablero discreto en el que cada jugador controla un pequeño conjunto de piezas con movimientos y costes de activación distintos. Cada turno concede un presupuesto común de Puntos de Acción (PA), que puede repartirse entre varias piezas y reservarse parcialmente para turnos posteriores.

## 1.3. Base conceptual

La base de control es el ajedrez entendido como sistema de:

- espacio discreto;
- piezas diferenciadas por patrones de movimiento;
- información completa;
- resolución determinista;
- capturas sin azar;
- fuerte legibilidad posicional.

ESCAQUE modifica esa base principalmente en los componentes **reglas**, **tiempo** y, en ramas posteriores, **espacio**, **información** y **agencia**.

## 1.4. Fantasía de diseño

El jugador no dirige una secuencia uniforme de movimientos aislados, sino que **administra capacidad táctica limitada**: concentra acciones en una zona, divide su esfuerzo entre varias piezas o reserva parte de su capacidad para preparar un turno posterior más potente.

## 1.5. Referencias funcionales

Referencias conceptuales presentes en las notas de origen:

- ajedrez occidental;
- shōgi y xiangqi;
- *Archon*;
- *Fire Emblem*;
- *Advance Wars*;
- *Shining Force*;
- sistema de leyes de *Final Fantasy Tactics Advance*;
- *Battle Chess* y derivados como referencia estética/presentacional;
- Three Hundred Mechanics #135 *Tessellation Tactics*, #133 *Negative Space Tactics* y #017 *Composition Army* como estímulos para algunas ramas espaciales y compositivas.

Estas referencias no implican identidad mecánica ni reproducción de sus sistemas completos.

---

# 2. Objetivos de diseño

## 2.1. Objetivo primario

Construir un juego táctico legible donde la decisión recurrente principal sea:

> **cómo distribuir y temporalizar la capacidad de acción disponible entre varias piezas con funciones y costes diferentes.**

## 2.2. Objetivos secundarios

- Mantener suficiente legibilidad para que el jugador pueda anticipar consecuencias sin cálculos opacos.
- Permitir combinaciones tácticas de varias piezas en un mismo turno.
- Crear tensión entre acción inmediata y preparación futura.
- Mantener el núcleo jugable sin necesidad de azar, progresión, campaña o contenido masivo.
- Hacer posible que ramas posteriores alteren el espacio, las reglas o la información sin redefinir necesariamente todo el sistema base.

## 2.3. No objetivos de P0

P0 no intenta validar:

- progresión RPG;
- campaña;
- construcción de ejército;
- facciones asimétricas;
- estadísticas de ataque/defensa;
- habilidades activas;
- terreno;
- alturas;
- orientación;
- niebla de guerra;
- IA autónoma;
- leyes variables;
- más de dos jugadores;
- multijugador en red;
- metaprogresión.

---

# 3. Principios de diseño

## 3.1. Economía de activación visible

El jugador debe poder comprender de forma inmediata cuánto cuesta actuar con cada pieza y qué combinaciones de activaciones son posibles.

## 3.2. Decisiones sobre capacidad, no sólo sobre posición

La pregunta táctica no debe reducirse a «qué movimiento es mejor», sino incluir «qué conjunto de movimientos merece mi presupuesto de este turno».

## 3.3. Preparación con coste de oportunidad

Reservar PA sólo resulta interesante si renunciar a acciones presentes produce una ventaja futura suficientemente significativa, pero no dominante.

## 3.4. Piezas con función legible

El coste de activación debe correlacionarse con el valor espacial o táctico de la pieza sin convertir las piezas caras en elecciones siempre superiores.

## 3.5. Determinismo como control experimental

P0 elimina azar y resolución estadística para aislar la economía temporal de acciones.

---

# 4. Estructura sistémica provisional

| Componente | ESCAQUE núcleo | Desarrollo posterior posible |
|---|---|---|
| Agentes | 2 jugadores | bandos, equipos, IA autónoma |
| Objetos | piezas | fuertes, banderas, recursos, obstáculos |
| Estado | posición, piezas capturadas, PA, reserva | orientación, control territorial, estados de terreno |
| Reglas | movimiento, captura, costes | leyes, habilidades, formaciones |
| Información | completa | E4 · FOG |
| Espacio | cuadrícula 8×8 | E1 · TERRAIN, E2 · MORPH |
| Tiempo | turnos + presupuesto de PA | recargas, leyes temporales |
| Economía | PA temporales | recursos o refuerzos futuros |
| Progresión | ninguna | coronación, experiencia, campaña |
| Ficción | abstracta / no fijada | facciones temáticas |
| Interfaz | tablero y marcadores | información parcial, órdenes, visualización 3D |
| Metajuego | ninguno | construcción de ejército, escenarios, campaña |

---

# 5. Bucle principal de P0

```text
Leer posición
→ identificar objetivos tácticos
→ calcular presupuesto disponible
→ seleccionar pieza(s) y secuencia de activaciones
→ ejecutar movimientos/capturas
→ decidir gastar o reservar PA
→ entregar turno
→ reevaluar nueva posición
```

La nueva decisión respecto al control de referencia es doble:

1. **distribución:** qué piezas reciben acciones;
2. **temporalización:** cuánto presupuesto se gasta ahora y cuánto se conserva.

---

# 6. ESCAQUE P0 · especificación jugable

## 6.1. Parámetros base

- Jugadores: 2.
- Tablero: 8×8.
- Información: completa.
- Azar: ninguno.
- PA base por turno: 6.
- Reserva máxima: 2 PA.
- Activaciones máximas por pieza y turno: 1.
- Victoria: capturar al Rey rival.

## 6.2. Ejército inicial

Cada jugador dispone de 8 piezas:

| Pieza | Cantidad | Coste de activación |
|---|---:|---:|
| Peón | 4 | 1 PA |
| Caballo | 1 | 2 PA |
| Torre | 2 | 3 PA |
| Rey | 1 | 2 PA |

## 6.3. Colocación inicial

Desde el punto de vista de Blancas:

```text
    a b c d e f g h
  +-----------------+
8 | . . r k n r . . |
7 | . . p p p p . . |
6 | . . . . . . . . |
5 | . . . . . . . . |
4 | . . . . . . . . |
3 | . . . . . . . . |
2 | . . P P P P . . |
1 | . . R N K R . . |
  +-----------------+
```

- Mayúsculas: Blancas.
- Minúsculas: Negras.
- Blancas comienzan.
- Ambos jugadores empiezan con Reserva = 0.

## 6.4. Inicio de turno

El jugador comienza con:

**PA disponibles = 6 + Reserva acumulada.**

Después la Reserva se pone a 0.

## 6.5. Activación

Para activar una pieza:

1. pagar su coste;
2. ejecutar exactamente un movimiento legal;
3. marcarla como agotada para el resto del turno.

Una pieza no puede activarse más de una vez en el mismo turno.

## 6.6. Movimiento de piezas

### Peón

- Coste: 1 PA.
- Avanza una casilla en dirección enemiga si está vacía.
- Captura una casilla diagonal hacia delante.
- No dispone de avance doble, *en passant* ni promoción.

### Caballo

- Coste: 2 PA.
- Movimiento en L estándar de ajedrez.
- Puede saltar piezas.

### Torre

- Coste: 3 PA.
- Movimiento ortogonal cualquier número de casillas.
- No puede atravesar piezas.

### Rey

- Coste: 2 PA.
- Se desplaza una casilla en cualquier dirección.
- No existe jaque ni jaque mate.
- Puede entrar en una casilla amenazada.
- Los Reyes pueden quedar adyacentes.

## 6.7. Captura

La captura es determinista:

- la pieza enemiga se retira;
- la atacante ocupa la casilla destino.

No existen puntos de vida, tiradas ni contraataques automáticos.

## 6.8. Fin de turno y Reserva

El jugador puede terminar su turno cuando quiera.

Al hacerlo:

**Reserva = mínimo(PA restantes, 2).**

Los PA por encima de 2 se pierden.

## 6.9. Victoria

Capturar al Rey enemigo termina la partida inmediatamente.

No existe condición de jaque ni protección obligatoria del Rey.

## 6.10. Empate experimental

P0 no establece reglas formales de tablas. Si una prueba entra en repetición evidente o en bloqueo indefinido, se registra como **empate experimental** junto con la causa observada.

---

# 7. Control C0

Para evaluar el efecto de la economía de PA se define un control directo.

## 7.1. C0 · activación única

Mismo tablero, piezas, movimientos, captura y condición de victoria que P0, pero:

- no existen PA;
- no existen costes;
- no existe Reserva;
- cada jugador activa exactamente una pieza por turno.

## 7.2. Propósito

Comparar si P0 produce decisiones y dinámicas atribuibles específicamente a:

- activaciones múltiples;
- costes distintos;
- reserva temporal.

---

# 8. Hipótesis de P0

## H-P0-1 · Distribución

Los jugadores deberán decidir entre concentrar PA en piezas costosas o activar varias piezas baratas.

## H-P0-2 · Reserva

La posibilidad de conservar hasta 2 PA generará decisiones reales entre eficiencia presente y capacidad futura.

## H-P0-3 · Secuenciación

El orden de varias activaciones dentro del mismo turno generará combinaciones tácticas inexistentes en el control de una activación.

## H-P0-4 · Legibilidad

El presupuesto de 6–8 PA y costes entre 1 y 3 mantendrá las posibilidades suficientemente legibles para planificar sin convertir cada turno en una búsqueda combinatoria excesiva.

---

# 9. Riesgos de P0

## 9.1. Burst dominante

Guardar siempre 2 PA puede ser óptimo y convertir los turnos de 8 PA en el ritmo real del juego.

## 9.2. Dominio de una composición

Una combinación de costes puede superar sistemáticamente a las demás; por ejemplo, dos Torres por turno o una Torre + Caballo + Peón.

## 9.3. Exceso de movilidad

Varias activaciones por turno pueden reducir demasiado el valor del posicionamiento anticipado.

## 9.4. Ventaja del primer jugador

La capacidad de encadenar acciones puede amplificar la iniciativa inicial.

## 9.5. Complejidad combinatoria

Si demasiadas piezas pueden actuar en demasiados órdenes, cada turno puede volverse lento pese a la simplicidad individual de los movimientos.

---

# 10. Seis ramas de desarrollo

Las seis ramas siguientes se consideran **propuestas experimentales**, no características comprometidas para el producto.

---

## 10.1. E1 · TERRAIN

### Pregunta de diseño

¿Qué ocurre si el tablero deja de ser homogéneo pero conserva su cuadrícula regular?

### Transformación

Añadir propiedades locales a las casillas sin alterar inicialmente su geometría.

### Elementos candidatos

- bosque;
- agua;
- fortificación;
- hielo;
- lava;
- zonas altas/bajas;
- obstáculos;
- casillas que modifican costes.

### Decisiones nuevas esperadas

- elegir rutas en función de coste y seguridad;
- disputar posiciones cuyo valor depende del tipo de terreno;
- decidir si gastar PA adicionales para atravesar zonas desfavorables;
- usar piezas diferentes según entorno.

### Acoplamiento con P0

El terreno debería modificar al menos uno de estos elementos:

- coste de activación;
- alcance de movimiento;
- legalidad del movimiento;
- capacidad de captura;
- persistencia sobre una casilla.

Si el terreno sólo cambia apariencia, la rama no produce una transformación mecánica relevante.

### Riesgos

- convertir el tablero en una colección de excepciones;
- hacer demasiado difícil anticipar rutas;
- que el terreno determine más que las piezas;
- añadir bonificadores numéricos poco legibles.

### Prototipo mínimo sugerido

P0 + tres tipos de casilla:

- normal;
- difícil: +1 PA para entrar;
- bloqueo: infranqueable.

### Criterio de avance

La rama merece continuar si el jugador cambia de objetivo o secuencia de activaciones por la configuración del terreno, no sólo si tarda más en llegar.

---

## 10.2. E2 · MORPH

### Pregunta de diseño

¿Qué ocurre si se transforma la propia geometría o topología del tablero?

### Transformación

Modificar relaciones de vecindad y/o permitir que esas relaciones cambien durante la partida.

### Variantes

**A. Teselación alternativa**

- hexágonos;
- triángulos;
- polígonos mixtos.

**B. Casillas de tamaño o capacidad distinta**

- zonas que admiten diferentes tipos o cantidades de unidades.

**C. Tablero mutable**

- crear/eliminar casillas;
- abrir/cerrar conexiones;
- desplazar regiones;
- invertir zonas transitables.

### Decisiones nuevas esperadas

- valorar relaciones de vecindad no uniformes;
- manipular rutas antes de mover piezas;
- atacar la movilidad futura del rival alterando el espacio;
- elegir entre gastar capacidad en unidades o en transformar el tablero.

### Relación con P0

MORPH puede competir directamente por PA si alterar el tablero constituye una acción. Eso genera un acoplamiento fuerte:

**acción sobre pieza ↔ acción sobre espacio.**

### Riesgos

- destruir la legibilidad ajedrecística;
- producir demasiadas excepciones de movimiento;
- volver irrelevantes los patrones clásicos de piezas;
- aumentar en exceso el espacio de búsqueda.

### Prototipo mínimo sugerido

Tablero 8×8 con 4 «puentes» binarios que pueden abrirse/cerrarse pagando PA.

### Criterio de avance

Debe aparecer una decisión real entre invertir PA en movilidad inmediata y modificar la estructura espacial futura.

---

## 10.3. E3 · LAW

### Pregunta de diseño

¿Qué ocurre si parte del reglamento se convierte en estado temporal de la partida?

### Transformación

Introducir «leyes» activas que modifican qué acciones están permitidas, penalizadas o bonificadas.

### Ejemplos

- «Caballería prohibida»: el Caballo puede mover, pero no capturar.
- «Tierra sagrada»: determinadas casillas no permiten capturas.
- «Movilización»: activar más de tres piezas aumenta el coste de la siguiente.
- «Protección real»: capturar una pieza adyacente al Rey cuesta +1 PA.

### Decisiones nuevas esperadas

- adaptar planes a un reglamento cambiante;
- anticipar cuándo caduca o cambia una ley;
- preparar posiciones que ganen valor bajo una regla futura.

### Variantes de control

- ley conocida con duración fija;
- secuencia de leyes visible con antelación;
- ley aleatoria pero pública;
- leyes manipulables por los jugadores.

Para mantener el carácter determinista del núcleo, la primera prueba debería usar secuencia conocida, no aleatoria.

### Riesgos

- reglas arbitrarias difíciles de memorizar;
- planes invalidados sin posibilidad de anticipación;
- que la «ley» se convierta en ruido táctico;
- exceso de excepciones.

### Prototipo mínimo sugerido

P0 + una ley pública que cambia cada 3 turnos según una secuencia predefinida de tres leyes.

### Criterio de avance

Los jugadores deben cambiar su plan anticipándose a la ley, no limitarse a obedecer una restricción puntual.

---

## 10.4. E4 · FOG

### Pregunta de diseño

¿Qué ocurre si ESCAQUE abandona la información completa?

### Transformación

Ocultar parte del estado y convertir la adquisición o inferencia de información en una actividad táctica.

### Variantes

- visibilidad por distancia;
- visibilidad por línea de visión;
- piezas ocultas pero casillas visibles;
- identidad oculta de piezas;
- información atrasada;
- señuelos o estados ambiguos.

### Decisiones nuevas esperadas

- explorar antes de comprometer PA;
- inferir posiciones o intenciones;
- ocultar concentraciones de fuerza;
- gestionar riesgo informacional.

### Cambio estructural

Esta rama altera una propiedad central de la base ajedrecística. Por ello debe tratarse como variante mayor y no como simple añadido.

### Riesgos

- sustituir estrategia posicional por adivinación;
- errores atribuidos a falta de información en vez de decisiones tácticas;
- pérdida de legibilidad del presupuesto rival;
- snowball por ventaja informacional.

### Prototipo mínimo sugerido

Cada pieza revela casillas a distancia 2; el resto del tablero permanece visible, pero las piezas enemigas fuera de visión se ocultan.

### Criterio de avance

La información parcial debe producir decisiones de exploración, engaño o cobertura; si sólo genera sorpresas inevitables, la rama fracasa.

---

## 10.5. E5 · AUTO

### Pregunta de diseño

¿Qué ocurre si el jugador deja de controlar directamente toda ejecución de las piezas?

### Transformación

Separar orden e implementación mediante comportamientos predefinidos o programables.

### Variantes

**Órdenes simples**

- avanzar;
- proteger;
- perseguir;
- mantener posición.

**Prioridades**

- atacar objetivo de mayor valor;
- interceptar pieza más cercana al Rey;
- ocupar casilla objetivo.

**Scripts limitados**

- condiciones y acciones reutilizables.

### Decisiones nuevas esperadas

- configurar comportamiento antes de conocer el resultado exacto;
- elegir cuánto PA invertir en órdenes frente a movimientos directos;
- diseñar respuestas robustas a situaciones cambiantes.

### Acoplamiento con P0

Hay varias opciones:

1. programar cuesta PA;
2. activar una unidad ejecuta automáticamente su orden;
3. las unidades actúan solas al final del turno;
4. el jugador sólo puede intervenir un número limitado de veces.

No deben probarse simultáneamente.

### Riesgos

- frustración por discrepancia entre intención y ejecución;
- dificultad para atribuir errores;
- IA trivial o explotable;
- transición desde táctica directa hacia programación demasiado rápida.

### Prototipo mínimo sugerido

Sólo una pieza especial por jugador recibe una orden entre tres comportamientos discretos; al activarse, ejecuta automáticamente una acción legal según esa prioridad.

### Criterio de avance

El jugador debe razonar sobre comportamiento futuro, no sentirse simplemente privado de control.

---

## 10.6. E6 · DEFENCE

### Pregunta de diseño

¿Qué ocurre si la decisión principal se desplaza desde el movimiento durante el combate hacia la configuración previa?

### Transformación

Invertir parcialmente la relación entre despliegue y ejecución: el jugador prepara una posición y después observa una resolución automatizada o semiautomatizada.

### Concepto

El jugador dispone de:

- una zona de despliegue;
- un conjunto limitado de piezas;
- información sobre amenazas o enemigos;
- recursos de colocación/configuración.

Después de preparar:

- el enemigo avanza;
- las piezas ejecutan reglas automáticas;
- el jugador puede tener cero, pocas o varias intervenciones limitadas.

### Decisiones nuevas esperadas

- optimizar cobertura espacial;
- predecir trayectorias;
- construir redundancia;
- aceptar sacrificios locales para maximizar supervivencia global.

### Diferencia respecto al núcleo

E6 no es necesariamente «otro modo» de P0. Puede convertirse en un concepto independiente, cercano a puzzle táctico, tower defence o auto-battler.

### Riesgos

- que exista una colocación óptima única;
- poca agencia tras iniciar la resolución;
- necesidad excesiva de ensayo/error;
- baja rejugabilidad si los ataques son fijos.

### Prototipo mínimo sugerido

Tablero 6×6; cuatro piezas defensivas; tres oleadas deterministas; una única intervención de 2 PA durante cada oleada.

### Criterio de avance

La colocación inicial debe permitir estrategias diferentes y la resolución debe revelar consecuencias comprensibles de esas decisiones.

---

# 11. Relación entre ramas

## 11.1. Compatibilidades plausibles

| Combinación | Potencial |
|---|---|
| P0 + TERRAIN | fuerte: los PA pueden expresar coste espacial |
| P0 + MORPH | fuerte pero complejo: competir por actuar sobre piezas o tablero |
| P0 + LAW | fuerte: el valor del presupuesto depende del reglamento temporal |
| P0 + FOG | incierto: multiplica incertidumbre sobre combinaciones de PA |
| P0 + AUTO | fuerte si órdenes consumen o transforman activaciones |
| TERRAIN + FOG | plausible: terreno como cobertura/visibilidad |
| MORPH + LAW | arriesgado: dos fuentes simultáneas de mutabilidad |
| AUTO + DEFENCE | muy fuerte: E6 puede ser una especialización de E5 |

## 11.2. Combinaciones que requieren cautela

- **MORPH + FOG:** modifica simultáneamente el espacio real y el espacio conocido.
- **LAW + FOG:** reglas cambiantes más información parcial pueden erosionar causalidad y aprendizaje.
- **MORPH + LAW + AUTO:** tres capas de indirectitud antes de haber demostrado el núcleo.

## 11.3. Hipótesis de arquitectura conceptual

Una posible organización futura sería:

```text
ESCAQUE CORE
├── economía de PA
├── piezas y movimiento
└── captura / objetivo

MÓDULOS DE ESTADO DEL MUNDO
├── TERRAIN
└── MORPH

MÓDULOS DE REGLAMENTO / INFORMACIÓN
├── LAW
└── FOG

MÓDULOS DE AGENCIA
├── AUTO
└── DEFENCE
```

Esta organización es provisional y no debe tratarse todavía como arquitectura definitiva del producto.

---

# 12. Orden de experimentación propuesto

El orden se basa en aislamiento de variables, no en prioridad comercial.

### Fase 0 — P0

Validar economía de PA, costes y Reserva.

### Fase 1 — P0.2 / balance nuclear

Ajustar:

- PA base;
- reserva máxima;
- costes;
- colocación inicial;
- condición de victoria si fuera necesario.

### Fase 2 — TERRAIN

Es la extensión menos destructiva del espacio base.

### Fase 3 — LAW o MORPH

Probar una sola transformación estructural adicional.

### Fase 4 — FOG

Sólo después de comprobar que el juego completo es legible con información perfecta.

### Fase 5 — AUTO / DEFENCE

Tratar como ramas de agencia potencialmente divergentes del núcleo táctico directo.

Este orden es una propuesta metodológica, no una decisión cerrada de producción.

---

# 13. Implementación inicial digital

## 13.1. Objetivo

Crear una versión digital mínima equivalente a P0 de papel que permita:

- ejecutar partidas locales 1v1;
- verificar legalidad de movimientos;
- gestionar PA y Reserva;
- registrar eventos básicos para evaluación;
- modificar parámetros sin reescribir reglas centrales.

## 13.2. Plataforma y motor

No se fija motor en este GDD. El prototipo requiere únicamente:

- cuadrícula 2D;
- entrada por ratón o equivalente;
- representación simple de piezas;
- lógica por turnos;
- exportación o visualización de logs.

Godot, Unity u otros motores 2D son suficientes, pero la selección queda fuera de P0.

## 13.3. Arquitectura mínima de juego

Entidades recomendadas:

### GameState

Contiene:

- turno actual;
- jugador activo;
- PA disponibles;
- Reserva de ambos jugadores;
- piezas activadas este turno;
- posición de todas las piezas;
- estado de victoria.

### Board

Responsable de:

- límites 8×8;
- ocupación de casillas;
- consultas de trayectoria;
- movimiento/captura.

### Piece

Datos mínimos:

```text
id
owner
piece_type
position
activation_cost
activated_this_turn
```

### PieceRule / MoveGenerator

Responsable de generar movimientos legales según tipo de pieza.

### TurnController

Responsable de:

- comenzar turno;
- añadir Reserva;
- consumir PA;
- impedir segunda activación;
- finalizar turno;
- guardar hasta 2 PA;
- cambiar jugador activo.

### VictorySystem

Comprueba la captura del Rey.

### MatchLogger

Registra eventos para evaluación.

## 13.4. Separación de datos y reglas

Los costes deben almacenarse como datos configurables:

```text
Pawn   = 1
Knight = 2
Rook   = 3
King   = 2
```

También:

```text
base_AP = 6
max_reserve = 2
board_size = 8
```

Esto permitirá probar variantes sin modificar código estructural.

## 13.5. Estados de interacción

Interfaz mínima:

```text
WAITING_FOR_SELECTION
→ PIECE_SELECTED
→ SHOW_LEGAL_MOVES
→ MOVE_CONFIRMED
→ STATE_UPDATED
→ WAITING_FOR_SELECTION
```

El jugador también debe poder seleccionar:

**END TURN**

cuando lo desee.

## 13.6. Información visible

La UI mínima muestra:

- jugador activo;
- PA disponibles;
- Reserva futura estimada al terminar ahora;
- coste de la pieza seleccionada;
- piezas ya activadas;
- movimientos legales;
- botón Fin de turno.

No son necesarios:

- animaciones complejas;
- modelos 3D;
- efectos;
- sonido;
- menú de campaña;
- IA enemiga.

## 13.7. Telemetría mínima

Por partida:

- jugador inicial;
- ganador;
- duración en turnos;
- motivo de final.

Por turno:

- PA iniciales;
- PA gastados;
- PA reservados;
- número de activaciones;
- secuencia de tipos activados.

Por acción:

- pieza;
- coste;
- origen;
- destino;
- captura sí/no;
- tipo capturado si procede.

---

# 14. Criterios de aceptación de la implementación P0

La implementación inicial se considera funcional cuando:

1. reproduce exactamente la disposición inicial definida;
2. alterna turnos correctamente;
3. otorga 6 PA + Reserva;
4. impide activar dos veces la misma pieza;
5. aplica correctamente costes 1/2/3/2;
6. valida movimientos de Peón, Caballo, Torre y Rey;
7. resuelve capturas;
8. termina la partida al capturar un Rey;
9. conserva como máximo 2 PA;
10. permite terminar turno voluntariamente;
11. muestra de forma inequívoca PA, Reserva y piezas agotadas;
12. registra el log mínimo de partida.

No se requiere balance para declarar la implementación funcional.

---

# 15. Plan de pruebas inicial

## 15.1. Pruebas funcionales

- costes descontados correctamente;
- Reserva no supera 2;
- PA no puede quedar negativo;
- pieza agotada no puede reactivarse;
- Caballo salta piezas;
- Torre no atraviesa piezas;
- Peón captura sólo diagonalmente;
- Rey puede entrar en amenaza;
- captura del Rey finaliza inmediatamente.

## 15.2. Pruebas de diseño

Comparar C0 y P0.

Registrar si aparecen:

- ahorro deliberado de PA;
- secuencias de activación dependientes del orden;
- concentración vs dispersión de acciones;
- combinaciones dominantes;
- turnos de preparación;
- dificultad excesiva para anticipar al rival.

## 15.3. Primera batería

1. C0 — referencia.
2. P0 — primera exposición.
3. P0 — colores invertidos.
4. P0 — segunda partida con conocimiento previo.
5. C0 — retorno al control.
6. P0 — comprobación de aprendizaje.

---

# 16. Preguntas abiertas

## Núcleo

- ¿6 PA es el presupuesto adecuado?
- ¿Reserva 2 produce tensión o una rutina dominante?
- ¿debe mantenerse «una activación por pieza»?
- ¿el Rey debe seguir costando 2 PA?
- ¿la Torre a 3 PA ofrece demasiado valor por activación?
- ¿la colocación inicial contiene suficiente interacción temprana?
- ¿capturar al Rey sin jaque genera finales legibles?

## Ramas

- TERRAIN: ¿coste de movimiento o modificación de capacidad?
- MORPH: ¿alteración previa o durante la partida?
- LAW: ¿secuencia conocida, aleatoria o manipulable?
- FOG: ¿ocultar posición, identidad o ambas?
- AUTO: ¿orden discreta o programación?
- DEFENCE: ¿cuánta intervención debe conservar el jugador durante la resolución?

---

# 17. Decisiones, propuestas e incertidumbres

## DECIDIDO para P0

- tablero 8×8;
- 2 jugadores;
- 8 piezas por jugador;
- 6 PA base;
- Reserva máxima 2;
- costes: Peón 1, Caballo 2, Torre 3, Rey 2;
- una activación por pieza y turno;
- captura determinista;
- información completa;
- ausencia de azar;
- victoria por captura del Rey;
- sin jaque, promoción, enroque ni *en passant*.

## PROPUESTO

- comparación experimental C0/P0;
- telemetría mínima;
- arquitectura modular de implementación;
- orden de experimentación de ramas.

## ABIERTO

- balance numérico;
- estética;
- ficción;
- motor;
- plataforma;
- ramas que formarán parte de una eventual versión completa;
- progresión RPG y campaña.

---

# 18. Criterio de avance desde P0

P0 no debe evolucionar porque «funcione técnicamente», sino porque demuestre que su economía de activaciones produce decisiones no triviales y legibles.

Se considera evidencia favorable si, tras varias partidas:

- gastar todos los PA no es siempre dominante;
- reservar siempre 2 PA tampoco lo es;
- distintas combinaciones de activación aparecen por razones posicionales;
- el orden de activaciones importa;
- el jugador puede explicar por qué tomó una secuencia concreta;
- el sistema no queda resuelto por una pauta única de activación.

Si estas condiciones no aparecen, el siguiente paso debe ser modificar el núcleo de PA antes de introducir TERRAIN, MORPH, LAW, FOG, AUTO o DEFENCE.

---

# 19. Síntesis canónica provisional

```text
ESCAQUE P0

Base:
    tablero táctico determinista de información completa

Núcleo:
    6 PA por turno
    + hasta 2 PA de Reserva
    + costes distintos por pieza
    + una activación por pieza

Decisión recurrente:
    qué objetivos perseguir mediante qué combinación de piezas
    y cuánto potencial reservar para el siguiente turno

Bucle:
    leer → priorizar → activar → capturar/reposicionar → reservar → reevaluar

Victoria:
    capturar al Rey enemigo

Ramas experimentales:
    TERRAIN / MORPH / LAW / FOG / AUTO / DEFENCE
```

**Fin · GDD ESCAQUE v0.1 · BORRADOR / PROPUESTO**
