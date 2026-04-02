# Session Summary - 2026-03-30

Este documento recoge la continuación de la sesión anterior, centrada en arrancar la `Prioridad 1` del backlog:

- GitHub runner
- OIDC
- primer workflow federado mínimo

## Validación final de la réplica en `francecentral`

En esta misma fecha también quedó validada la réplica completa en la suscripción `Azure for Students` y región `francecentral`.

Resultado:

- `hub-spoke-repo`: `terraform plan` sin cambios
- `mlops-platform-repo`: `terraform plan` sin cambios
- OPNsense restaurado correctamente desde backup validado de `staging`
- OpenVPN operativa contra la nueva IP pública del NVA
- acceso a Azure ML Studio validado desde el portátil conectado por VPN
- smoke test de training validado en AML
- registro manual de modelo validado
- smoke test de serving validado con invocación correcta

### OPNsense

Se reutilizó un backup real exportado del entorno funcional anterior:

- `docs/config-OPNsense.localhost-20260330054513.xml`

Comportamiento observado:

- no hizo falta cambiar IPs internas ni rutas del backup
- esto fue posible porque la réplica reutiliza exactamente los mismos CIDRs privados:
  - hub `10.0.0.0/22`
  - trust `10.0.0.128/26`
  - OPNsense trust `10.0.0.132`
  - OpenVPN `172.16.100.0/24`
  - spoke `10.1.0.0/22`
- el ajuste mínimo necesario fue reexportar el perfil OpenVPN con la IP pública actual del nuevo firewall

Valor usado en `Client Export`:

- `Host Name Resolution = 20.43.59.27`

Credenciales operativas confirmadas:

- antes del restore:
  - `root / opnsense`
- después del restore:
  - `root / Passw0rd.2018`
- VPN:
  - `vpnuser1 / Passw0rd.2018`

### Validación funcional

Quedó comprobado de forma efectiva:

- conexión OpenVPN correcta
- acceso al nuevo OPNsense por la VPN
- resolución privada suficiente para el entorno reutilizando la configuración DNS del backup
- acceso correcto a Azure ML Studio sobre el workspace privado de `francecentral`
- job `train_iris` completado en `cpu-cluster-stg`
- modelo `iris-rf-model:1` registrado en el workspace
- endpoint `iris-pkl-stg` creado con identidad `user_assigned`
- deployment `blue` creado correctamente con `Standard_DS2_v2`
- inferencia correcta con respuesta:
  - `result = [0, 1, 2]`

Conclusión operativa:

- para esta réplica, la reutilización del backup de OPNsense es válida y reduce mucho el trabajo manual
- mientras se mantengan los mismos rangos privados, la adaptación principal tras importar el backup es actualizar la IP pública del export OpenVPN
- la validación de AML Studio desde VPN confirma que la cadena OPNsense -> OpenVPN -> DNS privado -> Private Endpoints funciona en el entorno `frc`
- la validación manual confirma además que el patrón completo de MLOps sigue operativo:
  - training
  - registro de modelo
  - serving privado

Observación específica de la suscripción `Azure for Students`:

- `Standard_E2s_v3` no tenía cuota disponible para el deployment online
- se ajustó el smoke test de serving a `Standard_DS2_v2`
- el deployment quedó en `Succeeded` con ese SKU

## Estado de partida

Se partía de este estado ya validado:

- `hub-spoke-repo` operativo en `staging`
- `mlops-platform` convergente con Terraform
- workspace AML en `Managed Virtual Network`
- training validado
- registro de modelo validado
- endpoint AML validado
- endpoint endurecido con:
  - identidad `user_assigned`
  - `public_network_access = disabled`

## Decisión para la Prioridad 1

Se decidió separar dos problemas distintos:

1. login federado de GitHub hacia Azure
2. registro y operación del self-hosted runner en GitHub

Razón:

- OIDC puede dejarse reproducible ya desde Terraform y un workflow mínimo
- el registro del runner en GitHub depende de credenciales o token de registro y conviene tratarlo aparte

## Hallazgo sobre el estado real del runner

El runner actual sí existe como VM privada y sí está bootstrapado con tooling base:

- `docker`
- `azure-cli`
- `terraform`
- extensión `az ml`

Pero no existe todavía en el repo una automatización cerrada para:

- registrar la VM como self-hosted runner de GitHub
- mantener ese registro de forma persistente y reproducible

Conclusión:

- la VM runner existe
- el toolchain base existe
- el registro GitHub del runner sigue pendiente

## Soporte OIDC añadido

En `mlops-platform` se añadió soporte opcional para OIDC con GitHub.

### Infraestructura nueva

Se creó el módulo:

- `infrastructure/modules/github-oidc`

Ese módulo crea:

- `App Registration`
- `Service Principal`
- `federated identity credential` para GitHub Actions

Patrón de sujeto creado:

- `repo:<owner>/<repo>:ref:refs/heads/<main-branch>`

Además, se deja una asignación opcional de rol Azure sobre el RG del workload.

Decisión adicional tomada en esta continuación:

- para `staging`, el principal OIDC se dejará con:
  - `Owner`
  sobre:
  - `rg-mlops-workload-stg-weu-01`
- esto se acepta como atajo temporal para desbloquear pipelines
- no se considera el modelo final de permisos

### Configuración nueva

Se añadieron variables nuevas a la configuración del workload:

- `GITHUB_OWNER`
- `GITHUB_REPOSITORY`
- `GITHUB_MAIN_BRANCH`
- `GITHUB_OIDC_ROLE_DEFINITION_NAME`

Regla operativa:

- si `GITHUB_OWNER` y `GITHUB_REPOSITORY` están vacíos, Terraform no crea OIDC
- si se rellenan, Terraform sí crea la federación

Matiz importante para el despliegue real:

- la `federated credential` queda ligada a:
  - repo
  - owner/org
  - branch
- no conviene aplicar todavía la federación definitiva mientras no esté decidido qué repo de GitHub será el real
- valores de arranque razonables, si finalmente este repo es el que automatiza:
  - `GITHUB_OWNER=<usuario-u-org-definitiva>`
  - `GITHUB_REPOSITORY=mlops-platform`
  - `GITHUB_MAIN_BRANCH=main`

### Outputs nuevos

Se añadieron outputs para exponer:

- `github_oidc_application_client_id`
- `github_oidc_tenant_id`
- `github_oidc_branch_subject`

## Workflow mínimo añadido

Se añadió un workflow inicial:

- `.github/workflows/azure-federated-login.yml`

Objetivo:

- validar el login federado con `azure/login@v2`
- sin mezclar todavía despliegues AML, Terraform ni el self-hosted runner

Características:

- `workflow_dispatch`
- `permissions.id-token = write`
- `runs-on: ubuntu-latest`

Variables GitHub que habrá que cargar en el repositorio:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

Secuencia recomendada cuando se haga el despliegue real:

1. fijar repo y branch definitivos
2. rellenar `config/staging.env`
3. regenerar configuración
4. ejecutar `terraform init`
5. ejecutar `terraform plan`
6. aplicar
7. copiar outputs a variables de GitHub
8. lanzar el workflow de login

## Estado al cierre de esta sesión

Queda hecho:

- soporte IaC base para OIDC
- configuración de entrada para OIDC
- workflow mínimo de login federado

Queda pendiente dentro de la misma `Prioridad 1`:

- ejecutar `terraform init` con provider `azuread`

## Actualización posterior del mismo día

En una continuación posterior de la misma fecha se cerró además la preparación del paquete `delivery-tfm` y la validación reproducible del baseline privado en `francecentral` usando `instance = 02`.

### Motivo para usar `02`

No se reutilizó `01` porque el Key Vault histórico seguía en `soft-delete` con `purge protection`, por lo que no era posible recrear inmediatamente `kv-mlops-stg-frc-01`.

Se trabajó por tanto con:

- hub/spoke `rg-mlops-infra-stg-frc-02`
- workload `rg-mlops-workload-stg-frc-02`
- workspace `mlw-mlops-stg-frc-02`

### Ajustes en `delivery-tfm`

Se dejó el paquete de entrega más limpio y reproducible:

- documentación principal concentrada en:
  - `delivery-tfm/docs/README_hub-spoke.md`
  - `delivery-tfm/docs/README_mlopsplatform.md`
- eliminación del runbook y `README.md` internos redundantes
- limpieza de estados Terraform, ficheros generados y referencias operativas obsoletas
- plantilla `mlops-platform-repo/config/staging.env.example` actualizada a `francecentral / frc`
- credenciales operativas retiradas de las plantillas para dejar el paquete listo para reprovisión limpia

También se corrigió el orden documental real del despliegue:

1. copiar plantilla
2. importar outputs del hub
3. renderizar configuración del workload
4. desplegar
5. restaurar OPNsense y validar VPN/Studio

### Recuperación del despliegue `hub-spoke`

El redeploy de `hub-spoke` en `02` terminó convergiendo, pero fue necesario recuperar recursos creados en un `partial apply`.

Se importaron al state:

- `diag-public-ip-to-law`
- `diag-hub-vnet-to-law`
- `diag-spoke-vnet-to-law`
- `audit-allowed-location`

Tras esos imports:

- `terraform apply` completó correctamente
- `terraform plan` quedó en `No changes`

Valor operativo relevante del NVA restaurado:

- `nva_public_ip = 20.199.114.105`

### Recuperación del despliegue `mlops-platform`

El despliegue del workload también dejó recursos globales creados a nivel suscripción que no estaban en el state local.

Fue necesario importar las `custom policy definitions`:

- `audit-aml-workspace-public-access-disabled`
- `audit-allowed-aml-compute-sizes`
- `audit-allowed-vm-sizes`
- `audit-allowed-aml-online-deployment-sizes`
- `audit-storage-public-access-disabled`
- `audit-acr-public-access-disabled`
- `audit-keyvault-public-access-disabled`

Además, se reforzó el `main.tf` del entorno `staging` en `delivery-tfm/mlops-platform-repo` para que las `policy assignments` no dependan de outputs incompletos del módulo de definiciones durante imports parciales.

Resultado final:

- `mlops-platform-repo`: `terraform plan` en `No changes`

### Restauración y validación operativa final

La restauración del backup validado de OPNsense volvió a funcionar correctamente.

Credenciales confirmadas:

- antes del restore:
  - `root / opnsense`
- después del restore:
  - `root / Passw0rd.2018`
- VPN:
  - `vpnuser1 / Passw0rd.2018`

Validación funcional cerrada en esta réplica `frc-02`:

- OPNsense accesible
- backup restaurado correctamente
- OpenVPN operativa
- acceso a Azure ML Studio correcto desde el portátil conectado por VPN
- `hub-spoke-repo`: convergente
- `mlops-platform-repo`: convergente

Conclusión adicional del día:

- el paquete `delivery-tfm` ya sirve como base transportable para repetir la instalación
- la recuperación tras `partial apply` debe documentarse como flujo normal de operación:
  - identificar recursos singleton/globales ya creados
  - importarlos al state
  - repetir `plan/apply`
- rellenar `GITHUB_OWNER` y `GITHUB_REPOSITORY`
- aplicar Terraform para crear la federación real
- copiar outputs a variables del repo GitHub
- lanzar el workflow de login
- decidir el patrón final del self-hosted runner:
  - registro manual controlado
  - o automatización adicional
- revisar más adelante el `Owner` temporal del principal OIDC y separarlo por función si hace falta:
  - `infra`
  - `ml-train`
  - `ml-deploy`

Pendiente específico para que el runner quede operativo de verdad:

- descargar e instalar el agente oficial de GitHub Actions runner
- registrar la VM runner contra GitHub
- decidir si el registro será:
  - a nivel de repositorio
  - o a nivel de organización
- instalar el runner como servicio persistente
- decidir cómo se suministrará el token de registro:
  - manual temporal
  - PAT
  - GitHub App
- documentar el procedimiento de reprovisión si la VM runner se recrea

## Punto de continuación recomendado

La siguiente iteración debe empezar por:

1. rellenar `GITHUB_OWNER`, `GITHUB_REPOSITORY` y `GITHUB_MAIN_BRANCH`
2. ejecutar `terraform init` para descargar también el provider `azuread`
3. hacer `terraform plan`
4. aplicar y recoger:
   - `github_oidc_application_client_id`
   - `github_oidc_tenant_id`
5. cargar esas variables en GitHub
6. lanzar `azure-federated-login.yml`

Solo después de validar eso conviene pasar a:

- registro del self-hosted runner en GitHub
- y luego al endurecimiento de `egress`

## Definición inicial de Azure Policy en modo audit

En esta continuación también se dejó definida la base de policies de tags obligatorios en `audit`, separadas por scope para no forzar el mismo conjunto de tags en hub y spoke.

### Hub

Scope:

- `rg-hub`

Tags obligatorios auditados:

- `owner`
- `cost_center`
- `project`

### Spoke de infraestructura

Scope:

- `rg-mlops-infra-stg-weu-01`

Tags obligatorios auditados:

- `owner`
- `cost_center`
- `project`
- `environment`

### Workload

Scope:

- `rg-mlops-workload-stg-weu-01`

Tags obligatorios auditados:

- `owner`
- `cost_center`
- `project`
- `environment`

### Implementación

Se creó un módulo reusable:

- `policy-require-tags`

Y se instanció:

- en `hub-spoke-repo` para:
  - hub
  - spoke infra
- en `mlops-platform` para:
  - workload

La policy usada es la built-in de Azure para auditar existencia de tag obligatorio.

Estado:

- definición hecha en código
- pendiente todavía de `terraform plan/apply` para materializarla en Azure

## Ajuste posterior en allowed locations

La policy de `allowed locations` se ha reajustado para que no quede solo sobre `rg-hub`.

Decisión final:

- `allowed locations` se asigna a nivel de suscripción
- lista actual permitida:
  - `westeurope`
  - `francecentral`

Razón:

- así cubre de forma homogénea:
  - hub
  - spoke infra
  - workload
- y se evita duplicar la misma policy por RG cuando el criterio de localización es común

## Definición inicial de Azure Policy para acceso público

Se añadió una primera tanda de policies custom en modo `audit` para acceso público en recursos sensibles del workload.

Scope:

- `rg-mlops-workload-stg-weu-01`

Servicios cubiertos:

- Storage Account
- Key Vault
- ACR
- Azure ML Workspace

Comportamiento:

- auditan recursos cuyo `publicNetworkAccess` no esté en `Disabled`
- no bloquean
- no remedian

Razón:

- visibilidad temprana sobre exposición pública
- sin introducir todavía `deny`
- acotado al RG del workload, donde están los recursos más sensibles del patrón MLOps

## Definición inicial de Azure Policy para tamaños permitidos

Se dejó también definida una primera tanda de policies custom en modo `audit` para tamaños permitidos en el RG del workload.

Scope:

- `rg-mlops-workload-stg-weu-01`

Cobertura:

- VM normales del workload:
  - `Standard_D2s_v3`
- AML compute:
  - `Standard_DS2_v2`
- Managed Online Deployments:
  - `Standard_E2s_v3`
  - `Standard_DS2_v2`

Base técnica validada:

- se confirmaron aliases Azure Policy válidos para:
  - `Microsoft.MachineLearningServices/workspaces/computes/vmSize`
  - `Microsoft.MachineLearningServices/workspaces/onlineEndpoints/deployments/instanceType`

Objetivo:

- dejar visibilidad temprana de drift de tamaños y coste
- sin introducir todavía políticas de `deny`

## Diagnostic settings para observabilidad de infraestructura

Se dejó finalmente activada observabilidad centralizada en el hub.

Backend compartido en `hub-spoke-repo`:

- `log-hub-weu-01`
- `appi-hub-weu-01`

Recursos del workload en `mlops-platform`, enviando a `log-hub-weu-01`:

- `Storage Blob Service`
- `Key Vault`
- `ACR`
- `AML Workspace`

Recursos de red/base en `hub-spoke-repo`, enviando a `log-hub-weu-01`:

- `hub vnet`
- `spoke vnet`
- `NSG` untrust de la NVA
- `Public IP` de la NVA

Matices validados:

- `Storage` no soporta `allLogs` en el `storage account` raíz:
  - se configura sobre `blobServices/default`
  - con categorías `StorageRead`, `StorageWrite`, `StorageDelete`
  - y métricas `Capacity`, `Transaction`
- `Route Tables` no soportan `diagnostic settings`

Decisión final de arquitectura:

- `mlops-platform` consume siempre observabilidad compartida del hub
- `staging` fue migrado para quedar alineado con el modelo final
- nuevos entornos deben nacer ya con este mismo patrón
