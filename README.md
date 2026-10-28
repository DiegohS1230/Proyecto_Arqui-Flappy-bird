# Proyecto_Arqui-Flappy-bird
Flappy Bird en Ensamblador para DOSBox
Videojuego inspirado en Flappy Bird, desarrollado en ensamblador x86 para ejecutarse en un entorno DOS. El programa utiliza gráficos VGA, entrada por teclado y sonidos generados mediante el altavoz del PC emulado.
Tabla de contenidos
- Descripción
- Características
- Tecnologías y requisitos
- Estructura y funcionamiento
- Controles
- Cómo ejecutar el juego en DOSBox
- Compilar el programa
- Variables principales
- Personalización
- Limitaciones y notas
- Solución de problemas
Descripción
El objetivo es controlar un pájaro que se desplaza por la pantalla y evitar chocar con los obstáculos. El jugador presiona la barra espaciadora para impulsarlo hacia arriba mientras la gravedad lo hace descender. Cada vez que supera un conjunto de obstáculos, obtiene un punto.

El juego presenta una pantalla de bienvenida, obstáculos con aberturas de posición y tamaño variables, un marcador, sonidos y una pantalla de fin de partida. La dificultad aumenta a medida que se consiguen puntos.
Características
- Pantalla de bienvenida: muestra el título, un pájaro decorativo y obstáculos. Presione ENTER para comenzar.
- Gráficos VGA: dibuja directamente en el modo de video 13h, con una resolución de 320 × 200 píxeles y 256 colores.
- Movimiento del pájaro: aplica una velocidad vertical y gravedad; la barra espaciadora produce un impulso ascendente.
- Obstáculos variables: las aberturas cambian de posición y altura cuando aparece un nuevo obstáculo.
- Puntuación: suma un punto al superar cada obstáculo.
- Dificultad progresiva: aumenta la velocidad de los obstáculos por niveles de puntuación y reduce la abertura durante la partida, con límites definidos en el código.
- Contador de muertes: muestra cuántas veces se ha producido una colisión durante la sesión.
- Pausa: permite detener temporalmente la partida y reanudarla.
- Efectos de sonido: reproduce tonos para el salto, la puntuación y las colisiones usando el temporizador y el altavoz del PC.
- Pantalla Game Over: muestra la puntuación, el mejor resultado de la sesión y el contador de muertes; permite reintentar o salir.
