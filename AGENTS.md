# Reglas obligatorias de arquitectura y calidad del código

## 1. Principio fundamental

Todo código nuevo que se incorpore al proyecto debe estar organizado de forma profesional, modular, escalable y con una separación estricta de responsabilidades.

**Cada archivo, módulo, clase y función debe tener una responsabilidad clara y bien definida.**

El objetivo es mantener una arquitectura limpia, fácil de entender, mantener, probar y ampliar, tanto para desarrolladores humanos como para agentes de inteligencia artificial.

Estas reglas son obligatorias para cualquier implementación, refactorización o modificación de código.

## 2. Separación estricta de responsabilidades

* Cada archivo debe encargarse de una única responsabilidad principal, claramente identificable.
* No crear archivos que mezclen lógica de negocio, presentación, acceso a datos, validaciones, gestión de estado y otras responsabilidades independientes.
* Cuando un archivo comience a acumular responsabilidades diferentes, dividirlo en módulos más pequeños y especializados.
* Las clases, funciones y componentes deben tener un propósito concreto y no asumir tareas que correspondan a otros módulos.
* Evitar la duplicación de lógica. Si una funcionalidad se utiliza en varios lugares, evaluar si corresponde extraerla a un módulo compartido.
* Mantener una separación clara entre las capas de presentación, lógica de negocio, acceso a datos y utilidades, respetando la arquitectura existente.

## 3. Archivos pequeños, claros y especializados

* Evitar archivos excesivamente grandes o difíciles de comprender.
* No concentrar funcionalidades independientes en un único archivo por comodidad o rapidez de implementación.
* Si un archivo crece demasiado o resulta difícil de analizar, evaluar su división en módulos más pequeños.
* No utilizar un límite arbitrario de líneas como único criterio. La prioridad es que cada archivo tenga una responsabilidad coherente y pueda entenderse fácilmente.
* No crear archivos gigantes que obliguen a leer cientos o miles de líneas para comprender una funcionalidad.
* Evitar tanto los archivos monolíticos como la fragmentación excesiva en archivos innecesariamente pequeños.

## 4. Organización profesional de carpetas

* Ubicar cada archivo en la carpeta que corresponda según su responsabilidad y función dentro del sistema.
* Mantener una estructura de directorios coherente, predecible y fácil de navegar.
* Agrupar los módulos relacionados por funcionalidad o dominio, sin mezclar responsabilidades que pertenezcan a capas diferentes.
* Evitar carpetas genéricas que terminen acumulando archivos sin relación entre sí.
* No crear nuevas carpetas o estructuras redundantes cuando ya existe una ubicación apropiada.
* Respetar las convenciones de nombres y la organización establecida en el proyecto.

## 5. Arquitectura y dependencias

* Antes de implementar una funcionalidad, analizar la arquitectura existente y localizar los módulos responsables.
* Reutilizar los sistemas y componentes existentes cuando corresponda, sin duplicar funcionalidades.
* Mantener dependencias claras, explícitas y orientadas hacia las capas correctas.
* Evitar dependencias circulares, acoplamiento innecesario y referencias cruzadas difíciles de mantener.
* No introducir lógica de negocio en componentes visuales ni lógica de presentación en módulos de dominio.
* Diseñar los módulos de manera que puedan evolucionar sin obligar a modificar partes no relacionadas del sistema.

## 6. Prohibición de soluciones improvisadas

No se permite:

* Agregar funcionalidades completas dentro de un archivo existente simplemente porque ya contiene código relacionado.
* Acumular condicionales, funciones auxiliares o lógica independiente en módulos que ya tienen demasiadas responsabilidades.
* Duplicar código para evitar diseñar una solución reutilizable cuando realmente sea necesario.
* Crear abstracciones innecesarias, capas artificiales o patrones de diseño que no aporten valor real.
* Realizar refactorizaciones masivas sin comprender previamente el impacto sobre el sistema.
* Modificar módulos no relacionados con la tarea sin una justificación técnica concreta.

Toda decisión arquitectónica debe responder a una necesidad real y contribuir a la claridad, mantenibilidad y escalabilidad del proyecto.

## 7. Procedimiento obligatorio antes de implementar

Antes de escribir código:

1. Analizar la estructura del proyecto y las convenciones existentes.
2. Identificar los módulos y archivos relacionados con la funcionalidad solicitada.
3. Determinar qué responsabilidades nuevas aparecen y dónde deben ubicarse.
4. Evaluar si es necesario crear nuevos módulos, reutilizar los existentes o dividir archivos que ya concentran demasiadas responsabilidades.
5. Definir una solución que respete la arquitectura y minimice el acoplamiento.

Si la implementación requiere modificar un archivo que ya tiene demasiadas responsabilidades, evaluar su modularización antes de agregar más lógica.

## 8. Procedimiento obligatorio después de implementar

Al finalizar:

1. Verificar que cada archivo nuevo tenga una responsabilidad clara.
2. Comprobar que la funcionalidad esté correctamente distribuida entre los módulos correspondientes.
3. Revisar que no se hayan introducido duplicaciones, dependencias innecesarias o archivos excesivamente grandes.
4. Verificar que las importaciones, referencias y dependencias sean coherentes.
5. Ejecutar las comprobaciones, pruebas o validaciones disponibles que correspondan.
6. Informar qué archivos se crearon, cuáles se modificaron y qué responsabilidad cumple cada uno.

## 9. Criterio de calidad profesional

El código debe cumplir con los siguientes criterios:

* Modularidad y separación de responsabilidades.
* Claridad y legibilidad.
* Bajo acoplamiento y cohesión adecuada.
* Facilidad de mantenimiento y extensión.
* Organización consistente de carpetas y archivos.
* Reutilización razonable de componentes y lógica.
* Facilidad de análisis por parte de otros desarrolladores y agentes de IA.

## 10. Regla final

**Nunca priorizar la rapidez de implementación por encima de una arquitectura clara y mantenible.**

Toda funcionalidad nueva debe integrarse de manera ordenada, respetando las responsabilidades de cada módulo y evitando que el proyecto se convierta progresivamente en una colección de archivos grandes, confusos y difíciles de mantener.

Si existen varias soluciones posibles, elegir aquella que mantenga una separación de responsabilidades clara, minimice el acoplamiento y facilite la evolución futura del sistema.

Estas reglas deben aplicarse de manera consistente en todas las tareas, incluso cuando la solicitud del usuario no mencione explícitamente la arquitectura o la modularización.

## 11. Información del repositorio y convenciones de Git

* **Repositorio oficial:** `https://github.com/Lorenzo-Imvinkelried/rpgodot.git`

### Formato obligatorio de commits:

* **Idioma:** Siempre en español.
* **Longitud:** Corto y conciso.
* **Título (primera línea):** Escrito en imperativo (por ejemplo: `Añade...`, `Arregla...`, `Refactoriza...`, `Actualiza...`, `Elimina...`).
* **Cuerpo (body):** Explicación breve del *porqué* del cambio (motivo o necesidad técnica).

**Ejemplo de commit:**
```text
Añade sincronización de cámara con pivote de rotación

Evita el retraso opuesto al girar con A/D haciendo que el pivote y la cápsula roten juntos en el mismo frame.
```

---

## 12. Arquitectura objetivo del proyecto (`rpgodot`)

El proyecto sigue una organización modular orientada a sistemas y dominios de juego.

> [!IMPORTANT]
> **Estructura evolutiva (bajo demanda):** La siguiente es una **estructura objetivo**, no un árbol de carpetas que deba crearse vacío de golpe. Cada carpeta y subcarpeta debe crearse únicamente cuando exista una responsabilidad real y archivos concretos que justifiquen su existencia.

```text
rpgodot/
├── AGENTS.md
├── project.godot
├── listar_carpetas.bat
│
├── assets/                  # Recursos brutos de arte, sonido y multimedia
│   ├── models/              # Modelos 3D (characters, enemies, environments, weapons)
│   ├── animations/          # Archivos y pistas de animación
│   ├── textures/            # Texturas y mapas de materiales
│   ├── audio/               # Efectos de sonido (SFX) y música
│   └── materials/           # Materiales compartidos (.tres de BaseMaterial3D/ShaderMaterial)
│
├── config/                  # Archivos de configuración externa (JSON / planos)
│   ├── gameplay/            # Parámetros numéricos y balance de juego
│   ├── network/             # Puertos, IPs por defecto, tasas de tick
│   └── rendering/           # Ajustes gráficos y visuales
│
├── resources/               # Recursos nativos tipados de Godot (.tres / .res)
│   ├── characters/          # Definiciones base de personajes
│   ├── combat/              # Configuraciones de ataques, animaciones y combos
│   ├── items/               # Definiciones de equipamiento y consumibles
│   ├── enemies/             # Datos de arquetipos de enemigos
│   └── player/              # Recursos exclusivos de configuración del jugador
│
├── scenes/                  # Árbol de nodos y escenas instanciables (.tscn)
│   ├── characters/          # Variantes visuales o arquetipos de personajes
│   ├── combat/              # Escenas de combate, dummies y FX instanciables
│   ├── enemies/             # Escenas de enemigos con sus controladores
│   ├── world/               # Niveles, mapas, zonas y puntos de aparición
│   ├── player/              # Escena principal del jugador humano (player.tscn)
│   ├── ui/                  # HUD, menús, barras de estado y ventanas
│   └── network/             # Nodos de red y sincronizadores
│
├── scripts/                 # Código fuente GDScript estructurado por capas y dominio
│   ├── core/                # Fundamentos y utilidades agnósticas de gameplay
│   │   ├── events/          # Event buses globales o señales desacopladas
│   │   ├── utilities/       # Métodos matemáticos, serializadores, helpers
│   │   └── managers/        # Gestores globales o singletons de bajo nivel
│   │
│   ├── gameplay/            # Reglas y mecánicas de juego (jugador + enemigos)
│   │   ├── combat/          # Controladores de combate, cálculo de daño, hitboxes
│   │   ├── characters/      # Clases base compartidas entre entes del mundo
│   │   ├── enemies/         # Comportamientos específicos de IA y enemigos
│   │   ├── inventory/       # Lógica de contenedores, slots y mochilas
│   │   ├── items/           # Comportamiento de objetos en juego
│   │   ├── skills/          # Sistema de lanzamiento y cooldowns de habilidades
│   │   └── progression/     # Fórmulas de experiencia, niveles y estadísticas
│   │
│   ├── player/              # Lógica específica y exclusiva del personaje local
│   │   ├── controller/      # Entrada de teclado/ratón (PlayerController)
│   │   ├── movement/        # Locomoción, análisis de zancadas (stride), saltos
│   │   └── abilities/       # Coordinación de habilidades activadas por el input
│   │
│   ├── world/               # Gestión del entorno físico
│   │   ├── maps/            # Carga y streaming de zonas
│   │   ├── spawning/        # Gestión de puntos de aparición de entidades
│   │   └── interaction/     # Cofres, puertas, palancas y gatillos
│   │
│   ├── network/             # Conectividad y arquitectura cliente-servidor
│   │   ├── client/          # Predicción local, recepción de snapshots, interpolación
│   │   ├── server/          # Validación autoritativa, lógica de servidor headless
│   │   ├── synchronization/ # Replicación de variables y RPCs
│   │   └── sessions/        # Autenticación, estados de conexión, reconexiones
│   │
│   ├── ui/                  # Controladores de interfaz de usuario
│   └── tools/               # Scripts de desarrollo, editores y generadores de escenas
│
└── tests/                   # Pruebas automatizadas (unitarias y de integración)
    ├── gameplay/
    ├── network/
    └── utilities/
```

## 13. Límites de sistemas y reglas de desacoplamiento

### 13.1. Separación de `gameplay` vs `player`
* El combate, la vida, las estadísticas y las habilidades **NO pertenecen al jugador**: pertenecen al dominio de `gameplay`.
* Un enemigo, un aliado o un dummy de prueba deben poder utilizar los mismos componentes de combate ([combat_controller.gd](file:///c:/Users/HP/Desktop/LORENZO/rpgodot/scripts/combat/combat_controller.gd)) y recibir daño sin importar si el dueño es un jugador humano o un NPC.
* La carpeta `player/` contiene únicamente lo que corresponde al avatar del usuario: traducción de inputs, control de cámara, interpolación local y animaciones específicas de la malla del jugador.

### 13.2. Separación entre Lógica Autoritativa y Presentación Visual
* **Lógica Pura / Dominio (Servidor + Cliente):** Cálculo numérico de daño, aplicación de cooldowns, detección de si un ataque impactó según distancias y estados. Estos scripts **nunca** deben instanciar partículas ni depender de nodos gráficos.
* **Presentación / Efectos (Cliente y Herramientas):** Números de daño flotantes ([damage_number_fx.gd](file:///c:/Users/HP/Desktop/LORENZO/rpgodot/scripts/combat/damage_number_fx.gd)), efectos de impacto ([hit_fx.gd](file:///c:/Users/HP/Desktop/LORENZO/rpgodot/scripts/combat/hit_fx.gd)), barras de vida en pantalla ([health_bar_3d.gd](file:///c:/Users/HP/Desktop/LORENZO/rpgodot/scripts/combat/health_bar_3d.gd)), sonidos y animación. Estos elementos solo reaccionan a señales emitidas por la lógica. Pueden ejecutarse tanto en el cliente final como en herramientas de editor (`@tool`), escenas de test y sandbox locales de prueba.

## 14. Modelo de red: Servidor Dedicado Autoritativo

El proyecto tiene como **arquitectura objetivo** un modelo de juego multijugador con **Servidor Dedicado Autoritativo** (`Godot Headless`).

> [!NOTE]
> **Flexibilidad en fase de prototipado:** El servidor dedicado es el norte arquitectónico, pero se permiten excepciones justificadas durante las fases iniciales de prototipo y gameplay local. No es necesario sincronizar por red cada mecánica desde el día uno; la prioridad es desacoplar la lógica para que luego pueda conectarse a la red sin reescrituras masivas.

1. **El cliente nunca decide el estado del mundo:** El cliente no calcula si su golpe acertó ni cuánta vida le queda al objetivo. El cliente envía un mensaje RPC de *intención* (ejemplo: `solicitar_ataque(posicion, id_habilidad)`).
2. **El servidor autoriza y valida:** El servidor ejecuta la simulación, valida que el jugador tenga recursos/cooldown suficientes, calcula el daño y replica el resultado.
3. **El cliente predice e interpola:** Para que la experiencia sea reactiva y sin retraso perceptible, el cliente predice visualmente el inicio del movimiento o la animación, rectificando la posición suavemente si el servidor envía una corrección.
4. **Ejecución Headless:** La lógica de servidor debe poder correr sin GPU ni monitor (`--headless`). Cualquier dependencia con recursos gráficos, shaders o ventanas en código que deba correr en servidor romperá la arquitectura.

## 15. Migración y reutilización de lógica (C++ 2D a Godot 3D)

Al portar sistemas del proyecto C++ 2D (`RPGARENA`) hacia `rpgodot`, clasificar cada módulo en tres categorías obligatorias:

| Categoría | Ejemplo | Tratamiento en Godot |
| :--- | :--- | :--- |
| **Reglas de Juego Puras** | Fórmulas de daño, tablas de loot, mitigación por armadura, experiencia, árboles de talentos. | **Reutilizar/Adaptar:** Portar a GDScript tipado puro (`RefCounted` / scripts estáticos) o mantener en C++ mediante GDExtension si la complejidad matemática lo justifica. Independientes de nodos 3D. |
| **Lógica ligada a 2D** | Coordenadas cartesianas 2D, ordenamiento de profundidad, colisiones ortogonales. | **Rediseñar a 3D:** Usar `CharacterBody3D`, `Vector3`, `RayCast3D`, `ShapeCast3D` y los sistemas de física 3D de Godot. |
| **Lógica de motor propia** | Manejador de ventanas, bucle de renderizado, atlas de sprites, sincronización de hilos. | **Reimplementar:** Delegar en las APIs nativas de Godot 4 (SceneTree, AnimationPlayer, RenderServer). |

## 16. Protocolo de toma de decisiones para IA y desarrolladores

Antes de crear un archivo o modificar uno existente:
1. **Identificar la capa:** ¿Es `core` (utilidad general), `gameplay` (mecánica compartida), `player` (interfaz del jugador), `network` (comunicación) o `ui` (pantalla)?
2. **Verificar el contexto de ejecución:** ¿Este script correrá en el servidor dedicado, en el cliente, o en ambos? Si corre en el servidor, no puede contener lógica visual ni de sonido.
3. **Comprobar si existe un componente análogo:** Si vas a añadir una habilidad a un enemigo, verifica si `gameplay/skills` o `gameplay/combat` ya disponen de la estructura antes de inventar una solución paralela.
4. **Tipado estático razonable:** Emplear tipado estático explícito en firmas de funciones públicas, APIs de dominio y parámetros clave (`var target: Node3D = null`, `func calculate_damage(...) -> int:`). Evitar caer en sobre-ingeniería o tipados enrevesados para scripts utilitarios simples o expresiones efímeras.


