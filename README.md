# ENGLISH (PONIŻEJ ZNAJDZIESZ WERSJĘ PO POLSKU)

# RaspberryPi-N8N-Cloudflare-Deployer



Automated installation script for [n8n](https://n8n.io/) on Raspberry Pi with Cloudflare Tunnel configuration for secure remote access. The solution includes installation of necessary dependencies, database configuration, automatic backups, and error handling.

## 📋 Table of Contents

- [About the Project](#about-the-project)
- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Configuration](#configuration)
- [Backups](#backups)
- [Troubleshooting](#troubleshooting)
- [Authors](#authors)
- [License](#license)

## 🚀 About the Project

RaspberryPi-N8N-Cloudflare-Deployer is a comprehensive solution for running your own instance of n8n - a powerful workflow automation and integration tool - on the Raspberry Pi platform. The project additionally provides secure internet exposure of the service through Cloudflare Tunnel, eliminating the need for port forwarding configuration or a static IP address.

## ✨ Features

- **Fully Automated Installation** - one-command deployment of n8n on Raspberry Pi
- **Secure Remote Access** - Cloudflare Tunnel configuration for secure internet access
- **Containerization** - utilizing Docker and Docker Compose
- **PostgreSQL Database** - persistent storage for data and configurations
- **Automatic Backups** - daily backups with 30-day rotation
- **Error Resilience** - advanced error handling and recovery mechanisms
- **Restore Support** - tools for restoring from backups
- **Colorful Interface** - intuitive, color-coded terminal interface

## 📋 Requirements

- Raspberry Pi (tested on Raspberry Pi 4 and newer)
- Raspberry Pi OS (formerly Raspbian)
- Internet access
- Domain added to Cloudflare (Cloudflare account)

## 🔧 Installation

### Quick Installation

```bash
wget -O install-n8n.sh https://raw.githubusercontent.com/user/RaspberryPi-N8N-Cloudflare-Deployer/main/rpi-n8n-cloudflare-installer.sh && chmod +x install-n8n.sh && ./install-n8n.sh
```

### Manual Installation

1. Download the installation script
```bash
wget -O install-n8n.sh https://raw.githubusercontent.com/user/RaspberryPi-N8N-Cloudflare-Deployer/main/rpi-n8n-cloudflare-installer.sh
```

2. Make it executable
```bash
chmod +x install-n8n.sh
```

3. Run the script
```bash
./install-n8n.sh
```

## ⚙️ Configuration

During installation, the script will ask for several pieces of information:

- **Domain for n8n** - the full domain name where your n8n instance will be accessible
- **PostgreSQL database password** - default: n8n_password
- **Cloudflare Tunnel name** - default: n8n-tunnel

Configuration files:
- **n8n**: `~/n8n/docker-compose.yml`
- **Cloudflare Tunnel**: `/etc/cloudflared/config.yml`

## 💾 Backups

### Automatic Backups

The script configures automatic backups that run daily at 3:00 AM. Backups are stored in the `/root/backups` directory and include:

- PostgreSQL database
- n8n configuration data
- Cloudflare Tunnel configuration

Backups older than 30 days are automatically deleted.

### Restoring from Backup

To restore the system from a backup, use the script:

```bash
./restore-n8n.sh YYYY-MM-DD
```

where `YYYY-MM-DD` is the date of the backup you want to restore.

## ❓ Troubleshooting

### Docker Startup Issues

If Docker doesn't start properly after installation, restart the system:

```bash
sudo reboot
```

After reboot, run the script again.

### Cloudflare Tunnel Issues

Check the Cloudflared service logs:

```bash
sudo journalctl -u cloudflared
```

You can also run the tunnel manually:

```bash
sudo cloudflared tunnel --config /etc/cloudflared/config.yml run
```

### n8n Container Issues

Check container logs:

```bash
cd ~/n8n
docker-compose logs
```

Try restarting the containers:

```bash
cd ~/n8n
docker-compose down
docker-compose up -d
```

## 👥 Authors

- **Łukasz Podgórski** - [YouTube](https://www.youtube.com/@lukaszpodgorski)
- **Anthropic Claude** - AI assistant

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

This project is part of a tutorial available at [przewodnikai.pl](https://www.przewodnikai.pl). More materials can be found on the [YouTube channel](https://www.youtube.com/@lukaszpodgorski).

If you like this project, please leave a star! ⭐️



# POLSKI

# RaspberryPi-N8N-Cloudflare-Deployer

![Banner RaspberryPi N8N Cloudflare](https://raw.githubusercontent.com/user/RaspberryPi-N8N-Cloudflare-Deployer/main/banner.png)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-2.6-blue)](https://github.com/user/RaspberryPi-N8N-Cloudflare-Deployer)
[![Support](https://img.shields.io/badge/Support-Raspberry%20Pi-red)](https://www.raspberrypi.org/)

Automatyczny skrypt instalacji [n8n](https://n8n.io/) na Raspberry Pi z konfiguracją tunelu Cloudflare dla bezpiecznego dostępu zdalnego. Rozwiązanie zawiera instalację niezbędnych zależności, konfigurację bazy danych, automatyczne kopie zapasowe oraz obsługę błędów.

## 📋 Spis treści

- [O projekcie](#o-projekcie)
- [Funkcje](#funkcje)
- [Wymagania](#wymagania)
- [Instalacja](#instalacja)
- [Konfiguracja](#konfiguracja)
- [Kopie zapasowe](#kopie-zapasowe)
- [Rozwiązywanie problemów](#rozwiązywanie-problemów)
- [Autorzy](#autorzy)
- [Licencja](#licencja)

## 🚀 O projekcie

RaspberryPi-N8N-Cloudflare-Deployer to kompleksowe rozwiązanie umożliwiające uruchomienie własnej instancji n8n - potężnego narzędzia do automatyzacji i integracji przepływów pracy - na platformie Raspberry Pi. Projekt dodatkowo zapewnia bezpieczne udostępnienie usługi przez internet za pomocą tunelu Cloudflare, eliminując potrzebę konfiguracji przekierowania portów czy posiadania stałego adresu IP.

## ✨ Funkcje

- **Pełna automatyzacja instalacji** - jednokomendowe wdrożenie n8n na Raspberry Pi
- **Bezpieczny dostęp zdalny** - konfiguracja tunelu Cloudflare dla bezpiecznego dostępu przez internet
- **Konteneryzacja** - wykorzystanie Docker i Docker Compose
- **Baza danych PostgreSQL** - trwałe przechowywanie danych i konfiguracji
- **Automatyczne kopie zapasowe** - codzienne kopie zapasowe z 30-dniową rotacją
- **Odporność na błędy** - zaawansowana obsługa błędów i mechanizmy naprawcze
- **Wsparcie dla przywracania** - narzędzia do przywracania z kopii zapasowych
- **Kolorowy interfejs** - intuicyjny, kolorowy interfejs w terminalu

## 📋 Wymagania

- Raspberry Pi (testowane na Raspberry Pi 4 i nowszych)
- System operacyjny Raspberry Pi OS (dawniej Raspbian)
- Dostęp do internetu
- Domena dodana do Cloudflare (konto Cloudflare)

## 🔧 Instalacja

### Szybka instalacja

```bash
wget -O install-n8n.sh https://raw.githubusercontent.com/user/RaspberryPi-N8N-Cloudflare-Deployer/main/rpi-n8n-cloudflare-installer.sh && chmod +x install-n8n.sh && ./install-n8n.sh
```

### Instalacja manualna

1. Pobierz skrypt instalacyjny
```bash
wget -O install-n8n.sh https://raw.githubusercontent.com/user/RaspberryPi-N8N-Cloudflare-Deployer/main/rpi-n8n-cloudflare-installer.sh
```

2. Nadaj uprawnienia wykonywania
```bash
chmod +x install-n8n.sh
```

3. Uruchom skrypt
```bash
./install-n8n.sh
```

## ⚙️ Konfiguracja

Podczas instalacji, skrypt poprosi o podanie kilku informacji:

- **Domena dla n8n** - pełna nazwa domeny, pod którą będzie dostępna Twoja instancja n8n
- **Hasło dla bazy danych PostgreSQL** - domyślnie: n8n_password
- **Nazwa tunelu Cloudflare** - domyślnie: n8n-tunnel

Pliki konfiguracyjne:
- **n8n**: `~/n8n/docker-compose.yml`
- **Cloudflare Tunnel**: `/etc/cloudflared/config.yml`

## 💾 Kopie zapasowe

### Automatyczne kopie zapasowe

Skrypt konfiguruje automatyczne kopie zapasowe, które są wykonywane codziennie o godzinie 3:00. Kopie przechowywane są w katalogu `/root/backups` i zawierają:

- Bazę danych PostgreSQL
- Dane konfiguracyjne n8n
- Konfigurację tunelu Cloudflare

Kopie starsze niż 30 dni są automatycznie usuwane.

### Przywracanie z kopii zapasowej

Aby przywrócić system z kopii zapasowej, użyj skryptu:

```bash
./restore-n8n.sh YYYY-MM-DD
```

gdzie `YYYY-MM-DD` to data kopii zapasowej, którą chcesz przywrócić.

## ❓ Rozwiązywanie problemów

### Problem z uruchomieniem Dockera

Jeśli Docker nie uruchamia się poprawnie po instalacji, zrestartuj system:

```bash
sudo reboot
```

Po restarcie uruchom skrypt ponownie.

### Problem z tunelem Cloudflare

Sprawdź logi serwisu Cloudflared:

```bash
sudo journalctl -u cloudflared
```

Możesz również uruchomić tunel ręcznie:

```bash
sudo cloudflared tunnel --config /etc/cloudflared/config.yml run
```

### Problem z kontenerami n8n

Sprawdź logi kontenerów:

```bash
cd ~/n8n
docker-compose logs
```

Spróbuj zrestartować kontenery:

```bash
cd ~/n8n
docker-compose down
docker-compose up -d
```

## 👥 Autorzy

- **Łukasz Podgórski** - [YouTube](https://www.youtube.com/@lukaszpodgorski)
- **Anthropic Claude** - asystent AI

## 📜 Licencja

Ten projekt jest udostępniany na licencji MIT. Zobacz plik [LICENSE](LICENSE) aby dowiedzieć się więcej.

---

Projekt jest częścią poradnika dostępnego na stronie [przewodnikai.pl](https://www.przewodnikai.pl). Więcej materiałów znajdziesz na [kanale YouTube](https://www.youtube.com/@lukaszpodgorski).

Jeśli podoba Ci się ten projekt, zostaw gwiazdkę! ⭐️
