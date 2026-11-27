# Guía de Charm Sniping en MHGU

[English](charm-sniping-en.md) | [Português (Brasil)](charm-sniping-pt-BR.md) | [Español](charm-sniping-es.md)

Esta guía explica cómo conseguir talismanes específicos (incluidos los God Charms) en Monster Hunter Generations Ultimate mediante **MHGU Charms RNG** y el método de combinación de objetos. La aplicación calcula posiciones y tiempos del RNG; no modifica el juego ni la partida guardada. No necesitas una Switch modificada ni Python.

## 1. Descarga la aplicación

Descarga el ZIP correspondiente a tu sistema desde la [última versión](https://github.com/jasmithc/mhgu-rng-app/releases/latest).

- **Windows:** extrae todos los archivos, conserva las DLL junto al ejecutable y abre MHGU Charms RNG.exe.
- **macOS:** extrae el ZIP y mueve la aplicación a la carpeta Aplicaciones.
- Para los avisos de seguridad, requisitos e instalación opcional en iPhone/iPad, consulta el [README](../../README.md).

Esta guía utiliza los nombres de botones y objetos en inglés. Mantén **Language** en English.

## 2. Prepara el juego

- Retira los camaradas Palico que te acompañan y selecciona a la recepcionista de la aldea Moga para el servicio de habitación (Room Service).
- Lleva Combo Book 1, 99 Huskberries y 99 Needleberries. Asegúrate de que la receta de Normal S Lv2 tenga un 100 % de probabilidad de éxito y de no llevar munición Normal S Lv2 en la bolsa.
- Para Enduring Charms, desbloquea Juju Melding y lleva **tres King Talismans (azul oscuro, rareza 6)** que no te importe utilizar para la fusión. Esta es la combinación que recomiendo y corresponde al Rank 4. Los talismanes Queen y Dragon también sirven, pero recomiendo usar tres King Talismans.
- Comprueba que haya espacio en el álbum de la Switch para un vídeo de 30 segundos.
- Guarda en la aldea Kokoto con todo preparado. Volverás a esta partida guardada después de cada intento fallido.

**No corras desde que cargues tu personaje hasta que confirmes la fusión (Melding).** Correr puede hacer que el RNG avance de forma impredecible. Camina siempre, incluso de camino a tu habitación. Una vez confirmada la fusión, podrás volver a correr.

## 3. Busca el talismán deseado

Abre **Charm Search**. Usa los ajustes predefinidos de **God charms** o selecciona manualmente el tipo de talismán, las habilidades, los puntos y las ranuras. Por ejemplo: Enduring, Tenderizer +6, Expert +10, tres ranuras y **Source: Melding**.

- **Exact:** busca coincidencias exactas con los requisitos seleccionados.
- **At least:** busca talismanes que cumplan o superen los requisitos.

Establece **Start frame** en 0 y elige la cantidad en **Frames to search** (auméntala si no encuentras resultados). Activa **Set Continue Cycles target to the frame found** y pulsa **Run**.

Anota el frame del resultado deseado. El primer resultado rellena automáticamente **Target frame** en el panel de temporizadores; cámbialo manualmente si eliges otro resultado. Para practicar, empieza con un talismán posible que aparezca relativamente pronto en la secuencia. Para otros tipos, comprueba el Melding y los puntos de acierto correspondientes.

## 4. Calcula los Continue Cycles

Cada vez que seleccionas Continue, el RNG avanza aproximadamente 702 posiciones adicionales. Normalmente también avanza a 30 frames por segundo.

La calculadora **Continue Cycles** estima cuántos ciclos necesitas, dejando unos dos minutos de margen. El objetivo de **Continue Counter** se actualiza automáticamente.

Empieza con **Pace** a 60 BPM. Cuando tengas práctica, prueba 75 o 90 BPM. Por encima de 90 BPM, puede que la pantalla no termine de cargar a tiempo para registrar B y que la siguiente pulsación de A cargue accidentalmente el personaje.

### Usar la opción Poogie como margen de seguridad

La función original de **Poogie?** es restar cinco Continue Cycles para dejar tiempo para retirar a Poogie. En mis pruebas satisfactorias no tuve que retirarlo, pero activé esta opción igualmente como margen de seguridad.

Recomiendo activarla aunque dejes a Poogie en la habitación. Esos cinco ciclos menos proporcionan margen adicional si pulsas Continue demasiadas veces por accidente o tardas más de lo previsto. Es preferible llegar antes y esperar un poco más que sobrepasar el frame objetivo.

## 5. Realiza los Continue Cycles

1. Cierra completamente MHGU y vuelve a abrirlo.
2. En el menú inicial, inicia **Continue Counter**.
3. Con cada señal sonora, pulsa A sobre Continue y, cuando aparezca la selección de personaje, pulsa B para volver al menú inicial.
4. En la última cuenta (una señal más larga y aguda), selecciona Continue y carga el personaje en lugar de volver al menú inicial.

Mantén un ritmo constante. Si el objetivo está muy cerca del inicio de la secuencia, puede que no necesites ciclos; carga el personaje y continúa.

## 6. Identifica tu posición actual en el RNG

### Prepara la combinación

1. Ve a tu habitación caminando, sin correr. Retirar a Poogie es opcional, según las pruebas mencionadas anteriormente.
2. Abre la **Combo List** y localiza Normal S Lv2 (Huskberry + Needleberry).
3. Pulsa A **una vez** para seleccionar la receta y abrir el pequeño menú Combine. **Todavía no inicies el Stopwatch.**

### Combina los objetos y cronometra

1. Con el pequeño menú Combine ya abierto, prepara el **Stopwatch** de la aplicación (pulsa Reset si es necesario).
2. Pulsa A de nuevo y mantenlo pulsado para empezar a combinar. **Inicia el Stopwatch exactamente en el instante en que empieces a mantener pulsado A.**
3. Mantén A pulsado hasta alcanzar 99 unidades de munición y que no se puedan combinar más.

La primera pulsación abre el menú; la segunda, manteniendo A pulsado, inicia las combinaciones y el Stopwatch.

### Graba y suspende el juego

1. Cuando llegues a 99, suelta A.
2. **Mantén pulsado el botón de captura de la Switch** para guardar un vídeo de los 30 segundos anteriores.
3. Deja que el Stopwatch siga contando mientras se guarda el vídeo.
4. **Pulsa HOME en la Switch y detén el Stopwatch exactamente en el mismo instante.**

No detengas el Stopwatch al llegar a 99 ni al pulsar Captura. El RNG sigue avanzando hasta que el juego queda suspendido. Mantén MHGU suspendido en el menú HOME durante los siguientes pasos; no cierres ni reanudes el juego.

## 7. Usa Item Combo Search

Reproduce el vídeo en el álbum de la Switch. Pausa y recorre el vídeo para anotar cada cantidad distinta de munición, de 0 a 99, en el orden correcto.

Ejemplo (solo el comienzo de una secuencia ilustrativa): `0 2 4 7 10 13 16 18 22 25 28 30 32 35 39 42 45 … 99`. No escribas los puntos suspensivos: utiliza tu propia secuencia completa, separando los números con espacios.

1. Abre **Item Combo Search**.
2. Pega las cantidades registradas en el campo de combinaciones.
3. Establece el inicio y la cantidad de frames de búsqueda para abarcar la posición esperada antes del objetivo (o empieza en 0 y busca hasta el objetivo si es necesario).
4. Pulsa **Run** y anota el frame indicado.

Utiliza directamente el frame indicado: la herramienta ya tiene en cuenta los avances del RNG provocados por las combinaciones. No vuelvas a sumarlos.

Si no hay coincidencias, aparecen diferencias inválidas o un aviso de baja fiabilidad, revisa cada número y el intervalo de búsqueda. La aplicación también detecta pequeñas irregularidades en el ritmo de las combinaciones (Frame Stutter); no elimines valores solo para forzar una coincidencia. Un intervalo más reducido ayuda a distinguir coincidencias aleatorias.

## 8. Calcula el tiempo de espera

Abre **Frame → Wait Time**. Introduce el frame objetivo, activa **Subtract a baseline frame** y utiliza el frame devuelto por Item Combo Search como referencia. También puedes introducir directamente la diferencia sin activar esa opción.

Ejemplo:

| Información | Frame |
| --- | ---: |
| Objetivo | 296260 |
| Resultado de Item Combo Search | 292660 |
| Diferencia | 3600 |

A 30 frames por segundo, 3600 frames equivalen a dos minutos. Pulsa **Run** para rellenar el tiempo de espera de **Final Countdown**.

La cuenta atrás calcula automáticamente:

**Tiempo restante = Wait Time − Stopwatch + Correction**

No restes el Stopwatch manualmente. En el primer intento, deja Correction en 0. Si el tiempo restante no es positivo o no basta para preparar la fusión, reinicia el intento con menos Continue Cycles.

## 9. Realiza la fusión

1. Con el juego aún suspendido, comprueba los valores de **Final Countdown**.
2. **Reanuda MHGU y pulsa Start Countdown exactamente en el mismo instante.**
3. Camina hasta la recepcionista de tu habitación. No corras.
4. Selecciona Juju Melding para Enduring Charms y elige los tres King Talismans (azul oscuro).
5. Avanza hasta la confirmación final, pero todavía no entregues los talismanes.
6. La aplicación emite una señal cada segundo durante los últimos diez segundos y una señal larga al llegar a cero. **Confirma la fusión al escuchar esa última señal.**

Una vez confirmada la fusión, el resultado ya está determinado y puedes volver a correr.

## 10. Comprueba los resultados sin guardar

Completa una misión para que los resultados estén disponibles.

**No guardes después de completar la misión. Si el juego pregunta si deseas guardar, selecciona No.** Recoge los talismanes de la fusión y comprueba primero los resultados.

- Si has conseguido el talismán deseado, guarda la partida.
- Si no, anota los talismanes recibidos (habilidades, puntos y ranuras; una captura de pantalla resulta útil) y cierra completamente el juego sin guardar. Carga la partida preparada anteriormente para volver a intentarlo.

No guardar un intento fallido conserva los materiales utilizados en las combinaciones y los talismanes entregados para la fusión. Guarda únicamente cuando estés satisfecho con el resultado.

## 11. Corrige el tiempo

Usa **Around a Frame** con el frame objetivo, el tipo de talismán correcto y **Source: Melding** para examinar los talismanes cercanos. **Halcyon / Juju Meld** permite consultar todos los resultados previstos para un frame de entrega concreto; utiliza Juju y Rank 4 para los tres King Talismans recomendados.

Compara las predicciones con los resultados reales. Si descubres que confirmaste 15 frames demasiado tarde, introduce **−15 frames** (o −0,5 segundos) en **Correction** para el siguiente intento. Si confirmaste demasiado pronto, utiliza una corrección positiva. Una corrección positiva aumenta la espera; una negativa la reduce.

Si no logras identificar el resultado cerca del objetivo, revisa la secuencia de combinaciones, si caminaste en lugar de correr, la sincronización de los temporizadores, el Rank del Melding y el intervalo de búsqueda.

## Lista de comprobación rápida

- [ ] Prepara y guarda en Kokoto; elige el talismán objetivo.
- [ ] Activa Poogie como margen de seguridad y calcula los Continue Cycles.
- [ ] Reinicia MHGU y realiza los ciclos.
- [ ] Carga el personaje y camina hasta tu habitación.
- [ ] Abre el pequeño menú Combine de Normal S Lv2.
- [ ] Mantén A pulsado e inicia el Stopwatch a la vez; combina hasta 99.
- [ ] Mantén pulsado Captura para guardar el vídeo de 30 segundos.
- [ ] Pulsa HOME y detén el Stopwatch a la vez.
- [ ] Introduce la secuencia completa en Item Combo Search.
- [ ] Calcula Frame → Wait Time y comprueba Final Countdown.
- [ ] Reanuda el juego e inicia la cuenta atrás simultáneamente.
- [ ] Camina hasta la recepcionista y confirma la fusión con la señal final.
- [ ] Completa una misión sin guardar; comprueba los resultados.
- [ ] Guarda solo si estás satisfecho; en caso contrario reinicia sin guardar y ajusta Correction.

## Enlaces útiles

- [Método original de combinación de objetos (en inglés)](https://github.com/jasmithc/mhgu-rng/blob/main/docs/combo_snipe.md)
- [Rangos y funcionamiento del Melding](https://github.com/jasmithc/mhgu-rng/blob/main/docs/melding.md)
- [Investigación original sobre el RNG](https://github.com/apmnnn/mhxx-rng)
- [Tablas de habilidades de talismanes](https://mhgu.kiranico.com/charms)
- [Vídeo introductorio de Clobincole](https://www.youtube.com/watch?v=6aXJoX2hKOI)
