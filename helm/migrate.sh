#!/bin/bash

# GLPI SSO Migration Script
# Este script ayuda a migrar desde Docker Compose a Helm

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para imprimir mensajes
print_message() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar que Docker Compose esté ejecutándose
check_docker_compose() {
    print_message "Verificando que Docker Compose esté ejecutándose..."
    
    if ! docker-compose ps | grep -q "Up"; then
        print_error "Docker Compose no está ejecutándose. Por favor inicia los servicios primero:"
        echo "  docker-compose up -d"
        exit 1
    fi
    
    print_success "Docker Compose está ejecutándose"
}

# Crear directorio de backup
create_backup_dir() {
    BACKUP_DIR="backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    print_message "Directorio de backup creado: $BACKUP_DIR"
}

# Backup de GLPI
backup_glpi() {
    print_message "Creando backup de GLPI..."
    
    # Obtener el nombre del contenedor GLPI
    GLPI_CONTAINER=$(docker-compose ps -q glpi)
    
    if [ -z "$GLPI_CONTAINER" ]; then
        print_error "No se encontró el contenedor GLPI"
        exit 1
    fi
    
    # Crear backup
    docker exec "$GLPI_CONTAINER" tar czf /tmp/glpi-backup.tar.gz -C /var/www/html/glpi .
    docker cp "$GLPI_CONTAINER:/tmp/glpi-backup.tar.gz" "$BACKUP_DIR/"
    
    print_success "Backup de GLPI creado: $BACKUP_DIR/glpi-backup.tar.gz"
}

# Backup de Keycloak
backup_keycloak() {
    print_message "Creando backup de Keycloak..."
    
    # Obtener el nombre del contenedor Keycloak
    KEYCLOAK_CONTAINER=$(docker-compose ps -q keycloak)
    
    if [ -z "$KEYCLOAK_CONTAINER" ]; then
        print_error "No se encontró el contenedor Keycloak"
        exit 1
    fi
    
    # Crear backup del realm
    docker exec "$KEYCLOAK_CONTAINER" /opt/keycloak/bin/kc.sh export --dir=/tmp/export --users=realm_file
    docker cp "$KEYCLOAK_CONTAINER:/tmp/export" "$BACKUP_DIR/keycloak-export"
    
    print_success "Backup de Keycloak creado: $BACKUP_DIR/keycloak-export"
}

# Backup de MySQL
backup_mysql() {
    print_message "Creando backup de MySQL..."
    
    # Obtener el nombre del contenedor MySQL
    MYSQL_CONTAINER=$(docker-compose ps -q mysql)
    
    if [ -z "$MYSQL_CONTAINER" ]; then
        print_error "No se encontró el contenedor MySQL"
        exit 1
    fi
    
    # Crear backup de la base de datos
    docker exec "$MYSQL_CONTAINER" mysqldump -u root -p"${MYSQL_ROOT_PASSWORD:-root_password}" glpi > "$BACKUP_DIR/glpi-database.sql"
    
    print_success "Backup de MySQL creado: $BACKUP_DIR/glpi-database.sql"
}

# Verificar prerrequisitos de Kubernetes
check_kubernetes_prerequisites() {
    print_message "Verificando prerrequisitos de Kubernetes..."
    
    # Verificar Helm
    if ! command -v helm &> /dev/null; then
        print_error "Helm no está instalado. Por favor instala Helm 3.0+"
        exit 1
    fi
    
    # Verificar kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl no está instalado. Por favor instala kubectl"
        exit 1
    fi
    
    # Verificar conexión a Kubernetes
    if ! kubectl cluster-info &> /dev/null; then
        print_error "No se puede conectar al cluster de Kubernetes"
        exit 1
    fi
    
    print_success "Prerrequisitos de Kubernetes verificados"
}

# Instalar Helm chart
install_helm_chart() {
    print_message "Instalando Helm chart..."
    
    # Agregar repositorios
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm repo add oauth2-proxy https://oauth2-proxy.github.io/manifests
    helm repo update
    
    # Instalar dependencias
    cd helm
    helm dependency update
    cd ..
    
    # Instalar chart
    helm install glpi-sso ./helm -f ./helm/values-development.yaml
    
    print_success "Helm chart instalado"
}

# Restaurar datos
restore_data() {
    print_message "Esperando a que los pods estén listos..."
    
    # Esperar a que los pods estén listos
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=glpi-sso --timeout=300s
    
    print_message "Restaurando datos..."
    
    # Restaurar GLPI
    if [ -f "$BACKUP_DIR/glpi-backup.tar.gz" ]; then
        print_message "Restaurando GLPI..."
        kubectl cp "$BACKUP_DIR/glpi-backup.tar.gz" glpi-sso-glpi-0:/tmp/
        kubectl exec glpi-sso-glpi-0 -- tar xzf /tmp/glpi-backup.tar.gz -C /var/www/html/glpi
        print_success "GLPI restaurado"
    fi
    
    # Restaurar MySQL
    if [ -f "$BACKUP_DIR/glpi-database.sql" ]; then
        print_message "Restaurando base de datos MySQL..."
        kubectl cp "$BACKUP_DIR/glpi-database.sql" glpi-sso-mysql-0:/tmp/
        kubectl exec glpi-sso-mysql-0 -- mysql -u root -p"root_password" glpi < /tmp/glpi-database.sql
        print_success "Base de datos MySQL restaurada"
    fi
    
    # Restaurar Keycloak (opcional)
    if [ -d "$BACKUP_DIR/keycloak-export" ]; then
        print_message "Restaurando configuración de Keycloak..."
        kubectl cp "$BACKUP_DIR/keycloak-export" glpi-sso-keycloak-0:/opt/keycloak/data/import/
        print_success "Configuración de Keycloak restaurada"
    fi
}

# Mostrar información post-migración
show_post_migration_info() {
    echo
    print_success "¡Migración completada!"
    echo
    print_message "Información de acceso:"
    echo
    
    # Obtener información del ingress
    if kubectl get ingress -l app.kubernetes.io/instance=glpi-sso &> /dev/null; then
        echo "Ingress configurados:"
        kubectl get ingress -l app.kubernetes.io/instance=glpi-sso
        echo
    fi
    
    # Obtener estado de pods
    echo "Estado de pods:"
    kubectl get pods -l app.kubernetes.io/instance=glpi-sso
    echo
    
    print_message "Próximos pasos:"
    echo "1. Verifica que todos los pods estén en estado 'Running'"
    echo "2. Accede a GLPI: http://glpi.localhost"
    echo "3. Accede a Keycloak: http://keycloak.localhost"
    echo "4. Configura usuarios en Keycloak si es necesario"
    echo "5. Una vez que todo funcione, puedes detener Docker Compose:"
    echo "   docker-compose down"
    echo
    
    print_message "Backups guardados en: $BACKUP_DIR"
    print_warning "Guarda estos backups en un lugar seguro"
}

# Función principal
main() {
    echo "=========================================="
    echo "  GLPI SSO Migration Script"
    echo "  Docker Compose → Kubernetes/Helm"
    echo "=========================================="
    echo
    
    check_docker_compose
    create_backup_dir
    backup_glpi
    backup_keycloak
    backup_mysql
    check_kubernetes_prerequisites
    install_helm_chart
    restore_data
    show_post_migration_info
}

# Ejecutar función principal
main "$@"
