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

> [!TIP]
> **Referencia de arquitectura del proyecto:** Antes de modificar o crear módulos existentes, consultar la documentación y estructura arquitectónica definida en el repositorio para alinear cualquier cambio con los patrones establecidos.
