# Portal-Cautivo

El script es una herramienta de automatización diseñada para montar un ataque de red conocido como Evil Twin (Mellizo Malvado) combinado con un Portal Cautivo Falso (Phishing de red).

Su objetivo es suplantar una red Wi-Fi legítima para que los usuarios se conecten a ella y, posteriormente, engañarlos para que introduzcan información confidencial en una página web falsa.

A continuación se detalla qué hace cada una de sus partes principales desde el punto de vista técnico:

1. Preparación de la Interfaz Inalámbrica
Desactivación de interferencias: Utiliza el comando airmon-ng check kill para detener cualquier servicio del sistema (como NetworkManager o wpa_supplicant) que pueda utilizar la tarjeta Wi-Fi. Esto se hace para que la tarjeta quede completamente libre y disponible.

Creación del Punto de Acceso: Configura un archivo para hostapd, un software que permite transformar una tarjeta de red Wi-Fi normal en un punto de acceso (un enrutador inalámbrico) que emite un nombre de red (SSID) elegido por el atacante (por defecto, "WiFi_Gratis").

2. Gestión y Enrutamiento de la Red
Servidor DHCP y DNS (dnsmasq): Configura la red simulada en el rango de IPs 200.200.200.X. Cuando una víctima se conecta, este servicio le asigna una IP automáticamente. Además, utiliza una directiva (address=/#/200.200.200.1) que actúa como un "DNS falso": cualquier página web que la víctima intente buscar (por ejemplo, google.com) será redirigida obligatoriamente a la IP del atacante (200.200.200.1).

Manipulación del Tráfico (iptables): Modifica las reglas del cortafuegos de Linux para interceptar todo el tráfico web del puerto 80 (HTTP) y redirigirlo hacia el servidor local del atacante.

3. Captura de Datos y Servidor Web (servidor_pro.py)
Suplantación de Identidad: Levanta un servidor web básico en Python que carga una página de inicio de sesión falsa (el script hace referencia a un archivo llamado portal_carrefour.html).

Interceptación (Phishing): Cuando la víctima intenta navegar, le aparece esta página simulando ser un portal legítimo pidiendo datos.

Almacenamiento de Credenciales: Cuando la víctima introduce datos y pulsa el botón de enviar (petición POST), el script de Python captura la fecha, la hora, la dirección IP, la dirección MAC del dispositivo y el texto que la víctima escribió, guardándolo todo en un archivo de texto llamado datos.txt.

Simulación de Acceso: Tras robar los datos, el script ejecuta reglas de iptables para darle internet momentáneamente a esa IP específica, haciendo creer a la víctima que el portal funcionó correctamente y así evitar levantar sospechas.

4. Monitorización y Limpieza
Ventana de control: Abre una terminal secundaria (.monitor.sh) que muestra en tiempo real qué dispositivos están conectados al punto de acceso falso y enseña las últimas líneas del archivo donde se guardan los datos robados.

Borrado de huellas: Incluye funciones para detener todos los procesos creados (hostapd, dnsmasq, python), restaurar el cortafuegos a su estado original y borrar los archivos de configuración temporales para no dejar rastro en el equipo del atacante.
