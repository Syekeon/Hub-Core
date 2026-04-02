# MLOps Platform

Documento técnico del repositorio `mlops-platform-repo`.

Su responsabilidad final en `delivery-tfm` es crear el spoke de MLOps y el workload privado completo, reutilizando solo las piezas compartidas del hub.

Los valores que aparecen en ejemplos, nombres, credenciales y rutas deben entenderse como referencia del entorno validado. Cada despliegue puede adaptarlos a la suscripción, región, naming e instancia que necesite.

## Qué despliega

Este repo crea:

- `rg-mlops-infra-*`
- spoke VNet
- subredes de AML compute, private endpoints y runner
- route table del spoke
- peering hub <-> spoke
- enlaces del spoke a las zonas DNS privadas del hub
- diagnostic setting de la spoke VNet
- `rg-mlops-workload-*`
- identidades administradas
- Storage
- Key Vault
- ACR
- AML Workspace
- Private Endpoints
- runner VM privada
- AML compute cluster
- RBAC
- policies del workload
- diagnostic settings del workload

## Dependencias que sí importa del hub

Antes de renderizar el workload, este repo importa solo:

- `hub_resource_group_name`
- `hub_vnet_id`
- `hub_vnet_name`
- `hub_firewall_private_ip`
- `shared_log_analytics_workspace_id`
- `shared_application_insights_id`
- IDs de `Private DNS Zones`

Ya no importa del hub:

- `spoke_vnet_id`
- subredes del spoke
- route tables del spoke

Porque ahora ese bloque de red lo crea el propio `mlops-platform-repo`.

## Decisiones de diseño

- el spoke del workload se mueve a este repo para desacoplar el hub de la aplicación
- el hub sigue aportando observabilidad compartida, DNS privado y conectividad central
- el workload se mantiene en modo privado
- los `Private Endpoints` siguen viviendo en la subnet dedicada del spoke
- la runner VM sigue viviendo en el spoke
- el AML workspace puede seguir usando `managed_network_isolation_mode` según el caso, pero el spoke sigue siendo necesario para conectividad privada, runner, peerings y endpoints
- las policy assignments usan IDs deterministas de policy definition para evitar acoplamiento frágil al mapa parcial de outputs del módulo
- se decidió reutilizar la observabilidad centralizada del hub en lugar de crear un `Log Analytics Workspace` y un `Application Insights` locales al workload
- se decidió mantener identidades administradas separadas por función:
  - `runner`
  - `compute`
  - `endpoint`
- se decidió aplicar RBAC mínimo por rol y por recurso, en lugar de usar una identidad única con permisos excesivos sobre todo el workload
- se decidió desplegar una VM runner privada con tooling base ya instalado para dejar preparado el futuro uso como self-hosted runner
- se decidió separar el problema del runner de GitHub del problema de federación OIDC:
  - OIDC queda preparado en Terraform
  - el registro persistente del runner se deja como pendiente explícito
- se decidió validar el bloque no solo con `terraform plan`, sino con pruebas funcionales reales:
  - training
  - registro de modelo
  - serving
  - invoke
- se decidió usar `Standard_DS2_v2` para el smoke test de serving en esta suscripción porque `Standard_E2s_v3` no tenía cuota disponible
- se mantuvo la estrategia de un único config `staging` en la copia `delivery-tfm` para reducir complejidad operativa al entregar el paquete

## Caso operativo de este paquete

Esta copia está simplificada para un único flujo:

- `config/staging.env`
- `infrastructure/backend/backend-staging.hcl`
- `infrastructure/envs/staging/terraform.tfvars`

Los scripts siguen siendo interactivos, pero el paquete ya no mantiene varias configuraciones paralelas.

## Estado validado

Lo que ya quedó validado de forma real en `francecentral` es:

- fase privada aplicada correctamente
- acceso público deshabilitado en Storage, Key Vault, ACR y AML Workspace
- RBAC base aplicado
- runner VM privada desplegada
- AML Compute Cluster validado
- acceso a AML Studio desde la VPN
- smoke test de training completado
- registro de modelo completado
- Managed Online Endpoint validado
- invocación correcta del endpoint

## Recursos principales

### Infraestructura de spoke

- `rg-mlops-infra-<env>-<region>-<instance>`
- `vnet-mlops-<env>-<region>-<instance>`
- `snet-mlops-aml-compute`
- `snet-mlops-private-endpoints`
- `snet-mlops-devops-runner`
- `udr-mlops-<env>-<region>-<instance>`
- peering desde spoke a hub
- peering desde hub a spoke
- enlaces del spoke a:
  - `privatelink.api.azureml.ms`
  - `privatelink.notebooks.azure.net`
  - `privatelink.blob.core.windows.net`
  - `privatelink.file.core.windows.net`
  - `privatelink.dfs.core.windows.net`
  - `privatelink.vaultcore.azure.net`
  - `privatelink.azurecr.io`

### Workload

- `rg-mlops-workload-<env>-<region>-<instance>`
- Storage principal
- Key Vault
- ACR Premium
- AML Workspace
- AML compute cluster
- runner VM privada
- Private Endpoints de Storage, Key Vault, ACR y AML Workspace
- identities `runner`, `compute` y `endpoint`

## Detalle de lo construido

### Resource groups

- `rg-mlops-infra-<env>-<region>-<instance>`
  - agrupa la spoke VNet, subredes, UDR, peering y diagnóstico de red del workload
- `rg-mlops-workload-<env>-<region>-<instance>`
  - agrupa todos los recursos privados del workload MLOps
  - recibe policies de tags y policies de auditoría específicas del workload

### Identidades administradas

- `id-mlops-stg-runner-<region>-<instance>`
  - identidad de la VM runner
- `id-mlops-stg-compute-<region>-<instance>`
  - identidad del AML Compute Cluster
- `id-mlops-stg-endpoint-<region>-<instance>`
  - identidad del Managed Online Endpoint

Estas identidades permiten separar permisos por responsabilidad operativa.

### Storage

- `stmlopsstg<region><instance>`
  - cuenta de Storage principal del workload
  - usada por AML para artefactos y datos asociados al workspace
  - con acceso público deshabilitado

Private Endpoints asociados:

- `pep-storage-blob`
- `pep-storage-file`

### Key Vault

- `kv-mlops-stg-<region>-<instance>`
  - Key Vault principal del workload
  - con acceso público deshabilitado
  - con `soft-delete`
  - con `purge protection`
  - con autorización RBAC habilitada

Private Endpoint asociado:

- `pep-key-vault`

### Azure Container Registry

- `acrmlopsstg<region><instance>`
  - ACR Premium
  - con acceso público deshabilitado
  - preparado para consumo por AML y por el endpoint gestionado

Private Endpoint asociado:

- `pep-acr-registry`

### Azure Machine Learning

- `mlw-mlops-stg-<region>-<instance>`
  - AML Workspace principal del workload
  - con acceso público deshabilitado
  - integrado con:
    - Storage del workload
    - Key Vault del workload
    - ACR del workload
    - `Application Insights` compartido
  - con `Managed Virtual Network`

Private Endpoint asociado:

- `pep-aml-workspace`

### Compute de AML

- `cpu-cluster-stg`
  - AML Compute Cluster validado
  - creado mediante template deployment
  - con identidad administrada específica `compute`

### Runner

- `vm-mlops-stg-runner-<region>-<instance>`
  - VM privada del runner
  - desplegada en `snet-mlops-devops-runner`
  - con tooling base instalado:
    - `docker`
    - `azure-cli`
    - `terraform`
    - extensión `az ml`
    - herramientas auxiliares de shell

### Credenciales operativas

- usuario de la runner VM: `azureuser`
- password validada para reprovisión: `RunnerVm2026!`

## Policies y RBAC

El bloque crea:

- custom policy definitions del baseline
- policy assignments del workload
- policies de tags obligatorios para infra y workload
- RBAC mínimo para runner, compute, endpoint y workspace

Las assignments del workload se resuelven por nombre conocido de policy definition, no por un mapa dinámico frágil.

### RBAC base

Assignments validados:

- `runner`
  - `AcrPush`
  - `Key Vault Secrets Officer`
  - `Storage Blob Data Contributor`
  - `Contributor` sobre el RG del workload
- `compute`
  - `Key Vault Secrets User`
  - `Storage Blob Data Contributor`
- `endpoint`
  - `AcrPull`
  - `Key Vault Secrets User`
  - `Storage Blob Data Reader`
- `workspace`
  - `AcrPush`
  - `Key Vault Secrets Officer`

### Diagnóstico

Diagnostic settings del workload conectados a la observabilidad compartida:

- `diag-acr-to-law`
- `diag-keyvault-to-law`
- `diag-storage-to-law`
- `diag-amlworkspace-to-law`
- `diag-spoke-vnet-to-law`

## Scripts

### `import-hub-core-outputs.sh`

Lee `terraform output` del hub y rellena `config/staging.env` con:

- IDs del hub
- `hub_resource_group_name`
- `hub_vnet_id`
- `hub_vnet_name`
- `hub_firewall_private_ip`
- IDs de observabilidad compartida
- IDs de zonas DNS privadas

### `render-workload-config.sh`

Genera:

- `config/staging.env`
- `infrastructure/envs/staging/terraform.tfvars`
- `infrastructure/backend/backend-staging.hcl`

El script:

- deriva automáticamente nombres del backend por región e instancia
- deriva automáticamente nombres de RG, VNet, subredes e identidades
- escribe los CIDR y nombres del spoke local
- ya no espera subnet IDs importados desde el hub

#### Valores que solicita

##### Valores que normalmente debes adaptar

- `SUBSCRIPTION_ID`
  - usar la suscripción real donde se desplegará el workload
- `LOCATION`
  - valor de referencia validado: `francecentral`
- `LOCATION_SHORT`
  - valor de referencia validado: `frc`
- `INSTANCE`
  - usar el sufijo que corresponda al despliegue, por ejemplo `03`
- `RUNNER_ADMIN_PASSWORD`
  - consultar la sección `Credenciales operativas` de este README
- `GITHUB_OWNER`
  - dejar vacío si OIDC no se cierra aún
- `GITHUB_REPOSITORY`
  - dejar vacío si OIDC no se cierra aún

##### Valores que normalmente conviene mantener

- `WORKLOAD=mlops`
- `ENVIRONMENT=staging`
- `ENVIRONMENT_SHORT=stg`
- `ENABLE_PRIVATE_NETWORKING=true`
- `MANAGED_NETWORK_ISOLATION_MODE=AllowInternetOutbound`
- `TFSTATE_CONTAINER=tfstate`
- `TFSTATE_KEY=mlops-platform-staging.tfstate`
- `SPOKE_VNET_CIDR=10.1.0.0/22`
- `SPOKE_AML_COMPUTE_SUBNET_NAME=snet-mlops-aml-compute`
- `SPOKE_AML_COMPUTE_SUBNET_CIDR=10.1.0.0/24`
- `SPOKE_PRIVATE_ENDPOINTS_SUBNET_NAME=snet-mlops-private-endpoints`
- `SPOKE_PRIVATE_ENDPOINTS_SUBNET_CIDR=10.1.1.0/26`
- `SPOKE_DEVOPS_RUNNER_SUBNET_NAME=snet-mlops-devops-runner`
- `SPOKE_DEVOPS_RUNNER_SUBNET_CIDR=10.1.1.64/27`
- `RUNNER_ADMIN_USERNAME=azureuser`
- `RUNNER_VM_SIZE=Standard_D2s_v3`
- `AML_COMPUTE_NAME=cpu-cluster-stg`
- `AML_COMPUTE_VM_SIZE=Standard_DS2_v2`
- `AML_COMPUTE_MIN_INSTANCES=0`
- `AML_COMPUTE_MAX_INSTANCES=1`
- `GITHUB_MAIN_BRANCH=main`
- `GITHUB_OIDC_ROLE_DEFINITION_NAME=Owner`
- `TAG_OWNER=tfm`
- `TAG_COST_CENTER=master`

##### Valores que deben venir ya precargados desde el hub

Estos valores los rellena `import-hub-core-outputs.sh` y conviene revisarlos, no reescribirlos manualmente salvo incidencia:

- `HUB_RESOURCE_GROUP_NAME`
- `HUB_VNET_ID`
- `HUB_VNET_NAME`
- `HUB_FIREWALL_PRIVATE_IP`
- `SHARED_LOG_ANALYTICS_WORKSPACE_ID`
- `SHARED_APPLICATION_INSIGHTS_ID`
- `PRIVATE_DNS_ZONE_ID_API_AZUREML_MS`
- `PRIVATE_DNS_ZONE_ID_NOTEBOOKS_AZURE_NET`
- `PRIVATE_DNS_ZONE_ID_BLOB_CORE_WINDOWS_NET`
- `PRIVATE_DNS_ZONE_ID_FILE_CORE_WINDOWS_NET`
- `PRIVATE_DNS_ZONE_ID_DFS_CORE_WINDOWS_NET`
- `PRIVATE_DNS_ZONE_ID_VAULTCORE_AZURE_NET`
- `PRIVATE_DNS_ZONE_ID_AZURECR_IO`

##### Valores derivados que el script propone automáticamente

Si se usa `francecentral` con `INSTANCE=03`, el script propondrá valores como estos:

- `TFSTATE_RESOURCE_GROUP=rg-tfstate-platform-stg-frc-03`
- `TFSTATE_STORAGE_ACCOUNT=sttfplatformstgfrc03`
- `RG_INFRA_NAME=rg-mlops-infra-stg-frc-03`
- `RG_WORKLOAD_NAME=rg-mlops-workload-stg-frc-03`
- `SPOKE_VNET_NAME=vnet-mlops-stg-frc-03`
- `ENDPOINT_IDENTITY_NAME=id-mlops-stg-endpoint-frc-03`
- `RUNNER_IDENTITY_NAME=id-mlops-stg-runner-frc-03`
- `COMPUTE_IDENTITY_NAME=id-mlops-stg-compute-frc-03`

Estos nombres pueden adaptarse, pero conviene mantener el patrón si se quiere seguir la trazabilidad del entorno validado.

## Dependencias de red

Este repo no reutiliza ya el spoke desde el hub. Lo crea localmente en este propio bloque, pero sí requiere que `hub-core-repo` haya desplegado antes:

- `rg-hub`
- `hub-vnet`
- `Private DNS Zones` del hub
- `Log Analytics Workspace` compartido
- `Application Insights` compartido
- OPNsense operativo y accesible

Importante:

- la subnet `snet-mlops-aml-compute` se mantiene como parte del spoke, pero el estado validado actual usa `Managed Virtual Network` en el workspace
- por tanto el `AmlCompute` no se crea dentro de una subnet custom del spoke

Además, para validar acceso desde clientes OpenVPN conectados al hub, OPNsense debe tener:

- ruta estática a la red de clientes VPN según el backup restaurado
- `Unbound` con forwarding activado
- `Query Forwarding` para las zonas `privatelink...` hacia `168.63.129.16`
- regla de `LAN/trust` que permita el spoke MLOps:
  - origen `10.1.0.0/22`
  - destino `any`
- regla de `Outbound NAT` hacia `WAN` para el spoke MLOps:
  - origen `10.1.0.0/22`
  - traducción `WAN address`

Importante:

- el `Azure ML Workspace` usa un único `Private Endpoint` con subrecurso `amlworkspace`
- a ese mismo endpoint se asocian tanto `privatelink.api.azureml.ms` como `privatelink.notebooks.azure.net`
- no se crea un `Private Endpoint` separado con subrecurso `notebooks`

## Flujo de despliegue

Primero debe existir el hub:

```bash
cd /home/lfernanz/mlopsproject/repo-root/delivery-tfm/hub-core-repo/infrastructure/envs/shared
terraform apply
```

Después:

```bash
cd /home/lfernanz/mlopsproject/repo-root/delivery-tfm/mlops-platform-repo/scripts
./import-hub-core-outputs.sh
./render-workload-config.sh
```

```bash
cd /home/lfernanz/mlopsproject/repo-root/delivery-tfm/mlops-platform-repo/infrastructure/envs/staging
terraform init -reconfigure -backend-config=../../backend/backend-staging.hcl
terraform plan
terraform apply
```

### Restaurar OPNsense y validar VPN antes de AML

Antes de pasar a la validación funcional de AML, hay que dejar operativa la conectividad remota sobre el OPNsense desplegado en `hub-core-repo`.

Dato que debes traer de la fase anterior:

- `nva_public_ip`

Se obtiene así:

```bash
cd /home/lfernanz/mlopsproject/repo-root/delivery-tfm/hub-core-repo/infrastructure/envs/shared
terraform output nva_public_ip
```

Acceso inicial:

- URL: `https://<nva_public_ip>`
- credenciales iniciales: `root / opnsense`

Backup a restaurar:

- `hub-core-repo/docs/config-OPNsense.staging-validated-20260330.xml`

Tras el restore:

- acceso OPNsense: `root / Passw0rd.2018`
- usuario VPN: `vpnuser1 / Passw0rd.2018`

Ajuste obligatorio:

- reexportar el cliente OpenVPN con `Host Name Resolution = <nva_public_ip>`

Punto ya validado:

- reutilizando los mismos CIDRs, no hizo falta cambiar IPs internas ni rutas del backup

Checklist de apoyo:

- `hub-core-repo/docs/opnsense-reuse-checklist.md`

Resultado esperado de esta fase:

- VPN operativa
- resolución DNS privada desde la VPN
- acceso a AML Studio desde la VPN

## Estado actual de CI/CD

El estado actual dejado preparado es este:

- existe una VM privada de runner:
  - `vm-mlops-stg-runner-<region>-<instance>`
- el bootstrap de la VM instala:
  - `docker`
  - `azure-cli`
  - `terraform`
  - extensión `az ml`
  - `git`, `jq`, `curl`, `unzip`
- todavía no queda resuelto de forma automática en Terraform el registro persistente del runner en GitHub
- sí queda añadido el soporte base para OIDC con GitHub hacia Azure

Importante:

- el runner y OIDC se han separado a propósito
- primero se deja reproducible el login federado con Azure
- después se cerrará el registro operativo del self-hosted runner en GitHub

## OIDC con GitHub

El repo soporta crear de forma opcional una federación OIDC básica para GitHub Actions.

Variables nuevas en `config/staging.env`:

- `GITHUB_OWNER`
- `GITHUB_REPOSITORY`
- `GITHUB_MAIN_BRANCH`
- `GITHUB_OIDC_ROLE_DEFINITION_NAME`

Qué significan:

- `GITHUB_OWNER`
  - usuario u organización de GitHub que contendrá el repo real de automatización
- `GITHUB_REPOSITORY`
  - repo exacto que ejecutará los workflows contra Azure
- `GITHUB_MAIN_BRANCH`
  - rama concreta autorizada por la `federated credential`
- `GITHUB_OIDC_ROLE_DEFINITION_NAME`
  - rol Azure que recibirá el principal OIDC en el scope del RG del workload

Comportamiento:

- si `GITHUB_OWNER` y `GITHUB_REPOSITORY` están vacíos:
  - no se crea nada de OIDC
- si se rellenan:
  - Terraform crea:
    - una `App Registration`
    - un `Service Principal`
    - una `federated credential` para el branch principal
  - y asigna el rol configurado en el scope del RG del workload

Workflow de validación incluido:

- `mlops-platform-repo/.github/workflows/azure-federated-login.yml`

## Estado funcional esperado

Cuando este bloque converge, debe ser posible:

- resolver y alcanzar recursos privados a través de la conectividad validada
- acceder a AML Studio desde la VPN
- ejecutar training
- registrar modelos
- desplegar endpoints gestionados
- invocarlos correctamente

## Smoke tests manuales validados sin CI/CD

### Training

El smoke test validado consiste en:

- lanzar un job sencillo sobre `cpu-cluster-stg`
- esperar a `Completed`
- registrar el modelo resultante

Objetivo:

- demostrar que el workspace y el compute funcionan
- demostrar que el runner humano con CLI puede interactuar con AML

Ejemplo en validación:

Hazla desde una máquina con acceso por VPN y az ml instalado. Ejecutamos un ejemplo de job de `entrenamiento`:

- job.yml

Ese job es el entrenamiento:

- ejecuta job.yml
- corre python train.py
- usa azureml:cpu-cluster-stg
- deja el artefacto entrenado en outputs/model_output

Secuencia:

cd /home/lfernanz/mlopsproject/repo-root/delivery-tfm/mlops-platform-repo

az ml job create --file ml/jobs/train_iris/job.yml --resource-group rg-mlops-workload-stg-frc-03 --workspace-name mlw-mlops-stg-frc-03

Luego sigue el job:

az ml job list --resource-group rg-mlops-workload-stg-frc-03 --workspace-name mlw-mlops-stg-frc-03 --query "[?display_name=='train-iris-smoke-test'].[name,status]" -o table

Cuando aparezca Completed, se podría pasar a la fase de serving (se puede revisar el job desde ML Studio)

Ejemplo:

az ml job list --resource-group rg-mlops-workload-stg-frc-03 --workspace-name mlw-mlops-stg-frc-03 --query "[?display_name=='train-iris-smoke-test'].[name,status]" -o table
Class DeploymentTemplateOperations: This is an experimental class, and may change at any time. Please see https://aka.ms/azuremlexperimental for more information.
Displaying top 50 results from the list command.
Column1               Column2
--------------------  ---------
red_berry_zr9m2gbtc7  Completed

Ahora `registramos` el modelo entrenado:

az ml model create --name iris-rf-model --version 1 --path azureml://jobs/<JOB_NAME>/outputs/model_output --type custom_model --resource-group rg-mlops-workload-stg-frc-03 --workspace-name mlw-mlops-stg-frc-03

Ejemplo:
az ml model create --name iris-rf-model --version 1 --path azureml://jobs/red_berry_zr9m2gbtc7/outputs/model_output --type custom_model --resource-group rg-mlops-workload-stg-frc-03 --workspace-name mlw-mlops-stg-frc-03

### Deployment/Serving

El smoke test validado consiste en:

- crear un `online endpoint`
- desplegar una versión `blue`
- invocar el endpoint con un payload de ejemplo

Resultado validado:

- respuesta correcta con predicciones

Estado actual:

- job completado: red_berry_zr9m2gbtc7
- modelo registrado: iris-rf-model:1

Siguiente paso lógico: serving. Los assets ya están en:
- endpoint.yml
- deployment.yml
- request.json

Creamos el `endpoint`:

az ml online-endpoint create --file ml/endpoints/iris_pkl/endpoint.yml --set identity.user_assigned_identities[0].resource_id=/subscriptions/2d140556-0fed-401a-a125-8c737e5f49fd/resourceGroups/rg-mlops-workload-stg-frc-03/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-mlops-stg-endpoint-frc-03 --resource-group rg-mlops-workload-stg-frc-03 --workspace-name mlw-mlops-stg-frc-03

Desplegar `deployment` `blue`:

az ml online-deployment create --file ml/endpoints/iris_pkl/deployment.yml --resource-group rg-mlops-workload-stg-frc-03 --workspace-name mlw-mlops-stg-frc-03 --all-traffic

En Azure ML:
- el endpoint es la URL lógica estable, aquí iris-pkl-stg
- el deployment es la versión concreta que sirve el modelo detrás de ese endpoint. “desplegar blue” significa crear dentro de ese endpoint una implementación llamada blue y --all-traffic hace que el 100% del tráfico del endpoint vaya a ese deployment
- Es el patrón típico blue/green:
  - blue podría ser la versión actual
  - green una nueva versión
  - y luego cambias tráfico entre ambas

Invocar:

az ml online-endpoint invoke --name iris-pkl-stg --resource-group rg-mlops-workload-stg-frc-03 --workspace-name mlw-mlops-stg-frc-03 --request-file ml/endpoints/iris_pkl/request.json

Salida:
az ml online-endpoint invoke --name iris-pkl-stg --resource-group rg-mlops-workload-stg-frc-03 --workspace-name mlw-mlops-stg-frc-03 --request-file ml/endpoints/iris_pkl/request.json
Class DeploymentTemplateOperations: This is an experimental class, and may change at any time. Please see https://aka.ms/azuremlexperimental for more information.
"{\"result\": [0, 1, 2], \"probabilities\": [[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]]}"

El endpoint está usando un modelo entrenado con el dataset clásico de Iris para clasificar flores a partir de 4 medidas de entrada.

  Cada fila que envías en request.json representa una flor. El modelo responde con una clase por fila:

  - 0
  - 1
  - 2

  Esas clases corresponden a los tres tipos de Iris:

  - 0 = setosa
  - 1 = versicolor
  - 2 = virginica

  Por eso la salida:

  "result": [0, 1, 2]

  quiere decir que:

  - la primera muestra se ha clasificado como setosa
  - la segunda como versicolor
  - la tercera como virginica

  Y esto:

  "probabilities": [[1.0, 0.0, 0.0], ...]

  indica la confianza del modelo para cada clase. En tu prueba, ha dado 100% a una clase distinta en cada fila.

  Lo importante del smoke test es que no solo “predice algo”, sino que demuestra que todo el flujo funciona:

  - el modelo se entrenó
  - se registró en AML
  - se desplegó en un endpoint privado
  - y ese endpoint responde correctamente a una petición real

Importante:

- `Standard_E2s_v3` no tenía cuota en esta suscripción
- para la validación se usó `Standard_DS2_v2`
- Azure muestra una advertencia de tamaño recomendado, pero el smoke test funciona

Assets usados:

- `ml/jobs/train_iris/job.yml`
- `ml/endpoints/iris_pkl/endpoint.yml`
- `ml/endpoints/iris_pkl/deployment.yml`
- `ml/endpoints/iris_pkl/request.json`

## Teardown del smoke test

Para evitar consumo tras la validación manual:

```bash
az ml online-endpoint delete --name iris-pkl-stg --resource-group rg-mlops-workload-stg-frc-03 --workspace-name mlw-mlops-stg-frc-03 --yes
```

Opcionalmente, también se puede archivar el modelo de prueba:

```bash
az ml model archive --name iris-rf-model --version 1 --resource-group rg-mlops-workload-stg-frc-03 --workspace-name mlw-mlops-stg-frc-03
```

## Outputs útiles

Los valores operativos se leen desde `terraform output`.

Ejemplos:

```bash
cd /home/lfernanz/mlopsproject/repo-root/delivery-tfm/mlops-platform-repo/infrastructure/envs/staging
terraform output
terraform output aml_workspace_id
terraform output acr_id
terraform output key_vault_id
terraform output storage_account_id
terraform output spoke_vnet_id
```

Para sacar todos los datos en formato máquina:

```bash
terraform output -json
```

Si hiciera falta algún dato compartido del baseline:

```bash
cd /home/lfernanz/mlopsproject/repo-root/delivery-tfm/hub-core-repo/infrastructure/envs/shared
terraform output
```

### Valores mínimos típicos para pipelines

Para un pipeline de `training` y `serving`, normalmente bastan:

- `AZURE_SUBSCRIPTION_ID`
- `AZURE_RESOURCE_GROUP`
- `AZURE_ML_WORKSPACE`
- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`

El `subscription_id` de esta validación es:

- `2d140556-0fed-401a-a125-8c737e5f49fd`

Los demás deben salir del `terraform output` del workload y, en el caso de OIDC, de los outputs del bloque federado si está habilitado.

### Recomendación operativa

Para los compañeros que monten CI/CD:

1. desplegar o reutilizar la infraestructura con Terraform
2. leer los outputs con `terraform output` desde `delivery-tfm`
3. promover a variables/secrets de GitHub solo el mínimo necesario
4. evitar copiar IDs manualmente desde el portal

## Qué no queda resuelto todavía

Pendientes reales:

- registro automático del self-hosted runner en GitHub
- instalación persistente del runner como servicio
- definición final de labels y estrategia repo vs organización
- pipelines CI/CD finales de `training`
- pipelines CI/CD finales de `serving`

## Qué valida este bloque

Cuando este bloque está correctamente desplegado y validado, debe ser posible:

- acceder al workspace AML privado
- ejecutar training sobre el compute
- registrar modelos
- desplegar un managed online endpoint privado
- invocarlo con éxito desde el entorno validado
