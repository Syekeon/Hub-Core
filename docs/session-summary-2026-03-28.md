# Session Summary - 2026-03-28

Este documento recoge lo realizado en la sesión posterior al despliegue base de `hub-spoke-repo`, centrada en:

- arranque de `mlops-platform`
- despliegue base del workload MLOps
- privatización de recursos
- validación del acceso por VPN
- ajustes finales de OPNsense para DNS privado

## Estado al inicio de la sesión

Partíamos de este estado ya operativo:

- `hub-spoke-repo` desplegado
- Hub:
  - `rg-hub`
  - `hub-vnet` -> `10.0.0.0/22`
  - OPNsense trust -> `10.0.0.132`
  - OpenVPN operativo
- Spoke de red:
  - `rg-mlops-infra-stg-weu-01`
  - `vnet-mlops-stg-weu-01` -> `10.1.0.0/22`
  - `snet-mlops-aml-compute` -> `10.1.0.0/24`
  - `snet-mlops-private-endpoints` -> `10.1.1.0/26`
  - `snet-mlops-devops-runner` -> `10.1.1.64/27`
- `Private DNS Zones` del hub creadas y enlazadas al hub y al spoke

## Repositorio `mlops-platform`

Se creó la estructura inicial completa del repo:

- `config/`
- `scripts/`
- `infrastructure/envs/staging/`
- `infrastructure/modules/`

### Script de configuración

Se decidió separar visualmente los scripts por responsabilidad:

- `hub-spoke-repo/scripts/render-infra-config.sh`
- `mlops-platform-repo/scripts/render-workload-config.sh`

El script antiguo de nombre genérico no se reutiliza para el repo de workload.

### Módulos creados

Se crearon los módulos base de `mlops-platform`:

- `governance`
- `naming`
- `resource-groups`
- `identities`
- `log-analytics`
- `application-insights`
- `storage-aml`
- `key-vault`
- `acr`
- `aml-workspace`
- `private-endpoints`

## Despliegue del workload base

Se desplegó correctamente en `rg-mlops-workload-stg-weu-01`:

- `id-mlops-stg-endpoint-weu-01`
- `id-mlops-stg-runner-weu-01`
- `log-mlops-stg-weu-01`
- `appi-mlops-stg-weu-01`
- `stmlopsstgweu01`
- `kv-mlops-stg-weu-01`
- `acrmlopsstgweu01`
- `mlw-mlops-stg-weu-01`

### Naming confirmado

Se consolidó la convención:

- nombres de recursos con `stg`
- tags con `environment=staging`

## Restricción real detectada en Azure ML

Durante el primer despliegue del workspace AML apareció este error:

- `Cannot use storage with HNS enabled`

Conclusión validada:

- `Azure Machine Learning Workspace` no puede usar como almacenamiento principal una cuenta con `Hierarchical Namespace (HNS)` habilitado

Corrección aplicada:

- en `mlops-platform`, el storage principal del workspace quedó con:
  - `is_hns_enabled = false`

Además:

- se eliminó el `Private Endpoint` `dfs`, ya que dejaba de ser necesario para el storage principal del workspace AML

## Despliegue por fases en `mlops-platform`

Se decidió implementar el repo en dos fases:

### Fase 1: pública para validación

Se añadió el flag:

- `ENABLE_PRIVATE_NETWORKING=false`

Con ese modo:

- Storage, Key Vault, ACR y AML Workspace mantienen acceso público
- no se crean `Private Endpoints`

Esto permitió validar:

- naming
- dependencias Terraform
- creación correcta del workspace AML

### Fase 2: privatización

Se cambió a:

- `ENABLE_PRIVATE_NETWORKING=true`

Y se aplicó correctamente:

- `public_network_access_enabled = false` en:
  - Storage
  - Key Vault
  - ACR
  - AML Workspace

- creación de `Private Endpoints`:
  - `pep-storage-blob`
  - `pep-key-vault`
  - `pep-acr-registry`
  - `pep-aml-workspace`

## Problema de DNS privado a través de la VPN

Tras privatizar, se comprobó que:

- los recursos privados existían
- las `Private DNS Zones` en Azure tenían los registros A correctos
- pero el cliente conectado por VPN seguía resolviendo IPs públicas

### Qué se validó

1. Azure Private DNS sí tenía los registros esperados, por ejemplo:
   - `kv-mlops-stg-weu-01.privatelink.vaultcore.azure.net` -> `10.1.1.4`
   - `stmlopsstgweu01.privatelink.blob.core.windows.net` -> `10.1.1.7`

2. OPNsense, usando `Diagnostics > DNS Lookup` con servidor `168.63.129.16`, sí resolvía a IP privada.

3. OPNsense, resolviendo por su Unbound “normal”, devolvía IP pública.

Conclusión:

- Azure DNS funcionaba
- los `Private Endpoints` funcionaban
- el problema estaba en la configuración DNS de OPNsense para las zonas `privatelink...`

## Ajustes manuales necesarios en OPNsense

### 1. Ruta estática para clientes OpenVPN

Se añadió:

- destino: `172.16.100.0/24`
- gateway: `10.0.0.129`

Notas:

- `172.16.100.0/24` es la red de clientes OpenVPN
- `10.0.0.129` es la gateway Azure de la subnet trust `10.0.0.128/26`

### 2. DNS del sistema

En `System > Settings > General` se dejó:

- DNS server: `168.63.129.16`
- eliminado DNS público como `8.8.4.4`
- desactivado el override DNS por WAN

### 3. Unbound DNS

Se ajustó:

- `Enable Unbound`
- `Enable Forwarding Mode`
- `Network Interfaces`: todas
- `Outgoing Network Interfaces`: todas
- `Flush DNS Cache during reload`: activado
- `DNSSEC`: desactivado para esta validación

### 4. Query Forwarding en Unbound

Punto clave de la sesión.

El ejemplo original solo incluía:

- `internal.cloudlab.local -> 168.63.129.16`

Eso no basta para Azure ML Private Link.

Se añadieron en `Services > Unbound DNS > Query Forwarding`:

- `privatelink.vaultcore.azure.net -> 168.63.129.16`
- `privatelink.blob.core.windows.net -> 168.63.129.16`
- `privatelink.azurecr.io -> 168.63.129.16`
- `privatelink.api.azureml.ms -> 168.63.129.16`
- `privatelink.notebooks.azure.net -> 168.63.129.16`
- `api.azureml.ms -> 168.63.129.16`
- `notebooks.azure.net -> 168.63.129.16`
- `instances.azureml.ms -> 168.63.129.16`
- `aznbcontent.net -> 168.63.129.16`
- `inference.westeurope.api.azureml.ms -> 168.63.129.16`

Ese fue el cambio que finalmente hizo que el cliente VPN resolviera IPs privadas.

## Ajustes del servidor OpenVPN

Se revisó el servidor y se corrigieron/confirmaron estos puntos:

- `IPv4 Tunnel Network`: `172.16.100.0/24`
- `IPv4 Local Network` corregido a:
  - `10.0.0.0/22,10.1.0.0/22`
- `Topology`: `subnet`
- DNS entregado a clientes VPN:
  - `DNS Server #1 = 10.0.0.132`
  - `push "dhcp-option DNS 10.0.0.132"`
  - `push "register-dns"`

Motivo de la corrección de `IPv4 Local Network`:

- estaba heredado de una red más amplia del ejemplo
- no reflejaba correctamente las redes reales del hub y del spoke del TFM

Además:

- `block-outside-dns` hizo que `OpenVPN Connect` en Windows se quedara en `Trying to connect`
- se retiró para seguir usando ese cliente
- aun así, el cliente no aplicó correctamente el DNS empujado y hubo que fijar manualmente `10.0.0.132` en el adaptador `TAP-Windows Adapter V9 for OpenVPN Connect`

## Reglas de firewall ajustadas en OpenVPN

Se añadió una regla explícita para DNS hacia el firewall:

- `IPv4`
- `TCP/UDP`
- origen: `172.16.100.0/24`
- destino: `This Firewall`
- puerto destino: `53`

Y se dejó una regla general de paso para pruebas:

- origen VPN
- destino `any`

## Validación final conseguida

Al cierre de la sesión:

- `ping 172.16.100.1` desde el portátil VPN funciona
- `ping 10.0.0.132` desde el portátil VPN funciona
- resolución DNS privada a través de la VPN funciona

Se pudo resolver correctamente por ejemplo:

- `kv-mlops-stg-weu-01.privatelink.vaultcore.azure.net`
- `stmlopsstgweu01.privatelink.blob.core.windows.net`
- `acrmlopsstgweu01.privatelink.azurecr.io`
- `9332539b-ef8b-4cb9-8fc1-22af35747521.workspace.westeurope.api.azureml.ms -> 10.1.1.8`
- `ml-mlw-mlops-st-westeurope-9332539b-ef8b-4cb9-8fc1-22af35747521.westeurope.notebooks.azure.net -> 10.1.1.9`

## Validación adicional posterior: Azure ML Studio

En la validación posterior del acceso a Studio se confirmó:

- el `Azure ML Workspace` solo acepta `groupId = amlworkspace`
- no se puede crear un `Private Endpoint` separado con `groupId = notebooks`
- la forma correcta es asociar al mismo `Private Endpoint` del workspace las dos zonas:
  - `privatelink.api.azureml.ms`
  - `privatelink.notebooks.azure.net`

La prueba decisiva fue:

- con `nslookup <fqdn> 10.0.0.132` se obtenían IPs privadas
- con `nslookup <fqdn>` sin forzar servidor, Windows seguía usando el DNS del Wi-Fi y devolvía IP pública

Conclusión final:

- Azure estaba correctamente desplegado
- OPNsense resolvía correctamente
- el último bloqueo estaba en el cliente Windows/OpenVPN y no en Azure

## Estado actual consolidado

### `hub-spoke-repo`

Operativo y validado:

- hub
- OPNsense
- OpenVPN
- spoke de red
- peering
- UDR
- `Private DNS Zones`
- DNS privado funcional desde la VPN

### `mlops-platform`

Operativo y validado en su capa base:

- identities
- observabilidad
- storage AML
- key vault
- ACR premium
- AML workspace
- privatización con `Private Endpoints`

## Siguiente paso recomendado

El siguiente bloque lógico para continuar mañana es:

1. añadir en `hub-spoke-repo` la ruta UDR explícita del spoke para:
   - `172.16.100.0/24 -> 10.0.0.132`
2. validar acceso a recursos privatizados usando nombres públicos y privados
3. continuar en `mlops-platform` con:
   - RBAC
   - runner VM
   - AML Compute Cluster

## Cómo retomar mañana

Abrir Codex en la raíz del workspace:

```bash
cd /home/lfernanz/mlopsproject/repo-root
codex
```

Y enviar:

```text
Retomamos. Lee:
- hub-spoke-repo/docs/session-summary-2026-03-27.md
- hub-spoke-repo/docs/session-summary-2026-03-28.md
- hub-spoke-repo/README.md
- mlops-platform-repo/README.md

Quiero continuar desde el estado actual validado de VPN + DNS privado + mlops-platform base privatizado.
```

## Cierre real adicional de la sesión

En el tramo final de la sesión se completó la validación de acceso privado a `Azure ML Studio` y se documentó el procedimiento para poder retomarlo mañana sin rehacer el diagnóstico.

### 1. Corrección Terraform en `mlops-platform`

Se revisó el comportamiento del `Private Endpoint` del workspace AML.

Conclusión confirmada:

- `Azure ML Workspace` solo acepta `groupId = amlworkspace`
- no se puede crear un `Private Endpoint` adicional con `groupId = notebooks`
- el mismo `Private Endpoint` del workspace debe asociarse a:
  - `privatelink.api.azureml.ms`
  - `privatelink.notebooks.azure.net`

Acción aplicada:

- se actualizó `mlops-platform` para asociar ambas zonas DNS privadas al `Private Endpoint` `pep-aml-workspace`
- el `terraform apply` se ejecutó correctamente y modificó el `private_dns_zone_group` del PE existente

### 2. Obtención de los FQDN reales del workspace AML

Se consultó la NIC del `Private Endpoint` `pep-aml-workspace` y se obtuvieron los FQDN reales asociados por Azure:

- `9332539b-ef8b-4cb9-8fc1-22af35747521.workspace.westeurope.api.azureml.ms` -> `10.1.1.8`
- `9332539b-ef8b-4cb9-8fc1-22af35747521.workspace.westeurope.cert.api.azureml.ms` -> `10.1.1.8`
- `ml-mlw-mlops-st-westeurope-9332539b-ef8b-4cb9-8fc1-22af35747521.westeurope.notebooks.azure.net` -> `10.1.1.9`
- `*.9332539b-ef8b-4cb9-8fc1-22af35747521.inference.westeurope.api.azureml.ms` -> `10.1.1.10`

Lección importante:

- no hay que validar AML Studio con nombres inventados del tipo `mlw-...api.azureml.ms`
- primero hay que sacar los FQDN reales desde la NIC del `Private Endpoint`

### 3. Estado real de OPNsense al cierre

Se confirmó que OPNsense resolvía correctamente por privado cuando se consultaba contra `10.0.0.132`.

Validaciones correctas:

- `...workspace...api.azureml.ms` -> `10.1.1.8`
- `...notebooks.azure.net` -> `10.1.1.9`

Además, se amplió la documentación para dejar reflejados los forwarders necesarios en Unbound:

- `privatelink.vaultcore.azure.net`
- `privatelink.blob.core.windows.net`
- `privatelink.azurecr.io`
- `privatelink.api.azureml.ms`
- `privatelink.notebooks.azure.net`
- `api.azureml.ms`
- `notebooks.azure.net`
- `instances.azureml.ms`
- `aznbcontent.net`
- `inference.westeurope.api.azureml.ms`

Todos reenviados a:

- `168.63.129.16`

### 4. Causa raíz del error de AML Studio

El error:

- `You are attempting to access a restricted resource from an unauthorized network location`

no estaba causado por Azure ni por los `Private Endpoints`.

Causa raíz validada:

- el portátil Windows resolvía inicialmente usando el DNS del Wi-Fi (`192.168.18.1`)
- por eso `nslookup` sin servidor explícito devolvía IPs públicas
- en cambio, `nslookup ... 10.0.0.132` devolvía IPs privadas correctas

Conclusión:

- Azure estaba bien
- OPNsense estaba bien
- el último bloqueo estaba en el cliente Windows/OpenVPN

### 5. Hallazgo específico sobre OpenVPN Connect en Windows

Se confirmó este comportamiento real:

- `OpenVPN Connect` no aplicó correctamente el DNS empujado al adaptador activo del túnel
- `block-outside-dns` hizo que el cliente se quedara en `Trying to connect`
- quitar `block-outside-dns` permitió volver a conectar
- para validar el acceso privado fue necesario fijar manualmente `10.0.0.132` como DNS del adaptador `TAP-Windows Adapter V9 for OpenVPN Connect`

Resultado final en el portátil:

- `nslookup 9332539b-ef8b-4cb9-8fc1-22af35747521.workspace.westeurope.api.azureml.ms`
  - servidor: `10.0.0.132`
  - respuesta privada: `10.1.1.8`
- `nslookup ml-mlw-mlops-st-westeurope-9332539b-ef8b-4cb9-8fc1-22af35747521.westeurope.notebooks.azure.net`
  - servidor: `10.0.0.132`
  - respuesta privada: `10.1.1.9`

Con esto, la conectividad privada necesaria para AML Studio quedó funcional a nivel de DNS.

### 6. Documentación creada/actualizada en este cierre

Se actualizaron:

- `hub-spoke-repo/README.md`
- `mlops-platform-repo/README.md`
- `hub-spoke-repo/docs/session-summary-2026-03-28.md`

Y se creó además una guía nueva para compartir o reutilizar una copia del OPNsense:

- `hub-spoke-repo/docs/opnsense-reuse-checklist.md`

Esa guía quedó enlazada desde el README del repo de red.

### 7. Punto exacto para continuar mañana

El estado validado al cerrar es:

- `hub-spoke-repo` operativo
- DNS privado por VPN operativo
- `mlops-platform` base privatizado
- acceso DNS privado a AML Studio validado
- documentación del comportamiento real ya actualizada

Siguiente paso lógico mañana:

1. confirmar en navegador que AML Studio carga correctamente usando la resolución privada ya validada
2. decidir si se deja una solución permanente para el DNS del cliente VPN:
   - ajustar mejor el cliente OpenVPN en Windows
   - o documentar el ajuste manual del adaptador
3. continuar con la siguiente capa de `mlops-platform`:
   - RBAC
   - runner VM
   - AML Compute Cluster

## Cierre adicional posterior: RBAC y runner privado

En la continuación posterior de la sesión se completaron dos bloques nuevos en `mlops-platform`:

- `RBAC` base
- `runner VM` privado en la subnet `snet-mlops-devops-runner`

### 1. RBAC base aplicado

Se creó un módulo Terraform de `RBAC` y se aplicaron permisos base para:

- identidad del `AML Workspace` (`SystemAssigned`)
- identidad del endpoint (`UserAssigned`)
- identidad del runner (`UserAssigned`)

Además:

- `Key Vault` quedó en modo `rbac_authorization_enabled = true`

Asignaciones relevantes aplicadas:

- endpoint:
  - `AcrPull`
  - `Key Vault Secrets User`
  - `Storage Blob Data Reader`
- runner:
  - `Contributor` sobre `rg-mlops-workload-stg-weu-01`
  - `AcrPush`
  - `Key Vault Secrets Officer`
  - `Storage Blob Data Contributor`
- workspace:
  - `AcrPush`
  - `Key Vault Secrets Officer`

Hallazgo importante para reproducibilidad:

- no conviene declarar en Terraform el `Storage Blob Data Contributor` del `AML Workspace` sobre el storage principal
- Azure ML lo crea automáticamente
- cuando se intentó gestionarlo desde Terraform apareció `RoleAssignmentExists`
- se corrigió retirándolo del código y limpiándolo del state

Conclusión:

- el código quedó alineado para que en otros entornos no haga falta `terraform import` por ese caso

### 2. Runner VM privado aplicado

Se desplegó correctamente:

- VM: `vm-mlops-stg-runner-weu-01`
- NIC: `nic-mlops-stg-runner-weu-01`
- subnet: `snet-mlops-devops-runner`
- IP privada validada al cierre: `10.1.1.68`
- identidad asociada: `id-mlops-stg-runner-weu-01`

Tipo de identities consolidadas:

- `AML Workspace` -> `SystemAssigned`
- endpoint -> `UserAssigned`
- runner -> `UserAssigned`
- runner VM -> usa la `UserAssigned` del runner, no crea una nueva

### 3. Bootstrap del runner por `cloud-init`

Se añadió bootstrap reproducible vía `cloud-init` para instalar:

- `docker`
- `azure-cli`
- `terraform`
- extensión `az ml`

El primer intento falló aunque el YAML era correcto.

Causa raíz validada:

- la subnet del runner no tenía salida efectiva a Internet a través de OPNsense

Problemas detectados en OPNsense:

- faltaba regla de firewall en `LAN/trust` para permitir tráfico desde `10.1.0.0/22`
- faltaba regla de `Outbound NAT` hacia `WAN` para `10.1.0.0/22`

Tras añadir ambas reglas:

- el runner pudo hacer `ping` a `10.0.0.132`
- el runner pudo salir a Internet
- se recreó la VM runner para reejecutar el `cloud-init`

Validación funcional conseguida al cierre:

- acceso SSH al runner por VPN correcto
- `docker --version` correcto
- `az version` correcto
- `terraform version` correcto
- `az extension show --name ml` correcto

### 4. Estado exacto al cierre final

Al terminar la sesión queda validado:

- red hub-and-spoke operativa
- VPN OpenVPN operativa
- DNS privado de AML Studio operativo
- `mlops-platform` base privatizado
- `RBAC` base aplicado
- runner privado desplegado y funcional

### 5. Punto exacto para retomar mañana

El siguiente bloque lógico ya no es red ni runner base, sino:

1. `AML Compute Cluster`
2. después:
   - OIDC
   - GitHub Actions
   - registro/configuración del self-hosted runner de GitHub
