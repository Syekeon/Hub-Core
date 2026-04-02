# Session Summary - 2026-03-27

Este documento resume el estado exacto del trabajo realizado sobre `hub-spoke-repo` para poder continuar en otra sesión sin perder contexto.

## Objetivo general

Se está construyendo la base de conectividad y red para un TFM de MLOps en Azure con dos repositorios:

1. `hub-and-spoke`
2. `mlops-platform`

El objetivo del repo actual es dejar lista la parte de:

- Hub con OPNsense
- VPN OpenVPN
- spoke de red para el workload MLOps
- peering
- UDR
- Private DNS Zones compartidas

## Decisiones de arquitectura cerradas

### Repositorios

- `hub-spoke-repo`: red, conectividad, hub, spoke, DNS privado, peering, UDR
- `mlops-platform`: recursos MLOps, AML, ACR, Key Vault, Storage, identities, RBAC, runner, endpoints

### Naming

Patrón general:

`<tipo>-<workload>-<entorno>-<region>-<instancia>`

Excepciones explícitas:

- `rg-hub`
- recursos con restricciones de naming como `storage` y `acr`

Convención elegida:

- nombres de recursos del workload con `stg`
- tags con `environment=staging`

Ejemplos:

- `rg-mlops-infra-stg-weu-01`
- `rg-mlops-workload-stg-weu-01`
- `vnet-mlops-stg-weu-01`

### Tags obligatorios

- `project=mlops`
- `environment=staging`
- `owner=tfm`
- `cost_center=master`

### Private DNS

Las `Private DNS Zones` viven en el hub y no en `mlops-platform`.

Zonas definitivas:

- `privatelink.api.azureml.ms`
- `privatelink.notebooks.azure.net`
- `privatelink.blob.core.windows.net`
- `privatelink.dfs.core.windows.net`
- `privatelink.vaultcore.azure.net`
- `privatelink.azurecr.io`

### Red del hub

El hub se ha mantenido alineado con el ejemplo para facilitar OPNsense y OpenVPN:

- VNet: `hub-vnet`
- CIDR: `10.0.0.0/22`
- subnet NVA untrust: `10.0.0.64/26`
- subnet NVA trust: `10.0.0.128/26`
- IP trust OPNsense: `10.0.0.132`

### Red del spoke

El spoke se ha alineado con el diseño final del TFM:

- RG: `rg-mlops-infra-stg-weu-01`
- VNet: `vnet-mlops-stg-weu-01`
- CIDR: `10.1.0.0/22`

Subnets:

- `snet-mlops-aml-compute` -> `10.1.0.0/24`
- `snet-mlops-private-endpoints` -> `10.1.1.0/26`
- `snet-mlops-devops-runner` -> `10.1.1.64/27`

### UDR

Regla cerrada:

- `0.0.0.0/0 -> 10.0.0.132`

Aplicación:

- sí a `snet-mlops-aml-compute`
- sí a `snet-mlops-devops-runner`
- no a `snet-mlops-private-endpoints`

### VPN

Se decidió seguir con OpenVPN como en el ejemplo.

## Estado actual del despliegue

## Backend Terraform

Existe y no debe borrarse:

- RG: `rg-tfstate-mlops-staging-weu-01`
- Storage account: `sttfmlopsstgweu01`
- Container: `tfstate`

## Recursos desplegados correctamente

### Hub

- `rg-hub`
- `hub-vnet`
- subnets NVA
- OPNsense desplegado y accesible
- VPN OpenVPN operativa
- `Private DNS Zones` desplegadas y enlazadas al hub

### OPNsense

Estado funcional validado:

- Web GUI accesible públicamente
- configuración del ejemplo importada
- VPN conectando correctamente
- ping a `10.0.0.132` validado desde cliente VPN

IPs relevantes:

- IP trust OPNsense: `10.0.0.132`
- IP pública actual OPNsense: `20.229.73.69`

Credenciales actuales:

- acceso OPNsense tras importar XML:
  - usuario: `root`
  - password: `Passw0rd.2018`
- acceso OpenVPN:
  - usuario: `vpnuser1`
  - password: `Passw0rd.2018`

### spoke de red

Desplegado correctamente:

- `rg-mlops-infra-stg-weu-01`
- `vnet-mlops-stg-weu-01`
- `snet-mlops-aml-compute`
- `snet-mlops-private-endpoints`
- `snet-mlops-devops-runner`
- peering Hub <-> Spoke
- links de `Private DNS Zones` al spoke
- route table del spoke
- asociaciones de la route table a compute y runner

## Outputs disponibles al cierre de la sesión

Outputs de `terraform apply` al final:

- `hub_firewall_private_ip = 10.0.0.132`
- `hub_vnet_id = /subscriptions/c7c226e6-e7a0-4f38-bfe0-3acb0c838c99/resourceGroups/rg-hub/providers/Microsoft.Network/virtualNetworks/hub-vnet`
- `hub_vnet_name = hub-vnet`
- `nva_public_ip = 20.229.73.69`
- `nva_vm_name = hub-vm-nva`
- `spoke_vnet_id = /subscriptions/c7c226e6-e7a0-4f38-bfe0-3acb0c838c99/resourceGroups/rg-mlops-infra-stg-weu-01/providers/Microsoft.Network/virtualNetworks/vnet-mlops-stg-weu-01`
- `spoke_vnet_name = vnet-mlops-stg-weu-01`
- `spoke_aml_compute_subnet_id = /subscriptions/c7c226e6-e7a0-4f38-bfe0-3acb0c838c99/resourceGroups/rg-mlops-infra-stg-weu-01/providers/Microsoft.Network/virtualNetworks/vnet-mlops-stg-weu-01/subnets/snet-mlops-aml-compute`
- `spoke_private_endpoints_subnet_id = /subscriptions/c7c226e6-e7a0-4f38-bfe0-3acb0c838c99/resourceGroups/rg-mlops-infra-stg-weu-01/providers/Microsoft.Network/virtualNetworks/vnet-mlops-stg-weu-01/subnets/snet-mlops-private-endpoints`
- `spoke_devops_runner_subnet_id = /subscriptions/c7c226e6-e7a0-4f38-bfe0-3acb0c838c99/resourceGroups/rg-mlops-infra-stg-weu-01/providers/Microsoft.Network/virtualNetworks/vnet-mlops-stg-weu-01/subnets/snet-mlops-devops-runner`

## Cambios de código realizados en esta sesión

### README

Se rehizo el README principal como guía detallada para replicar el entorno:

- `README.md`

### Módulos añadidos

Se añadieron:

- `infrastructure/modules/spoke-network`
- `infrastructure/modules/route-tables`

### Cambios en entorno staging

Se actualizaron:

- `infrastructure/envs/staging/main.tf`
- `infrastructure/envs/staging/variables.tf`
- `infrastructure/envs/staging/outputs.tf`

### Configuración local

Se actualizaron:

- `config/staging.env`
- `config/staging.env.example`
- `scripts/render-infra-config.sh`
- `infrastructure/envs/staging/terraform.tfvars`

### OPNsense

Se generó un XML alineado al esquema del ejemplo:

- `docs/config-OPNsense.example-hub.xml`

Además existe otro XML adaptado a un addressing intermedio anterior:

- `docs/config-OPNsense.staging.xml`

Ese segundo fichero no es la referencia principal ahora mismo.

## Problemas encontrados y resueltos

### 1. Restos de recursos parciales

Hubo intentos previos con:

- Azure VPN Gateway
- configuración antigua del hub

Se resolvió limpiando `rg-hub` y rehaciendo el entorno.

### 2. OPNsense accesible por TCP pero no por HTTPS

Se diagnosticó que:

- el servicio estaba levantado
- faltaba la parte de NSG WAN adecuada por tratarse de una `Public IP Standard`

Se añadió NSG WAN con reglas para:

- `443/TCP`
- `22/TCP`
- `80/TCP`
- `1194/UDP`

### 3. OpenVPN no conectaba

Se resolvió combinando:

- importación del XML de OPNsense del ejemplo
- regla `1194/UDP` en Azure
- exportación correcta del perfil OpenVPN

### 4. Inconsistencia `staging` vs `stg`

Se normalizó:

- nombres de recursos con `stg`
- tags con `environment=staging`

## Continuación posterior sobre `mlops-platform`

En la sesión siguiente se avanzó sobre el segundo repositorio, `mlops-platform`, y se validaron varios puntos relevantes que impactan también en la operativa del hub.

### Recursos base desplegados en `mlops-platform`

Se desplegaron correctamente en `rg-mlops-workload-stg-weu-01`:

- `stmlopsstgweu01`
- `kv-mlops-stg-weu-01`
- `acrmlopsstgweu01`
- `log-mlops-stg-weu-01`
- `appi-mlops-stg-weu-01`
- `mlw-mlops-stg-weu-01`
- `id-mlops-stg-endpoint-weu-01`
- `id-mlops-stg-runner-weu-01`

### Restricción real de Azure ML detectada

Se validó durante el despliegue que:

- `Azure ML Workspace` no admite como storage principal una cuenta con `HNS` activado

Por ello, el storage principal del workspace quedó corregido a:

- `is_hns_enabled = false`

### Privatización validada

Se aplicó correctamente la capa privada de `mlops-platform`:

- `pep-storage-blob`
- `pep-key-vault`
- `pep-acr-registry`
- `pep-aml-workspace`

Y se deshabilitó acceso público en:

- Storage
- Key Vault
- ACR
- Azure ML Workspace

### Ajustes adicionales necesarios en OPNsense

Durante la validación desde cliente VPN se comprobó que la conectividad existía, pero la resolución DNS seguía siendo pública.

Se confirmó que:

- las `Private DNS Zones` de Azure sí tenían registros A correctos
- OPNsense no los resolvía bien por defecto aunque tuviera configurado `168.63.129.16`

Acciones manuales necesarias documentadas:

- ruta estática a `172.16.100.0/24` vía `10.0.0.129`
- `Unbound` en forwarding mode
- `Domain Overrides` para:
  - `privatelink.vaultcore.azure.net`
  - `privatelink.blob.core.windows.net`
  - `privatelink.azurecr.io`
  - `privatelink.api.azureml.ms`
  - `privatelink.notebooks.azure.net`

Se decidió:

- nombres de recursos: `stg`
- tags y valor semántico de entorno: `staging`

## Contexto del TFM que hay que mantener

El TFM busca una plataforma MLOps privada, gobernada y reproducible.

Decisiones relevantes ya fijadas:

- dos repositorios: `hub-and-spoke` y `mlops-platform`
- Terraform + GitHub Actions + Azure ML CLI v2
- OIDC, no secretos persistentes
- Private Endpoints para:
  - Storage AML blob
  - Key Vault vault
  - ACR registry
  - Azure ML Workspace amlworkspace
- grupos humanos:
  - `group-mlops-platform-engineers`
  - `group-mlops-data-scientists`
  - `group-mlops-readers`
- managed identities:
  - AML Workspace -> system assigned
  - Compute Cluster -> system assigned
  - Managed Online Endpoint -> `id-mlops-dev-endpoint-weu-01`
  - Runner -> `id-mlops-dev-runner-weu-01`
- RGs objetivo finales:
  - `rg-tfstate-mlops-staging-weu-01`
  - `rg-mlops-infra-stg-weu-01`
  - `rg-mlops-workload-stg-weu-01`

## Punto exacto para retomar mañana

El siguiente paso natural no está ya en `hub-spoke-repo`, sino en arrancar el segundo repositorio:

- `mlops-platform`

Orden recomendado para la siguiente sesión:

1. diseñar la estructura inicial de `mlops-platform`
2. crear el esqueleto Terraform del repo
3. usar como inputs de red los outputs de `hub-spoke-repo`
4. desplegar primero:
   - `rg-mlops-workload-stg-weu-01`
   - identidades
   - observabilidad
   - `Storage`
   - `Key Vault`
   - `ACR`
   - `Azure ML Workspace`
5. después:
   - `Private Endpoints`
   - `runner VM`
   - `Compute Cluster`
   - RBAC
   - OIDC

## Inputs que debe consumir `mlops-platform`

Mínimos:

- `spoke_vnet_id`
- `spoke_aml_compute_subnet_id`
- `spoke_private_endpoints_subnet_id`
- `spoke_devops_runner_subnet_id`
- `private_dns_zone_ids`

## Comandos útiles para empezar la próxima sesión

Comprobar outputs actuales:

```bash
cd infrastructure/envs/staging
terraform output
```

Comprobar recursos del hub:

```bash
az resource list --resource-group rg-hub --output table
```

Comprobar recursos del spoke:

```bash
az resource list --resource-group rg-mlops-infra-stg-weu-01 --output table
```

Comprobar IP pública actual de OPNsense:

```bash
az network public-ip show \
  --resource-group rg-hub \
  --name hub-pip-nva \
  --query ipAddress \
  -o tsv
```

## Ficheros de referencia principales

- `README.md`
- `config/staging.env`
- `scripts/render-infra-config.sh`
- `infrastructure/envs/staging/main.tf`
- `infrastructure/envs/staging/outputs.tf`
- `docs/config-OPNsense.example-hub.xml`

## Observación final

La base `hub-and-spoke` ha quedado funcional y defendible:

- acceso remoto validado
- conectividad privada preparada
- naming estabilizado
- outputs listos para el repo `mlops-platform`

No hay bloqueos técnicos abiertos en el repo actual. El trabajo pendiente está ya en la capa de plataforma MLOps.
