# Session Summary - 2026-03-29

Este documento recoge la evolución completa de la sesión hasta dejar validados:

- `AmlCompute` para training
- registro de modelo en Azure ML
- `Managed Online Endpoint` para serving
- decisión arquitectónica de pasar el workspace a `Managed Virtual Network`

## Estado de partida

Se partía de este escenario ya validado:

- `hub-spoke-repo` desplegado
- `mlops-platform` desplegado con networking privado
- `runner VM` privada operativa
- `Azure ML Workspace` privado
- `Storage`, `Key Vault` y `ACR` privados
- `AmlCompute` inicialmente desplegado en la subnet custom:
  - `snet-mlops-aml-compute`

## RBAC y reproducibilidad

Se consolidó el modelo de identidades administradas:

- `runner`: `id-mlops-stg-runner-weu-01`
- `endpoint`: `id-mlops-stg-endpoint-weu-01`
- `compute`: `id-mlops-stg-compute-weu-01`

RBAC explícito del compute gestionado por Terraform:

- `Storage Blob Data Contributor`
- `Key Vault Secrets User`

Caso especial detectado:

- `compute_acr_pull` ya existía o era creado por Azure
- Terraform chocaba con `RoleAssignmentExists`

Decisión:

- `compute_acr_pull` queda fuera de Terraform
- para reproducibilidad no se gestiona ese assignment desde código

## Problema real en jobs privados

El primer smoke test del compute falló con:

- `DownloadJobSpecFromXDSError`

La causa real no fue RBAC, sino conectividad privada incompleta al storage del workspace.

Estaban bien:

- `privatelink.api.azureml.ms`
- `privatelink.notebooks.azure.net`
- `privatelink.blob.core.windows.net`
- `privatelink.vaultcore.azure.net`
- `privatelink.azurecr.io`

Pero faltaban:

- zona `privatelink.file.core.windows.net`
- `Private Endpoint` `pep-storage-file`

## Corrección aplicada

En `hub-spoke-repo` se añadió:

- `privatelink.file.core.windows.net`
- link al `hub-vnet`
- link al `vnet-mlops-stg-weu-01`

En `mlops-platform` se añadió:

- `pep-storage-file`

Conclusión:

- para jobs AML privados no basta con `blob`
- también hace falta exponer `file` del storage principal del workspace

## Smoke test de training

Se creó un smoke test mínimo en:

- `mlops-platform-repo/ml/jobs/train_iris/`

Evolución:

- primer intento con environment inline propio
- fallo en `Image build failed`
- cambio a curated environment:
  - `azureml://registries/azureml/environments/sklearn-1.5/labels/latest`

Resultado:

- job completado correctamente
- training validado extremo a extremo

Posteriormente se mejoró el job para declarar un output formal:

- `model_output`

Eso permitió registrar el modelo directamente desde Azure ML sin descarga manual.

Modelo registrado:

- `iris-rf-model:1`

## Problema encontrado con Managed Online Endpoint

Se intentó desplegar un `Managed Online Endpoint` sobre el workspace privado original y Azure devolvió este bloqueo:

- el workspace con `private link` y sin `managed network` bloqueaba el `Managed Online Endpoint`

La inspección del workspace mostró:

- `public_network_access: Disabled`
- `managed_network.isolation_mode: disabled`

Además, la documentación de Microsoft separa claramente dos modelos:

- `custom virtual network isolation`
- `managed virtual network isolation`

Hallazgo clave:

- `Managed Online Endpoints` requieren el modelo de `Managed Virtual Network`
- el patrón previo, con workspace privado y compute en subnet custom del spoke, servía para training pero no para ese tipo de serving

También se comprobó en tiempo de ejecución que, una vez activado `Managed Virtual Network`, Azure rechaza explícitamente crear `AmlCompute` en una custom subnet:

- error:
  - `Unsupported operation: Attempting to create AmlCompute compute in custom vnet ... when the workspace is configured with a Managed Virtual Network`

## Decisión arquitectónica tomada

Se decidió priorizar en `staging` la validación de un único workspace capaz de soportar:

- training
- registro de modelo
- serving con `Managed Online Endpoint`

Para ello se aceptó este cambio de modelo:

- pasar el workspace a `Managed Virtual Network`
- abandonar el patrón anterior de `AmlCompute` en la subnet `snet-mlops-aml-compute` para este workspace

Trade-off explícito:

- el compute ya no vive en la VNet del spoke
- Azure lo crea en la red gestionada del workspace
- por tanto deja de aplicarle el hardening anterior basado en subnet custom

## Cambio operativo realizado

Se ejecutó este flujo:

1. borrado del endpoint fallido `iris-pkl-stg`
2. borrado del compute `cpu-cluster-stg`
3. actualización del workspace a:
   - `managed_network = AllowInternetOutbound`
4. provisión de la managed network del workspace
5. verificación de:
   - `managed_network.status = Active`
   - outbound rules requeridas en `Active`

## Cambio de código realizado

En `mlops-platform` se dejó el código alineado con la nueva decisión:

- `aml_workspace` ahora declara `managed_network.isolation_mode`
- staging queda configurado con:
  - `managed_network_isolation_mode = "AllowInternetOutbound"`

Además, el módulo `aml-compute-cluster` se adaptó para soportar ambos modelos:

- si el workspace está en `Disabled`:
  - usa la subnet custom del spoke
  - `enableNodePublicIp = false`
  - `remoteLoginPortPublicAccess = Disabled`
- si el workspace no está en `Disabled`:
  - no envía subnet custom
  - permite el comportamiento exigido por Azure para managed network

También se alinearon:

- `terraform.tfvars`
- `config/staging.env`
- `config/staging.env.example`
- `render-workload-config.sh`

## Compute recreado en Managed Virtual Network

Se recreó manualmente el compute en el workspace ya migrado:

- `cpu-cluster-stg`
- tipo: `AmlCompute`
- size: `Standard_DS2_v2`
- `min_instances = 0`
- `max_instances = 1`
- identidad:
  - `UserAssigned`
  - `id-mlops-stg-compute-weu-01`

Estado observado:

- `network_settings = {}`
- `enable_node_public_ip = true`
- `ssh_public_access_enabled = true`

Esto confirma que Azure ya no lo está creando en la subnet custom, sino bajo el patrón de red gestionada del workspace.

## Revalidación de training en el nuevo modelo

Se relanzó el smoke test de training con el compute recreado.

Job validado:

- `plucky_island_zrdw0yfzg1`

Resultado:

- `Completed`

Conclusión:

- el cambio a `Managed Virtual Network` no rompe training
- pero sí cambia el patrón de red del compute

## Validación de Managed Online Endpoint

Se creó el endpoint:

- `iris-pkl-stg`

Se desplegó el modelo registrado:

- deployment: `blue`
- modelo: `iris-rf-model:1`

Problemas encontrados durante el serving:

1. bloqueo inicial por cuota con:
   - `Standard_DS3_v2`
2. cambio a:
   - `Standard_E2s_v3`
3. fallo posterior del contenedor por faltar:
   - `azureml-inference-server-http`

Corrección:

- añadir `azureml-inference-server-http` al environment del deployment

Resultado final:

- deployment `blue`: `Succeeded`
- tráfico:
  - `blue = 100`
- invocación correcta del endpoint con respuesta válida

Respuesta validada:

```json
{"result":[0,1,2],"probabilities":[[1.0,0.0,0.0],[0.0,1.0,0.0],[0.0,0.0,1.0]]}
```

## Estado final validado

Queda validado extremo a extremo en `staging`:

- workspace en `Managed Virtual Network`
- training sobre `AmlCompute`
- registro de modelo
- `Managed Online Endpoint`
- inferencia real satisfactoria
- identidad del endpoint:
  - `user_assigned`
  - `id-mlops-stg-endpoint-weu-01`
- endpoint con:
  - `public_network_access = disabled`

También queda validado que el flujo sigue funcionando tras endurecer el endpoint:

- `az ml online-endpoint invoke` sigue respondiendo correctamente
- `curl` directo al `scoring_uri` con key también respondió correctamente en la validación previa

Hallazgo adicional importante:

- la identidad del endpoint es inmutable tras la creación
- intentar pasar de `system_assigned` a `user_assigned` con `update` no cambió el recurso
- la corrección válida fue:
  1. borrar `iris-pkl-stg`
  2. recrearlo con `UserAssigned Identity`
  3. recrear el deployment `blue`
  4. volver a validar inferencia

Otro cierre importante de la sesión:

- `terraform apply` dejó convergido el estado del compute con el nuevo patrón de `Managed Virtual Network`
- el último `terraform plan` quedó limpio:
  - `No changes. Your infrastructure matches the configuration.`

## Backlog priorizado

### Prioridad 1

- completar OIDC entre GitHub y Azure para evitar credenciales estáticas en workflows
- cerrar la puesta a punto del self-hosted GitHub runner
- validar el flujo completo desde GitHub Actions hacia Azure para:
  - `terraform plan/apply`
  - training en Azure ML
  - registro de modelo
  - deployment del endpoint
- definir permisos mínimos reales para:
  - runner
  - workflows federados
- revisar y reducir el `Owner` temporal del principal OIDC sobre `rg-mlops-workload-stg-weu-01` cuando quede definido:
  - repo GitHub definitivo
  - pipelines reales
  - separación de principals por función
- rotar la `primaryKey` del endpoint, porque quedó expuesta durante la validación manual

### Prioridad 2

- inspeccionar `managed_network` y `outbound_rules` del workspace antes de tocar `egress`
- decidir si conviene pasar de:
  - `AllowInternetOutbound`
  a:
  - `AllowOnlyApprovedOutbound`
- analizar ese endurecimiento pensando en el patrón MLOps y no en un modelo concreto, porque en futuras iteraciones podrán cambiar:
  - modelo
  - environment
  - dependencias de serving
- revisar también `egress_public_network_access` del deployment `blue`

### Prioridad 3

- ampliar Azure Policy más allá de la auditoría básica de ubicación
- decidir qué políticas quieres realmente:
  - regiones permitidas
  - tags obligatorios
  - diagnósticos obligatorios
  - restricciones de exposición pública
- añadir `diagnostic settings` a recursos clave para observabilidad en Azure Monitor / Log Analytics:
  - AML Workspace
  - Storage Account
  - Key Vault
  - ACR
  - Private Endpoints
  - runner VM si aplica
- definir alertas mínimas operativas:
  - fallos de deployment
  - errores de inferencia
  - salud del endpoint
  - consumo o cuota

### Prioridad 4

- decidir si `staging` seguirá siendo el workspace único para training y serving o si conviene separar workspaces
- documentar si se mantiene o no la subnet `snet-mlops-aml-compute` como parte activa del diseño de `staging`
- revisar si conviene automatizar más pasos CLI que hoy se hicieron manualmente
- preparar el patrón de promoción MLOps siguiente:
  - blue/green
  - canary
  - promoción de modelos entre entornos

## Punto de continuación recomendado

La siguiente sesión debería empezar por `Prioridad 1`:

1. revisar el estado actual del runner self-hosted
2. diseñar y crear la federación OIDC para GitHub Actions
3. dejar un primer workflow mínimo que valide login federado y acceso a Azure

Una vez cerrado eso, el siguiente bloque natural sería `Prioridad 2`:

1. inspeccionar `managed_network` del workspace
2. inventariar dependencias outbound del patrón de serving
3. decidir si se puede endurecer `egress` sin romper futuros despliegues
