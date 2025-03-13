#!/bin/bash
# Automatyczny skrypt instalacji n8n na Raspberry Pi
# Autor: Łukasz Podgórski & Anthropic Claude
# Data: 13.03.2025
# Wersja: 2.6 (simplified permissions)
# Poradnik z serwisu: www.przewodnikai.pl
# Kanał YouTube: https://www.youtube.com/@lukaszpodgorski
#
# GitHub: https://github.com/xshocuspocusxd/RaspberryPi-N8N-Cloudflare-Deployer
#
# wget -O install-n8n.sh https://www.przewodnikai.pl/scripts/rpi-n8n-installer.sh && chmod +x install-n8n.sh

# Ustaw kolory dla lepszej czytelności w terminalu
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

db_user="user"  # Domyślna wartość
db_password="n8n_password"  # Domyślna wartość

# Funkcja wyświetlająca informacje
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Funkcja wyświetlająca sukces
success() {
    echo -e "${GREEN}[SUKCES]${NC} $1"
}

# Funkcja wyświetlająca ostrzeżenia
warning() {
    echo -e "${YELLOW}[UWAGA]${NC} $1"
}

# Funkcja wyświetlająca błędy
error() {
    echo -e "${RED}[BŁĄD]${NC} $1"
}

# Funkcja do weryfikacji, czy użytkownik chce kontynuować
confirm() {
    read -p "Czy chcesz kontynuować? (t/n): " response
    case "$response" in
        [tT][aA][kK]|[tT])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Funkcja do sprawdzenia, czy jesteśmy na Raspberry Pi
check_raspberry_pi() {
    if [ ! -f /proc/device-tree/model ] || ! grep -q "Raspberry Pi" /proc/device-tree/model; then
        error "Ten skrypt jest przeznaczony do uruchomienia na Raspberry Pi."
        exit 1
    fi
}

# Funkcja do sprawdzenia, czy mamy wystarczające uprawnienia
check_privileges() {
    if ! groups | grep -q "sudo\|root"; then
        error "Ten skrypt wymaga uprawnień administratora (sudo)."
        exit 1
    fi
}

# Funkcja do aktualizacji systemu
update_system() {
    info "Aktualizacja systemu..."
    sudo apt update && sudo apt upgrade -y
    success "System zaktualizowany."
}

# Funkcja do instalacji Dockera
install_docker() {
    info "Instalacja Dockera..."
    if ! command -v docker &> /dev/null; then
        curl -sSL https://get.docker.com | sh
        sudo usermod -aG docker $USER
        success "Docker zainstalowany. Wymagany będzie restart systemu."
        
        # Zapisujemy informację, że Docker został świeżo zainstalowany
        touch ~/.docker_fresh_install
        
        # Pytamy o restart systemu
        warning "System musi zostać zrestartowany aby zmiany weszły w życie."
        info "Po restarcie uruchom skrypt ponownie, aby kontynuować instalację."
        read -p "Czy chcesz zrestartować system teraz? (t/n): " restart_now
        if [[ "$restart_now" =~ ^[tT] ]]; then
            info "Restartuję system..."
            sudo reboot
            exit 0
        else
            warning "Pamiętaj o konieczności restartu systemu przed kontynuacją."
            exit 0
        fi
    else
        success "Docker jest już zainstalowany."
    fi
}

# Funkcja do instalacji Docker Compose
install_docker_compose() {
    info "Instalacja Docker Compose..."
    if ! command -v docker-compose &> /dev/null; then
        sudo apt install -y docker-compose
        success "Docker Compose zainstalowany."
    else
        success "Docker Compose jest już zainstalowany."
    fi
}

# Funkcja do konfiguracji n8n
configure_n8n() {
    info "Konfiguracja n8n..."
    
    # Pobierz dane od użytkownika TYLKO RAZ
    read -p "Podaj domenę dla n8n (np. mojadomena-n8n.pl): " domain_name
    read -p "Podaj hasło dla bazy danych PostgreSQL [n8n_password]: " db_password
    db_password=${db_password:-n8n_password}
    
    # Tworzenie katalogu projektu
    mkdir -p ~/n8n
    
    # Tworzenie katalogu danych n8n z odpowiednimi uprawnieniami
    mkdir -p ~/.n8n
    sudo chown -R $USER:$USER ~/.n8n
    sudo chmod -R 755 ~/.n8n
    
    # Tworzenie pliku docker-compose.yml
    cat > ~/n8n/docker-compose.yml << EOF
version: '3'

services:
  postgres:
    image: postgres:15.8
    restart: always
    environment:
      - POSTGRES_USER=${db_user}
      - POSTGRES_PASSWORD=${db_password}
      - POSTGRES_DB=n8n

    volumes:
      - postgres_data:/var/lib/postgresql/data

  n8n:
    image: n8nio/n8n
    user: "root"
    restart: always
    ports:
      - '8443:5678'
    environment:
      - N8N_HOST=localhost
      - N8N_PORT=5678
      - N8N_PROTOCOL=http
      - NODE_ENV=production
      - WEBHOOK_URL=https://${domain_name}
      # Konfiguracja połączenia z PostgreSQL
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=n8n
      - DB_POSTGRESDB_USER=${db_user}
      - DB_POSTGRESDB_PASSWORD=${db_password}
    volumes:
      - ~/.n8n:/home/node/.n8n
    depends_on:
      - postgres

volumes:
  postgres_data:
EOF
    
    success "Konfiguracja n8n utworzona w ~/n8n/docker-compose.yml"
}

# Funkcja do instalacji Cloudflared
install_cloudflared() {
    info "Instalacja Cloudflared..."
    if ! command -v cloudflared &> /dev/null; then
        sudo mkdir -p /usr/local/bin
        cd /usr/local/bin
        sudo curl -fsSL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64 -o cloudflared
        sudo chmod +x cloudflared
        success "Cloudflared zainstalowany. Wersja: $(cloudflared --version)"
    else
        success "Cloudflared jest już zainstalowany. Wersja: $(cloudflared --version)"
    fi
}

# Funkcja pomocnicza do znajdowania pliku poświadczeń
find_credential_file() {
    local tunnel_id=$1
    local credential_file=""
    
    # Możliwe lokalizacje plików poświadczeń
    local cloudflared_dirs=("/root/.cloudflared" "$HOME/.cloudflared")
    
    # Szukaj pliku JSON z ID tunelu w znalezionych katalogach
    for dir in "${cloudflared_dirs[@]}"; do
        if [ -d "$dir" ]; then
            potential_file=$(find "$dir" -name "*.json" -type f | grep -i "${tunnel_id}" | head -n 1)
            if [ -n "$potential_file" ] && [ -f "$potential_file" ]; then
                credential_file="$potential_file"
                break
            fi
        fi
    done
    
    # Jeśli nie znaleziono pliku, przeszukaj katalogi jeszcze raz dla wszystkich plików JSON
    if [ -z "$credential_file" ]; then
        for dir in "${cloudflared_dirs[@]}"; do
            if [ -d "$dir" ]; then
                info "Sprawdzanie plików JSON w katalogu $dir:"
                ls -la "$dir"/*.json 2>/dev/null || echo "Brak plików JSON w $dir"
                
                # Wybierz pierwszy plik JSON, jeśli jakikolwiek istnieje
                potential_file=$(find "$dir" -name "*.json" -type f | head -n 1)
                if [ -n "$potential_file" ] && [ -f "$potential_file" ]; then
                    credential_file="$potential_file"
                    warning "Nie znaleziono pliku specyficznego dla tunelu, używam: $credential_file"
                    break
                fi
            fi
        done
    fi
    
    echo "$credential_file"
}

# Funkcja do konfiguracji Cloudflare Tunnel
configure_cloudflare_tunnel() {
    info "Konfiguracja Cloudflare Tunnel..."
    
    warning "Musisz posiadać domenę dodaną do Cloudflare. Jeśli jeszcze tego nie zrobiłeś, przerwij instalację i wykonaj ten krok ręcznie."
    if ! confirm; then
        exit 1
    fi
    
    # Przygotowanie katalogów
    sudo mkdir -p /etc/cloudflared
    
    # Logowanie do Cloudflare
    info "Zostaniesz przekierowany do autoryzacji Cloudflare w przeglądarce."
    cloudflared tunnel login
    
    # Kopiujemy cert.pem do /etc/cloudflared/
    if [ -f ~/.cloudflared/cert.pem ]; then
        sudo cp ~/.cloudflared/cert.pem /etc/cloudflared/
        sudo chmod 600 /etc/cloudflared/cert.pem
    else
        error "Plik cert.pem nie został znaleziony. Upewnij się, że logowanie do Cloudflare przebiegło pomyślnie."
        exit 1
    fi
    
    # Tworzenie tunelu
    read -p "Podaj nazwę dla tunelu Cloudflare [n8n-tunnel]: " tunnel_name
    tunnel_name=${tunnel_name:-n8n-tunnel}
    
    # Sprawdzenie czy tunel o tej nazwie już istnieje
    info "Sprawdzanie, czy tunel o nazwie ${tunnel_name} już istnieje..."
    if cloudflared tunnel list | grep -q "${tunnel_name}"; then
        warning "Tunel ${tunnel_name} już istnieje."
        # Pobieramy ID tunelu - tylko pierwszy dopasowany wynik
        tunnel_id=$(cloudflared tunnel list | grep "${tunnel_name}" | head -n 1 | awk '{print $1}')
        # Upewniamy się, że ID jest poprawne i występuje tylko raz
        tunnel_id=$(echo "$tunnel_id" | tr -d '\n' | grep -o '[a-f0-9]\{8\}-[a-f0-9]\{4\}-[a-f0-9]\{4\}-[a-f0-9]\{4\}-[a-f0-9]\{12\}')
        info "Użyję istniejącego tunelu o ID: ${tunnel_id}"
    else
        info "Tworzenie nowego tunelu: ${tunnel_name}"
        # Zapisujemy pełny output komendy do pliku tymczasowego
        cloudflared tunnel create ${tunnel_name} > /tmp/tunnel_create_output.txt
        
        # Próbujemy wyodrębnić ID tunelu używając dokładnego wzorca dla UUID
        tunnel_id=$(cat /tmp/tunnel_create_output.txt | grep -o '[a-f0-9]\{8\}-[a-f0-9]\{4\}-[a-f0-9]\{4\}-[a-f0-9]\{4\}-[a-f0-9]\{12\}' | head -n 1)
        
        # Jeśli nie znaleziono ID tunelu, wyświetlamy pełny output
        if [ -z "$tunnel_id" ]; then
            error "Nie udało się wyodrębnić ID tunelu."
            echo "Pełny output komendy:"
            cat /tmp/tunnel_create_output.txt
            
            # Pytamy użytkownika o ręczne podanie ID tunelu
            read -p "Podaj ID tunelu wyświetlone powyżej: " manual_tunnel_id
            
            if [[ "$manual_tunnel_id" =~ ^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$ ]]; then
                tunnel_id="$manual_tunnel_id"
            else
                error "Podane ID tunelu ma nieprawidłowy format. Przerwanie instalacji."
                exit 1
            fi
        fi
        
        success "Tunel utworzony. ID: ${tunnel_id}"
        # Wyświetlamy ID jeszcze raz dla pewności, że jest poprawne
        info "Sprawdzone ID tunelu: ${tunnel_id}"
        # Usuwamy plik tymczasowy
        rm -f /tmp/tunnel_create_output.txt
    fi
    
    # Szukamy pliku z poświadczeniami
    credential_file=$(find_credential_file "$tunnel_id")
    
    # Jeśli nadal nie znaleziono pliku, poproś użytkownika o ręczne wskazanie
    if [ -z "$credential_file" ] || [ ! -f "$credential_file" ]; then
        error "Nie znaleziono pliku z poświadczeniami tunelu."
        read -p "Podaj pełną ścieżkę do pliku JSON z poświadczeniami: " manual_cred_file
        
        if [ -f "$manual_cred_file" ]; then
            credential_file="$manual_cred_file"
        else
            error "Plik $manual_cred_file nie istnieje. Przerwanie instalacji."
            exit 1
        fi
    fi
    
    # Czyszczenie ID tunelu z potencjalnych znaków nowej linii
    # Dodatkowo upewniamy się, że ID tunelu pojawia się tylko raz (bez duplikatów)
    tunnel_id=$(echo "$tunnel_id" | tr -d '\n' | grep -o '[a-f0-9]\{8\}-[a-f0-9]\{4\}-[a-f0-9]\{4\}-[a-f0-9]\{4\}-[a-f0-9]\{12\}')
    domain_name=$(echo "$domain_name" | tr -d '\n')
    clean_filename="${tunnel_id}.json"
    
    # Dodatkowa weryfikacja ID tunelu
    info "Sprawdzanie poprawności ID tunelu: ${tunnel_id}"
    if [[ ! "$tunnel_id" =~ ^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$ ]]; then
        error "ID tunelu ma nieprawidłowy format. Wprowadź poprawne ID ręcznie."
        read -p "Poprawne ID tunelu (format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx): " tunnel_id
        # Ponowne czyszczenie wprowadzonego ID
        tunnel_id=$(echo "$tunnel_id" | tr -d '\n' | grep -o '[a-f0-9]\{8\}-[a-f0-9]\{4\}-[a-f0-9]\{4\}-[a-f0-9]\{4\}-[a-f0-9]\{12\}')
        if [[ ! "$tunnel_id" =~ ^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$ ]]; then
            error "Nadal nieprawidłowy format ID. Przerwanie instalacji."
            exit 1
        fi
        clean_filename="${tunnel_id}.json"
    fi
    
    # Kopiujemy plik do /etc/cloudflared/ i ustawiamy odpowiednie uprawnienia
    info "Kopiowanie pliku poświadczeń $credential_file do /etc/cloudflared/$clean_filename"
    
    # Usuń stary plik jeśli istnieje, aby uniknąć problemów z kopiowaniem
    sudo rm -f "/etc/cloudflared/$clean_filename"
    
    # Kopiowanie pliku
    sudo cp -f "$credential_file" "/etc/cloudflared/$clean_filename"
    sudo chmod 600 "/etc/cloudflared/$clean_filename"
    
    # Sprawdź, czy plik został poprawnie skopiowany
    if [ ! -f "/etc/cloudflared/$clean_filename" ]; then
        error "Nie udało się utworzyć pliku poświadczeń. Przerwanie instalacji."
        exit 1
    fi
    
    # Tworzenie pliku konfiguracyjnego z zachowaniem prawidłowego formatowania YAML
    info "Tworzenie pliku konfiguracyjnego z poprawnym formatowaniem YAML..."
    
    # Usuwamy stary plik konfiguracyjny, jeśli istnieje
    sudo rm -f /etc/cloudflared/config.yml
    
    # Wyświetlanie wartości przed utworzeniem pliku (dla weryfikacji)
    info "ID tunelu: ${tunnel_id}"
    info "Nazwa pliku poświadczeń: ${clean_filename}"
    info "Domena: ${domain_name}"
    
    # Tworzenie nowego pliku z użyciem pojedynczych komend echo
    echo "tunnel: ${tunnel_id}" | sudo tee /etc/cloudflared/config.yml > /dev/null
    echo "credentials-file: /etc/cloudflared/${clean_filename}" | sudo tee -a /etc/cloudflared/config.yml > /dev/null
    echo "ingress:" | sudo tee -a /etc/cloudflared/config.yml > /dev/null
    echo "  - hostname: ${domain_name}" | sudo tee -a /etc/cloudflared/config.yml > /dev/null
    echo "    service: http://localhost:8443" | sudo tee -a /etc/cloudflared/config.yml > /dev/null
    echo "  - service: http_status:404" | sudo tee -a /etc/cloudflared/config.yml > /dev/null
    
    # Sprawdzenie zawartości pliku konfiguracyjnego
    info "Zawartość utworzonego pliku konfiguracyjnego:"
    cat /etc/cloudflared/config.yml
    
    # Ustaw odpowiednie uprawnienia
    sudo chmod 644 /etc/cloudflared/config.yml
    
    # Weryfikacja poprawności pliku YAML
    info "Weryfikuję poprawność pliku konfiguracyjnego..."
    
    # Próba użycia komendy cloudflared do sprawdzenia poprawności pliku
    if cloudflared tunnel ingress validate --config /etc/cloudflared/config.yml 2>&1 | grep -q "error parsing"; then
        error "Weryfikacja pliku konfiguracyjnego nie powiodła się."
        warning "Wygląda na to, że istnieje problem z formatowaniem YAML."
        
        # Wyświetl aktualną zawartość pliku
        info "Aktualna zawartość pliku config.yml:"
        cat /etc/cloudflared/config.yml
        
        read -p "Czy chcesz użyć edytora nano do ręcznej edycji pliku teraz? (t/n): " edit_confirm
        if [[ "$edit_confirm" =~ ^[tT] ]]; then
            sudo nano /etc/cloudflared/config.yml
            info "Plik został edytowany. Sprawdźmy czy jest poprawny..."
            if cloudflared tunnel ingress validate --config /etc/cloudflared/config.yml 2>&1 | grep -q "error parsing"; then
                error "Nadal istnieją problemy z plikiem konfiguracyjnym."
                warning "Będziesz musiał poprawić go ręcznie później."
            else
                success "Plik konfiguracyjny został naprawiony ręcznie i jest teraz poprawny."
            fi
        else
            warning "Kontynuuję instalację, ale tunel może nie działać poprawnie do czasu naprawy pliku konfiguracyjnego."
        fi
    else
        success "Plik konfiguracyjny jest poprawny."
    fi
    
    # Utworzenie rekordu DNS
    cloudflared tunnel route dns ${tunnel_name} ${domain_name}
    
    success "Konfiguracja Cloudflare Tunnel zakończona w /etc/cloudflared/config.yml."
}

# Funkcja do ręcznego uruchomienia tunelu Cloudflare
run_cloudflare_tunnel_manually() {
    info "Uruchamianie tunelu Cloudflare ręcznie..."
    
    # Sprawdź czy plik konfiguracyjny istnieje
    if [ ! -f /etc/cloudflared/config.yml ]; then
        error "Nie znaleziono pliku konfiguracyjnego. Najpierw skonfiguruj tunel."
        return 1
    fi
    
    # Uruchom tunel w tle
    nohup cloudflared tunnel --config /etc/cloudflared/config.yml run > ~/cloudflared.log 2>&1 &
    
    # Zapisz PID procesu
    echo $! > ~/cloudflared.pid
    
    success "Tunel Cloudflare uruchomiony ręcznie. Logi: ~/cloudflared.log"
    info "Aby zatrzymać tunel, użyj: kill \$(cat ~/cloudflared.pid)"
}

# Funkcja do konfiguracji Cloudflared jako usługi
setup_cloudflared_service() {
    info "Konfiguracja Cloudflared jako usługi..."
    
    # Sprawdzenie czy plik konfiguracyjny istnieje
    if [ ! -f /etc/cloudflared/config.yml ]; then
        error "Nie znaleziono pliku konfiguracyjnego /etc/cloudflared/config.yml. Najpierw skonfiguruj tunel."
        exit 1
    fi
    
    # Znajdujemy ID tunelu na podstawie pliku konfiguracyjnego
    tunnel_id=$(grep -oP '(?<=tunnel: )([a-f0-9-]+)' /etc/cloudflared/config.yml)
    tunnel_id=$(echo "$tunnel_id" | tr -d '\n')
    
    # Weryfikacja, czy plik poświadczeń istnieje
    credentials_file=$(grep -oP '(?<=credentials-file: )(.+)' /etc/cloudflared/config.yml)
    
    if [ ! -f "$credentials_file" ]; then
        error "Plik poświadczeń nie istnieje: $credentials_file"
        
        # Próba naprawy przez znalezienie odpowiedniego pliku
        info "Próbuję znaleźć plik poświadczeń..."
        found_file=$(find_credential_file "$tunnel_id")
        
        if [ -n "$found_file" ] && [ -f "$found_file" ]; then
            clean_filename="${tunnel_id}.json"
            info "Znaleziono plik poświadczeń: $found_file"
            sudo cp -f "$found_file" "/etc/cloudflared/$clean_filename"
            sudo chmod 600 "/etc/cloudflared/$clean_filename"
            sudo sed -i "s|credentials-file: .*|credentials-file: /etc/cloudflared/$clean_filename|" /etc/cloudflared/config.yml
            success "Zaktualizowano plik konfiguracyjny."
        else
            # Poproś o ręczne wskazanie pliku
            read -p "Podaj pełną ścieżkę do pliku JSON z poświadczeniami: " manual_cred_file
            
            if [ -f "$manual_cred_file" ]; then
                clean_filename="${tunnel_id}.json"
                sudo cp -f "$manual_cred_file" "/etc/cloudflared/$clean_filename"
                sudo chmod 600 "/etc/cloudflared/$clean_filename"
                sudo sed -i "s|credentials-file: .*|credentials-file: /etc/cloudflared/$clean_filename|" /etc/cloudflared/config.yml
                success "Zaktualizowano plik konfiguracyjny."
            else
                error "Nie udało się znaleźć pliku poświadczeń. Przerwanie instalacji."
                exit 1
            fi
        fi
    fi
    
    # Tworzenie pliku usługi systemd
    sudo mkdir -p /etc/systemd/system
    cat > /tmp/cloudflared.service << EOF
[Unit]
Description=cloudflared
After=network.target

[Service]
TimeoutStartSec=0
Type=simple
User=root
ExecStart=/usr/local/bin/cloudflared --config /etc/cloudflared/config.yml tunnel run
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
    
    sudo cp /tmp/cloudflared.service /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable cloudflared
    sudo systemctl start cloudflared
    
    # Sprawdzenie statusu z opóźnieniem
    sleep 2
    if sudo systemctl is-active cloudflared > /dev/null 2>&1; then
        success "Cloudflared uruchomiony."
    else
        error "Cloudflared nie uruchomił się. Sprawdź logi: sudo journalctl -u cloudflared"
        warning "Możesz spróbować uruchomić go ręcznie: sudo cloudflared tunnel --config /etc/cloudflared/config.yml run"
        warning "Kontynuowanie instalacji, ale musisz rozwiązać ten problem później."
        
        # Oferujemy możliwość ręcznego uruchomienia
        info "Czy chcesz uruchomić tunel ręcznie (nie jako usługa systemd)?"
        if confirm; then
            run_cloudflare_tunnel_manually
        fi
    fi
}

# Funkcja do konfiguracji automatycznych kopii zapasowych
configure_backups() {
    info "Konfiguracja automatycznych kopii zapasowych..."
    
    # Tworzenie skryptu backupu
    cat > ~/backup-n8n.sh << EOF
#!/bin/bash
BACKUP_DIR="/root/backups"
DATE=\$(date +%Y-%m-%d)
BACKUP_LOG="\$BACKUP_DIR/backup_history.log"

# Tworzenie katalogu na backupy jeśli nie istnieje
mkdir -p \$BACKUP_DIR

echo "Rozpoczęcie tworzenia kopii zapasowej \$(date)" >> \$BACKUP_LOG

# Backup bazy danych PostgreSQL
cd ~/n8n
docker-compose exec -T postgres pg_dump -U ${db_user} n8n > \$BACKUP_DIR/n8n_postgres_backup_\$DATE.sql
if [ \$? -eq 0 ]; then
    echo "✓ Backup bazy danych PostgreSQL zakończony pomyślnie" >> \$BACKUP_LOG
else
    echo "✗ Błąd tworzenia kopii bazy danych PostgreSQL" >> \$BACKUP_LOG
fi

# Backup danych konfiguracyjnych n8n
tar -czvf \$BACKUP_DIR/n8n_data_backup_\$DATE.tar.gz ~/.n8n
if [ \$? -eq 0 ]; then
    echo "✓ Backup danych konfiguracyjnych zakończony pomyślnie" >> \$BACKUP_LOG
else
    echo "✗ Błąd tworzenia kopii danych konfiguracyjnych" >> \$BACKUP_LOG
fi

# Backup konfiguracji Cloudflare
sudo tar -czvf \$BACKUP_DIR/cloudflared_backup_\$DATE.tar.gz /etc/cloudflared
if [ \$? -eq 0 ]; then
    echo "✓ Backup konfiguracji Cloudflare zakończony pomyślnie" >> \$BACKUP_LOG
else
    echo "✗ Błąd tworzenia kopii konfiguracji Cloudflare" >> \$BACKUP_LOG
fi

# Tworzenie pojedynczego archiwum zawierającego wszystkie kopie z danego dnia
tar -czvf \$BACKUP_DIR/n8n_full_backup_\$DATE.tar.gz \$BACKUP_DIR/n8n_postgres_backup_\$DATE.sql \$BACKUP_DIR/n8n_data_backup_\$DATE.tar.gz \$BACKUP_DIR/cloudflared_backup_\$DATE.tar.gz
if [ \$? -eq 0 ]; then
    echo "✓ Pełna kopia zapasowa utworzona pomyślnie" >> \$BACKUP_LOG
else
    echo "✗ Błąd tworzenia pełnej kopii zapasowej" >> \$BACKUP_LOG
fi

# Usuwanie backupów starszych niż 30 dni
echo "Usuwanie starych kopii zapasowych..." >> \$BACKUP_LOG
find \$BACKUP_DIR -name "n8n_postgres_backup_*.sql" -type f -mtime +30 -delete
find \$BACKUP_DIR -name "n8n_data_backup_*.tar.gz" -type f -mtime +30 -delete
find \$BACKUP_DIR -name "cloudflared_backup_*.tar.gz" -type f -mtime +30 -delete
find \$BACKUP_DIR -name "n8n_full_backup_*.tar.gz" -type f -mtime +30 -delete

# Informacja o zakończeniu backupu
echo "Kopia zapasowa zakończona \$(date)" >> \$BACKUP_LOG
echo "--------------------------------------" >> \$BACKUP_LOG
EOF
    
    chmod +x ~/backup-n8n.sh
    
    # Tworzenie skryptu do przywracania
    cat > ~/restore-n8n.sh << EOF
#!/bin/bash

# Skrypt do przywracania n8n z backupu
# Użycie: ./restore-n8n.sh YYYY-MM-DD

if [ -z "\$1" ]; then
  echo "Podaj datę backupu w formacie YYYY-MM-DD"
  exit 1
fi

BACKUP_DIR="/root/backups"
DATE=\$1

# Sprawdzenie czy backup istnieje
if [ ! -f "\$BACKUP_DIR/n8n_postgres_backup_\$DATE.sql" ] || [ ! -f "\$BACKUP_DIR/n8n_data_backup_\$DATE.tar.gz" ]; then
  echo "Backup z daty \$DATE nie istnieje!"
  exit 1
fi

# Zatrzymanie usług
cd ~/n8n
docker-compose down
sudo systemctl stop cloudflared

# Przywracanie konfiguracji Cloudflare
if [ -f "\$BACKUP_DIR/cloudflared_backup_\$DATE.tar.gz" ]; then
  sudo tar -xzvf "\$BACKUP_DIR/cloudflared_backup_\$DATE.tar.gz" -C /
  echo "Konfiguracja Cloudflare przywrócona."
fi

# Przywracanie bazy danych
docker-compose up -d postgres
sleep 5
cat "\$BACKUP_DIR/n8n_postgres_backup_\$DATE.sql" | docker-compose exec -T postgres psql -U ${db_user} n8n
docker-compose down

# Przywracanie plików konfiguracyjnych n8n
rm -rf ~/.n8n.bak
mv ~/.n8n ~/.n8n.bak  # Backup aktualnej konfiguracji
tar -xzvf "\$BACKUP_DIR/n8n_data_backup_\$DATE.tar.gz" -C /

# Uruchomienie usług
sudo systemctl start cloudflared
docker-compose up -d

echo "Przywracanie z backupu \$DATE zakończone"
EOF
    
    chmod +x ~/restore-n8n.sh
    
    # Dodanie zadania do crona
    (crontab -l 2>/dev/null | grep -v "backup-n8n.sh"; echo "0 3 * * * /root/backup-n8n.sh > /root/backup.log 2>&1") | crontab -
    
    success "Konfiguracja automatycznych kopii zapasowych zakończona."
}

# Funkcja do uruchomienia usług
start_services() {
    info "Uruchamianie usług..."
    
    # Najpierw konfiguracja Cloudflared
    setup_cloudflared_service
    
    # Sprawdzenie czy Docker daemon jest uruchomiony
    if ! docker info &>/dev/null; then
        error "Docker nie jest uruchomiony lub brakuje uprawnień. Próba naprawy..."
        
        # Próba naprawy problemu z Docker
        info "Sprawdzanie uprawnień katalogu Docker..."
        sudo mkdir -p /var/lib/docker/network/files
        sudo chown -R root:root /var/lib/docker
        
        info "Restart usługi Docker..."
        sudo systemctl restart docker
        sleep 5
        
        # Sprawdzenie, czy Docker działa po restarcie
        if ! docker info &>/dev/null; then
            error "Docker nadal nie działa poprawnie."
            warning "Prawdopodobnie potrzebny jest restart systemu."
            read -p "Czy chcesz zrestartować system teraz? (t/n): " restart_now
            if [[ "$restart_now" =~ ^[tT] ]]; then
                # Zapisanie flagi, aby skrypt wiedział, że powinien kontynuować po restarcie
                touch ~/.n8n_install_progress
                info "Restartuję system. Uruchom skrypt ponownie po restarcie."
                sudo reboot
                exit 0
            else
                error "Nie można kontynuować bez działającego Dockera. Przerwanie instalacji."
                exit 1
            fi
        else
            success "Docker naprawiony po restarcie usługi."
        fi
    fi
    
    # Uruchomienie n8n
    cd ~/n8n
    info "Uruchamianie kontenerów n8n..."
    docker-compose down
    docker-compose up -d
    
    # Sprawdzenie statusu
    if docker-compose ps | grep -q "n8n"; then
        success "n8n uruchomione."
    else
        error "n8n nie uruchomiło się. Sprawdź logi: docker-compose logs"
        warning "Wyświetlanie logów..."
        docker-compose logs
        
        # Próba naprawy problemów z siecią Docker
        warning "Próbuję naprawić problemy z siecią Docker..."
        docker network prune -f
        info "Usunięto nieużywane sieci Docker. Próbuję ponownie uruchomić n8n..."
        
        # Ponowna próba uruchomienia
        docker-compose up -d
        
        sleep 5
        if docker-compose ps | grep -q "n8n"; then
            success "n8n uruchomione po naprawie sieci."
        else
            error "Nadal nie można uruchomić n8n."
            warning "Kontynuuję instalację, mimo że wystąpiły problemy z uruchomieniem n8n."
        fi
    fi
}

# Funkcja do wyświetlania informacji końcowych
show_final_info() {
    domain_name=$(grep -oP '(?<=hostname: )(.+)' /etc/cloudflared/config.yml)
    
    echo -e "\n${GREEN}==================================================${NC}"
    echo -e "${GREEN}Instalacja n8n zakończona pomyślnie!${NC}"
    echo -e "${GREEN}==================================================${NC}"
    echo -e "${BLUE}Poradnik z serwisu:${NC} www.przewodnikai.pl"
    echo -e "${BLUE}Kanał YouTube:${NC} https://www.youtube.com/@lukaszpodgorski"
    
    echo -e "\nTwój serwer n8n jest dostępny pod adresem:"
    echo -e "${BLUE}https://${domain_name}${NC}"
    echo -e "\nPrzy pierwszym uruchomieniu utwórz konto administratora."
    echo -e "\nDodatkowe informacje:"
    echo -e "- Pliki konfiguracyjne n8n: ~/n8n/docker-compose.yml"
    echo -e "- Konfiguracja Cloudflare: /etc/cloudflared/config.yml"
    echo -e "- Skrypt kopii zapasowej: ~/backup-n8n.sh (uruchamiany codziennie o 3:00)"
    echo -e "- Skrypt przywracania: ~/restore-n8n.sh (użycie: ./restore-n8n.sh YYYY-MM-DD)"
    
    echo -e "\n${YELLOW}WAŻNE: Wykonaj restart systemu, aby upewnić się, że wszystkie usługi zostaną uruchomione poprawnie.${NC}"
    echo -e "${YELLOW}Możesz to zrobić komendą: sudo reboot${NC}"
    
    echo -e "\n${BLUE}Dziękujemy za skorzystanie z poradnika!${NC}"
    echo -e "${BLUE}Więcej materiałów na:${NC} www.przewodnikai.pl"
    echo -e "${BLUE}oraz na YouTube:${NC} https://www.youtube.com/@lukaszpodgorski"
    echo -e "\n${GREEN}==================================================${NC}"
}

# Główna funkcja skryptu
main() {
    check_raspberry_pi
    check_privileges
    
    echo -e "\n${GREEN}==================================================${NC}"
    echo -e "${GREEN}Automatyczny skrypt instalacji n8n na Raspberry Pi${NC}"
    echo -e "${GREEN}==================================================${NC}"
    echo -e "${BLUE}Autor:${NC} Łukasz Podgórski & Anthropic Claude"
    echo -e "${BLUE}Wersja:${NC} 2.6 (simplified permissions)"
    echo -e "${BLUE}Poradnik z serwisu:${NC} www.przewodnikai.pl"
    echo -e "${BLUE}Kanał YouTube:${NC} https://www.youtube.com/@lukaszpodgorski"
    echo -e "\n${YELLOW}Ten skrypt zainstaluje n8n oraz skonfiguruje dostęp przez Cloudflare Tunnel.${NC}"
    
    if ! confirm; then
        exit 0
    fi
    
    # Sprawdzenie, czy to jest kontynuacja po restarcie systemu po instalacji Dockera
    if [ -f ~/.docker_fresh_install ]; then
        info "Wykryto kontynuację po restarcie systemu po instalacji Dockera."
        
        # Sprawdzenie, czy Docker działa poprawnie
        if ! docker info &>/dev/null; then
            error "Docker nie działa poprawnie nawet po restarcie. Sprawdź instalację Dockera ręcznie."
            exit 1
        fi
        
        # Usunięcie flagi świeżej instalacji Dockera
        rm -f ~/.docker_fresh_install
        
        success "Docker działa poprawnie. Kontynuuję instalację..."
        
        # Przejście do instalacji Docker Compose (może być konieczne po restarcie)
        install_docker_compose
        configure_n8n
        install_cloudflared
        configure_cloudflare_tunnel
        start_services
        configure_backups
        show_final_info
    elif [ -f ~/.n8n_install_progress ]; then
        # Jeśli istnieje flaga postępu instalacji n8n (po restarcie z powodu problemów z Dockerem)
        info "Wykryto kontynuację instalacji po restarcie systemu (problemy z uruchomieniem n8n)."
        
        # Usunięcie flagi postępu
        rm -f ~/.n8n_install_progress
        
        # Sprawdzenie, czy Docker działa poprawnie
        if ! docker info &>/dev/null; then
            error "Docker nadal nie działa poprawnie. Proszę sprawdzić instalację Dockera ręcznie."
            exit 1
        fi
        
        success "Docker działa poprawnie. Kontynuuję instalację n8n..."
        
        # Próba uruchomienia n8n i dokończenia instalacji
        cd ~/n8n
        docker network prune -f
        docker-compose down
        docker-compose up -d
        
        # Sprawdzenie statusu
        if docker-compose ps | grep -q "n8n" && docker-compose ps | grep -q "Up"; then
            success "n8n uruchomione pomyślnie po restarcie systemu."
            configure_backups
            show_final_info
        else
            error "Nadal problemy z uruchomieniem n8n."
            configure_backups
            show_final_info
        fi
    else
        # Standardowy przepływ instalacji
        update_system
        install_docker
        install_docker_compose
        configure_n8n
        install_cloudflared
        configure_cloudflare_tunnel
        start_services
        configure_backups
        show_final_info
    fi
}

# Uruchomienie skryptu
main
