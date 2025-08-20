# GLPI SSO Helm Chart

Este chart de Helm despliega una stack completa de GLPI con autenticación SSO usando Keycloak y OAuth2-Proxy en Kubernetes.

## Componentes

- **GLPI**: Sistema de gestión de inventario y tickets
- **MySQL**: Base de datos para GLPI
- **Keycloak**: Servidor de identidad y acceso (IdP)
- **OAuth2-Proxy**: Proxy de autenticación OAuth2
- **Nginx Ingress**: Controlador de ingress (opcional)

## Prerrequisitos

- Kubernetes 1.19+
- Helm 3.0+
- Nginx Ingress Controller instalado
- StorageClass configurado (opcional)

## Instalación

### 1. Agregar repositorios de Helm

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add oauth2-proxy https://oauth2-proxy.github.io/manifests
helm repo update
```

### 2. Instalar dependencias

```bash
cd helm
helm dependency update
```

### 3. Instalar el chart

#### Desarrollo (localhost)
```bash
helm install glpi-sso . -f values-development.yaml
```

#### Producción
```bash
helm install glpi-sso . -f values-production.yaml
```

## Configuración

### Variables principales

| Parámetro | Descripción | Default |
|-----------|-------------|---------|
| `global.domain` | Dominio principal | `localhost` |
| `glpi.enabled` | Habilitar GLPI | `true` |
| `keycloak.enabled` | Habilitar Keycloak | `true` |
| `oauth2-proxy.enabled` | Habilitar OAuth2-Proxy | `true` |
| `mysql.enabled` | Habilitar MySQL | `true` |

### Configuración de seguridad

**IMPORTANTE**: Cambia todas las contraseñas por defecto en producción:

- `mysql.auth.rootPassword`
- `mysql.auth.password`
- `keycloak.auth.adminPassword`
- `oauth2-proxy.config.clientSecret`
- `oauth2-proxy.config.cookieSecret`

### Configuración de ingress

El chart configura automáticamente los ingress para:
- GLPI: `glpi.your-domain.com`
- Keycloak: `keycloak.your-domain.com`
- OAuth2-Proxy: `glpi.your-domain.com/oauth2`

## Acceso a las aplicaciones

### GLPI
- URL: `http://glpi.localhost` (desarrollo) o `https://glpi.your-domain.com` (producción)
- Autenticación: SSO a través de Keycloak

### Keycloak Admin Console
- URL: `http://keycloak.localhost` (desarrollo) o `https://keycloak.your-domain.com` (producción)
- Usuario: `admin`
- Contraseña: Configurada en `keycloak.auth.adminPassword`

## Configuración de Keycloak

### Realm GLPI
El chart crea automáticamente un realm llamado "glpi" con:
- Client ID: `glpi-proxy`
- Protocol: OpenID Connect
- Redirect URIs: Configurados según el dominio

### Configuración manual adicional
1. Accede a la consola de administración de Keycloak
2. Ve al realm "glpi"
3. Configura usuarios y grupos según necesites
4. Ajusta la configuración del client `glpi-proxy` si es necesario

## Troubleshooting

### Verificar el estado de los pods
```bash
kubectl get pods -l app.kubernetes.io/instance=glpi-sso
```

### Ver logs de un componente
```bash
kubectl logs -l app.kubernetes.io/component=glpi
kubectl logs -l app.kubernetes.io/component=keycloak
kubectl logs -l app.kubernetes.io/component=oauth2-proxy
```

### Verificar servicios
```bash
kubectl get svc -l app.kubernetes.io/instance=glpi-sso
```

### Verificar ingress
```bash
kubectl get ingress -l app.kubernetes.io/instance=glpi-sso
```

## Desinstalación

```bash
helm uninstall glpi-sso
```

**Nota**: Los PersistentVolumeClaims no se eliminan automáticamente. Para eliminarlos:

```bash
kubectl delete pvc -l app.kubernetes.io/instance=glpi-sso
```

## Migración desde Docker Compose

### 1. Exportar datos de GLPI
```bash
# Desde tu contenedor Docker actual
docker exec -it glpi-sso-clean_glpi_1 tar czf /tmp/glpi-backup.tar.gz /var/www/html/glpi
docker cp glpi-sso-clean_glpi_1:/tmp/glpi-backup.tar.gz ./glpi-backup.tar.gz
```

### 2. Exportar datos de Keycloak
```bash
# Desde tu contenedor Docker actual
docker exec -it glpi-sso-clean_keycloak_1 /opt/keycloak/bin/kc.sh export --dir=/tmp/export
docker cp glpi-sso-clean_keycloak_1:/tmp/export ./keycloak-export
```

### 3. Instalar con Helm
```bash
helm install glpi-sso ./helm -f helm/values-production.yaml
```

### 4. Restaurar datos
```bash
# Restaurar GLPI
kubectl cp glpi-backup.tar.gz glpi-sso-glpi-0:/tmp/
kubectl exec -it glpi-sso-glpi-0 -- tar xzf /tmp/glpi-backup.tar.gz -C /var/www/html/

# Restaurar Keycloak (si es necesario)
kubectl cp keycloak-export glpi-sso-keycloak-0:/opt/keycloak/data/import/
```

## Personalización

### Agregar variables de entorno personalizadas
```yaml
glpi:
  env:
    CUSTOM_VAR: "custom_value"
```

### Configurar recursos personalizados
```yaml
glpi:
  resources:
    limits:
      cpu: 2000m
      memory: 2Gi
    requests:
      cpu: 1000m
      memory: 1Gi
```

### Configurar storage personalizado
```yaml
glpi:
  persistence:
    storageClass: "my-storage-class"
    size: 50Gi
```

## Soporte

Para problemas o preguntas:
1. Revisa los logs de los pods
2. Verifica la configuración de ingress
3. Confirma que los servicios están funcionando
4. Verifica la conectividad entre componentes
