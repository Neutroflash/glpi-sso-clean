#!/bin/bash

# GLPI SSO Helm Chart Installation Script
# Este script instala la stack completa de GLPI con SSO

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

# Verificar prerrequisitos
check_prerequisites() {
    print_message "Verificando prerrequisitos..."
    
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
    
    print_success "Prerrequisitos verificados"
}

# Agregar repositorios de Helm
add_helm_repos() {
    print_message "Agregando repositorios de Helm..."
    
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm repo add oauth2-proxy https://oauth2-proxy.github.io/manifests
    helm repo update
    
    print_success "Repositorios agregados"
}

# Instalar dependencias
install_dependencies() {
    print_message "Instalando dependencias..."
    
    cd helm
    helm dependency update
    cd ..
    
    print_success "Dependencias instaladas"
}

# Función para obtener configuración del usuario
get_configuration() {
    echo
    print_message "Configuración de instalación"
    echo "1. Desarrollo (localhost)"
    echo "2. Producción (dominio personalizado)"
    echo "3. Personalizado"
    echo
    read -p "Selecciona una opción (1-3): " config_choice
    
    case $config_choice in
        1)
            VALUES_FILE="values-development.yaml"
            print_message "Usando configuración de desarrollo"
            ;;
        2)
            VALUES_FILE="values-production.yaml"
            print_message "Usando configuración de producción"
            print_warning "Recuerda cambiar las contraseñas por defecto en el archivo values-production.yaml"
            ;;
        3)
            read -p "Ingresa la ruta al archivo de valores personalizado: " custom_values
            VALUES_FILE="$custom_values"
            print_message "Usando configuración personalizada: $VALUES_FILE"
            ;;
        *)
            print_error "Opción inválida"
            exit 1
            ;;
    esac
}

# Función para obtener nombre del release
get_release_name() {
    read -p "Ingresa el nombre del release (default: glpi-sso): " release_name
    RELEASE_NAME=${release_name:-glpi-sso}
    print_message "Usando release name: $RELEASE_NAME"
}

# Función para verificar si el release ya existe
check_existing_release() {
    if helm list | grep -q "^$RELEASE_NAME"; then
        print_warning "El release '$RELEASE_NAME' ya existe"
        read -p "¿Deseas actualizar el release existente? (y/N): " update_choice
        if [[ $update_choice =~ ^[Yy]$ ]]; then
            UPGRADE_MODE=true
        else
            print_message "Instalación cancelada"
            exit 0
        fi
    fi
}

# Instalar/actualizar el chart
install_chart() {
    print_message "Instalando chart de GLPI SSO..."
    
    if [ "$UPGRADE_MODE" = true ]; then
        helm upgrade $RELEASE_NAME ./helm -f ./helm/$VALUES_FILE
        print_success "Chart actualizado exitosamente"
    else
        helm install $RELEASE_NAME ./helm -f ./helm/$VALUES_FILE
        print_success "Chart instalado exitosamente"
    fi
}

# Mostrar información post-instalación
show_post_install_info() {
    echo
    print_success "¡Instalación completada!"
    echo
    print_message "Información de acceso:"
    echo
    
    # Obtener información del ingress
    if kubectl get ingress -l app.kubernetes.io/instance=$RELEASE_NAME &> /dev/null; then
        echo "Ingress configurados:"
        kubectl get ingress -l app.kubernetes.io/instance=$RELEASE_NAME
        echo
    fi
    
    # Obtener información de servicios
    echo "Servicios desplegados:"
    kubectl get svc -l app.kubernetes.io/instance=$RELEASE_NAME
    echo
    
    # Obtener estado de pods
    echo "Estado de pods:"
    kubectl get pods -l app.kubernetes.io/instance=$RELEASE_NAME
    echo
    
    print_message "Comandos útiles:"
    echo "  Ver logs de GLPI: kubectl logs -l app.kubernetes.io/component=glpi"
    echo "  Ver logs de Keycloak: kubectl logs -l app.kubernetes.io/component=keycloak"
    echo "  Ver logs de OAuth2-Proxy: kubectl logs -l app.kubernetes.io/component=oauth2-proxy"
    echo "  Desinstalar: helm uninstall $RELEASE_NAME"
    echo
    
    if [ "$VALUES_FILE" = "values-production.yaml" ]; then
        print_warning "IMPORTANTE: Cambia las contraseñas por defecto en el archivo values-production.yaml antes de usar en producción"
    fi
}

# Función principal
main() {
    echo "=========================================="
    echo "  GLPI SSO Helm Chart Installation"
    echo "=========================================="
    echo
    
    check_prerequisites
    add_helm_repos
    install_dependencies
    get_configuration
    get_release_name
    check_existing_release
    install_chart
    show_post_install_info
}

# Ejecutar función principal
main "$@"
