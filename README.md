# Delivery TFM

Este paquete contiene la versión portable del entorno validado para `francecentral`.

Los valores visibles en ejemplos, nombres, usuarios, passwords y rutas de ejemplo deben entenderse como referencia del entorno validado. Cada compañero debe adaptarlos a su propia suscripción, región, instancia y naming antes de desplegar.

```text
delivery-tfm/
|-- README.md
|   Resumen general del paquete: orden de despliegue, scripts, identidades,
|   policies y pendientes.
|
|-- docs/
|   Documentación principal del paquete.
|   |-- README_hub-core.md
|   |   Guía técnica del bloque de red compartido: hub, OPNsense, DNS privado,
|   |   observabilidad y validación.
|   |
|   `-- README_mlopsplatform.md
|       Guía técnica del workload MLOps: spoke, AML, runner, RBAC, OIDC,
|       Private Endpoints, training, serving y CI/CD.
|
|-- hub-core-repo/
|   Copia portable del bloque de red y conectividad base.
|   |-- config/
|   |   Plantillas y variables del bloque hub compartido.
|   |
|   |-- docs/
|   |   Documentación auxiliar del bloque de red.
|   |   |-- config-OPNsense.example-hub.xml
|   |   |   Ejemplo base de configuración OPNsense.
|   |   |
|   |   |-- config-OPNsense.staging-validated-20260330.xml
|   |   |   Backup validado de OPNsense para restaurar VPN, DNS y reglas.
|   |   |
|   |   |-- opnsense-reuse-checklist.md
|   |   |   Checklist para restaurar y validar OPNsense.
|   |   |
|   |   `-- session-summary-*.md
|   |       Resúmenes históricos de sesiones y trazabilidad técnica.
|   |
|   |-- infrastructure/
|   |   Código Terraform del bloque de red compartido.
|   |   |-- backend/
|   |   |   Configuración del backend remoto Terraform del hub.
|   |   |
|   |   |-- envs/
|   |   |   `-- shared/
|   |   |       Entorno operativo donde se ejecutan terraform init/plan/apply.
|   |   |
|   |   `-- modules/
|   |       Módulos Terraform reutilizables del bloque de red.
|   |       |-- resource-groups/
|   |       |   Crea los Resource Groups base.
|   |       |
|   |       |-- hub-network/
|   |       |   Crea la VNet hub y subredes del NVA.
|   |       |
|   |       |-- nva-opnsense/
|   |       |   Despliega OPNsense, NICs, NSG y Public IP.
|   |       |
|   |       |-- private-dns/
|   |       |   Crea zonas DNS privadas y enlaces al hub.
|   |       |
|   |       |-- observability/
|   |       |   Crea Log Analytics y Application Insights compartidos.
|   |       |
|   |       |-- diagnostic-settings/
|   |       |   Aplica diagnostic settings a recursos de red.
|   |       |
|   |       |-- policy-audit/
|   |       |   Assignment de allowed locations a nivel suscripción.
|   |       |
|   |       `-- policy-require-tags/
|   |           Assignments de tags obligatorios por Resource Group.
|   |
|   `-- scripts/
|       Scripts operativos del bloque de red.
|       |-- bootstrap-tf-backend.sh
|       |   Prepara RG, Storage Account y contenedor tfstate del backend remoto.
|       |
|       `-- render-infra-config.sh
|           Genera shared.env, backend-shared.hcl y terraform.tfvars.
|
`-- mlops-platform-repo/
    Copia portable del bloque de workload MLOps.
    |-- config/
    |   Plantillas y variables del workload.
    |   `-- staging.env.example
    |       Plantilla base del entorno adaptada a francecentral/frc.
    |
    |-- infrastructure/
    |   Código Terraform del workload MLOps.
    |   |-- backend/
    |   |   Configuración del backend remoto Terraform del workload.
    |   |
    |   |-- envs/
    |   |   `-- staging/
    |   |       Entorno operativo donde se ejecutan terraform init/plan/apply.
    |   |
    |   `-- modules/
    |       Módulos Terraform reutilizables del workload.
    |       |-- resource-groups/
    |       |   Crea los Resource Groups de infra y workload.
    |       |
    |       |-- spoke-network/
    |       |   Crea la VNet spoke y subredes del workload.
    |       |
    |       |-- route-tables/
    |       |   Crea la UDR y sus asociaciones del spoke.
    |       |
    |       |-- storage-aml/
    |       |   Crea el Storage Account principal del workspace.
    |       |
    |       |-- key-vault/
    |       |   Crea el Key Vault del workload.
    |       |
    |       |-- acr/
    |       |   Crea el Azure Container Registry Premium.
    |       |
    |       |-- aml-workspace/
    |       |   Crea el Azure Machine Learning Workspace.
    |       |
    |       |-- aml-compute-cluster/
    |       |   Crea el AML Compute Cluster.
    |       |
    |       |-- runner-vm/
    |       |   Crea la NIC y la VM runner privada.
    |       |   `-- cloud-init.yaml.tftpl
    |       |       Bootstrap automático con docker, azure-cli, terraform,
    |       |       az ml y utilidades base.
    |       |
    |       |-- private-endpoints/
    |       |   Crea Private Endpoints de Storage, Key Vault, ACR y AML.
    |       |
    |       |-- identities/
    |       |   Crea managed identities de runner, compute y endpoint.
    |       |
    |       |-- rbac/
    |       |   Aplica role assignments necesarios.
    |       |
    |       |-- diagnostic-settings/
    |       |   Configura diagnósticos del workload hacia Log Analytics.
    |       |
    |       |-- policy-definitions/
    |       |   Crea las custom policy definitions del baseline.
    |       |
    |       |-- policy-rg-assignment/
    |       |   Asigna policies custom al RG del workload.
    |       |
    |       |-- policy-require-tags/
    |       |   Aplica las policies de tags obligatorios.
    |       |
    |       `-- github-oidc/
    |           Crea App Registration, Service Principal y Federated Credential
    |           para GitHub OIDC.
    |
    `-- scripts/
        Scripts operativos del workload.
        |-- import-hub-core-outputs.sh
        |   Importa outputs del hub: VNet, DNS privado,
        |   Log Analytics y App Insights.
        |
        `-- render-workload-config.sh
            Genera staging.env, backend-staging.hcl y terraform.tfvars
            del workload con datos de AML, runner, red, tags y OIDC.
```

## Punto de entrada

Empieza por estos dos documentos:

- `docs/README_hub-core.md`
- `docs/README_mlopsplatform.md`

Entre ambos cubren:

- el despliegue de `hub-core-repo`
- el despliegue de `mlops-platform-repo`
- la restauración y validación de OPNsense
- las pruebas manuales de training y serving
- lo que ya está automatizado
- lo que sigue pendiente

## Estructura

- `hub-core-repo`
- `mlops-platform-repo`
- `docs`

## Documentación técnica principal

- `docs/README_hub-core.md`
  - documentación técnica del bloque de red, conectividad, DNS privado y OPNsense
- `docs/README_mlopsplatform.md`
  - documentación técnica del bloque de workload, spoke, AML, runner, OIDC y assets de ML

## Alcance actual

Lo que queda validado en este paquete:

- despliegue Terraform de la base `hub-core`
- despliegue Terraform del spoke y del workload MLOps
- restauración de OPNsense y acceso por VPN
- acceso a AML Studio desde la VPN
- smoke test de training
- registro de modelo
- smoke test de serving

## Orden de ejecución de scripts y despliegues

### 1. Generar configuración del entorno del bloque hub

- **Repo:** `hub-core-repo`
- **Script / fichero:** `render-infra-config.sh`
- **Ruta:** `/home/lfernanz/mlopsproject/repo-root/delivery-tfm/hub-core-repo/scripts/render-infra-config.sh`
- **Qué hace:** pide o reutiliza valores del entorno y genera:
  - `config/shared.env`
  - `infrastructure/envs/shared/terraform.tfvars`
  - `infrastructure/backend/backend-shared.hcl`
- **Cuándo se usa:** antes de `terraform init / plan / apply` del bloque hub.

### 2. Preparar backend remoto de Terraform del bloque de red

- **Repo:** `hub-core-repo`
- **Script / fichero:** `bootstrap-tf-backend.sh`
- **Ruta:** `/home/lfernanz/mlopsproject/repo-root/delivery-tfm/hub-core-repo/scripts/bootstrap-tf-backend.sh`
- **Qué hace:** crea o prepara la infraestructura del backend remoto de Terraform del bloque hub, incluyendo Resource Group, Storage Account y contenedor `tfstate`.
- **Cuándo se usa:** después de generar `shared.env` y antes del primer `terraform init` del bloque de red.

### 3. Desplegar hub y conectividad base

- **Repo:** `hub-core-repo`
- **Script / fichero:** `terraform init / plan / apply`
- **Ruta:** `/home/lfernanz/mlopsproject/repo-root/delivery-tfm/hub-core-repo/infrastructure/envs/shared`
- **Qué hace:** inicializa backend y proveedores, y despliega hub, DNS privado, observabilidad, policies y OPNsense.
- **Cuándo se usa:** después de preparar backend y configuración.

### 4. Importar outputs compartidos del hub

- **Repo:** `mlops-platform-repo`
- **Script / fichero:** `import-hub-core-outputs.sh`
- **Ruta:** `/home/lfernanz/mlopsproject/repo-root/delivery-tfm/mlops-platform-repo/scripts/import-hub-core-outputs.sh`
- **Qué hace:** lee `terraform output` del bloque hub e importa en `config/staging.env` los IDs compartidos de:
  - hub resource group
  - hub VNet
  - firewall private IP
  - DNS privado
  - Log Analytics
  - Application Insights
- **Cuándo se usa:** después de desplegar `hub-core` y antes de renderizar el workload.

### 5. Generar configuración del workload

- **Repo:** `mlops-platform-repo`
- **Script / fichero:** `render-workload-config.sh`
- **Ruta:** `/home/lfernanz/mlopsproject/repo-root/delivery-tfm/mlops-platform-repo/scripts/render-workload-config.sh`
- **Qué hace:** pide o reutiliza valores del workload y genera:
  - `config/staging.env`
  - `infrastructure/envs/staging/terraform.tfvars`
  - `infrastructure/backend/backend-staging.hcl`
- **Cuándo se usa:** antes de `terraform init / plan / apply` del workload.

### 6. Desplegar plataforma MLOps

- **Repo:** `mlops-platform-repo`
- **Script / fichero:** `terraform init / plan / apply`
- **Ruta:** `/home/lfernanz/mlopsproject/repo-root/delivery-tfm/mlops-platform-repo/infrastructure/envs/staging`
- **Qué hace:** inicializa backend y proveedores, y despliega:
  - spoke de red del workload
  - peerings hub <-> spoke
  - DNS links del spoke
  - AML Workspace
  - Storage
  - Key Vault
  - ACR
  - runner
  - compute
  - identidades
  - RBAC
  - policies
  - Private Endpoints
- **Cuándo se usa:** después de importar outputs del hub y renderizar la configuración.

### 7. Bootstrap automático de la runner VM

- **Repo:** `mlops-platform-repo`
- **Script / fichero:** `cloud-init.yaml.tftpl`
- **Ruta:** `/home/lfernanz/mlopsproject/repo-root/delivery-tfm/mlops-platform-repo/infrastructure/modules/runner-vm/cloud-init.yaml.tftpl`
- **Qué hace:** se renderiza dentro del `terraform apply` de la runner VM, se inyecta como `custom_data` y ejecuta el bootstrap del runner con:
  - docker
  - azure-cli
  - terraform
  - `az ml`
  - git
  - jq
  - curl
  - unzip
- **Cuándo se usa:** automáticamente durante la creación de `vm-mlops-stg-runner-*`.

## Secuencia recomendada de despliegue

1. Ejecutar `hub-core-repo/scripts/render-infra-config.sh`.
2. Ejecutar `hub-core-repo/scripts/bootstrap-tf-backend.sh`.
3. Ejecutar `terraform init / plan / apply` en `hub-core-repo/infrastructure/envs/shared`.
4. Ejecutar `mlops-platform-repo/scripts/import-hub-core-outputs.sh`.
5. Ejecutar `mlops-platform-repo/scripts/render-workload-config.sh`.
6. Ejecutar `terraform init / plan / apply` en `mlops-platform-repo/infrastructure/envs/staging`.
7. Dejar que Terraform renderice y aplique automáticamente `cloud-init.yaml.tftpl` durante la creación de la runner VM.

## Notas importantes

- El bloque `hub-core` debe estar completamente desplegado antes de desplegar `mlops-platform`.
- El script `import-hub-core-outputs.sh` es el puente entre ambos repositorios y evita copiar IDs a mano.
- El backend remoto de Terraform se prepara por separado en cada repo.
- El fichero `cloud-init.yaml.tftpl` no se ejecuta manualmente: lo consume Terraform durante la creación de la VM runner.
- Los valores de ejemplo de `*.env.example`, `backend-*.hcl.example` y `terraform.tfvars.example` representan el estado esperado del entorno validado, pero no sustituyen la adaptación manual a cada despliegue.


## Matriz de identidades

| Identidad | Tipo | Asociada a | Propósito | RBAC |
|---|---|---|---|---|
| `SystemAssigned` del AML Workspace | Managed Identity | `mlw-mlops-stg-frc-02` | Permitir que el workspace opere sobre recursos asociados del workload | `Storage Blob Data Contributor`, `AcrPush`, `Key Vault Secrets Officer` |
| `id-mlops-stg-runner-frc-02` | User Assigned Managed Identity | `vm-mlops-stg-runner-frc-02` | Identidad de automatización para la runner VM, usada por CI/CD y operación del entorno | `Contributor` sobre el RG del workload, `Storage Blob Data Contributor`, `AcrPush`, `Key Vault Secrets Officer` |
| `id-mlops-stg-compute-frc-02` | User Assigned Managed Identity | `cpu-cluster-stg` | Identidad del AML Compute Cluster para training, acceso a datos y lectura de secretos | `Storage Blob Data Contributor`, `Key Vault Secrets User` |
| `id-mlops-stg-endpoint-frc-02` | User Assigned Managed Identity | `iris-pkl-stg` | Identidad del Managed Online Endpoint para serving privado y acceso a artefactos del modelo | `Storage Blob Data Reader`, `AcrPull`, `Key Vault Secrets User` |

## Matriz de Azure Policies

| Scope | Nombre | Tipo | Propósito |
|---|---|---|---|
| Suscripción | `audit-allowed-location` | Assignment | Auditar que los recursos solo se desplieguen en `westeurope` y `francecentral` |
| Suscripción | `audit-storage-public-access-disabled` | Custom Policy Definition | Auditar Storage Accounts con `publicNetworkAccess` habilitado |
| Suscripción | `audit-keyvault-public-access-disabled` | Custom Policy Definition | Auditar Key Vaults con `publicNetworkAccess` habilitado |
| Suscripción | `audit-acr-public-access-disabled` | Custom Policy Definition | Auditar ACR con `publicNetworkAccess` habilitado |
| Suscripción | `audit-aml-workspace-public-access-disabled` | Custom Policy Definition | Auditar AML Workspaces con `publicNetworkAccess` habilitado |
| Suscripción | `audit-allowed-vm-sizes` | Custom Policy Definition | Auditar VMs del workload fuera de los tamaños permitidos |
| Suscripción | `audit-allowed-aml-compute-sizes` | Custom Policy Definition | Auditar AML Compute fuera de los tamaños permitidos |
| Suscripción | `audit-allowed-aml-online-deployment-sizes` | Custom Policy Definition | Auditar online deployments fuera de los tamaños permitidos |
| RG | `audit-tag-owner` | Assignment | Auditar presencia del tag `owner` |
| RG | `audit-tag-project` | Assignment | Auditar presencia del tag `project` |
| RG | `audit-tag-cost-center` | Assignment | Auditar presencia del tag `cost_center` |
| RG | `audit-tag-environment` | Assignment | Auditar presencia del tag `environment` |
| RG workload | `audit-public-storage` | Assignment | Aplicar la policy custom de acceso público deshabilitado a Storage |
| RG workload | `audit-public-keyvault` | Assignment | Aplicar la policy custom de acceso público deshabilitado a Key Vault |
| RG workload | `audit-public-acr` | Assignment | Aplicar la policy custom de acceso público deshabilitado a ACR |
| RG workload | `audit-public-amlworkspace` | Assignment | Aplicar la policy custom de acceso público deshabilitado a AML Workspace |
| RG workload | `audit-size-vm` | Assignment | Aplicar la policy custom de tamaños permitidos a la VM del workload |
| RG workload | `audit-size-amlcompute` | Assignment | Aplicar la policy custom de tamaños permitidos a AML Compute |
| RG workload | `audit-size-onlinedeployment` | Assignment | Aplicar la policy custom de tamaños permitidos a online deployments |

## Lo que sigue pendiente

- Ha quedado activado el soft delete (7 dias) y el purge protection (true) en el KeyVault del workload. Como da problemas al recrearse el entorno, quedaría revisar también el backend storage como buena práctica.
- Las Azure Policy definidas están todas en modo Audit para no generar bloqueos.
- El runner como máquina de GitHub ha quedado creada. La VM `vm-mlops-stg-*` existe conceptualmente en el diseño final, está en red privada y tiene el tooling base instalado (`docker`, `azure-cli`, `terraform`, `az ml`, etc.). El script de instalación está en `mlops-platform-repo/infrastructure/modules/runner-vm/cloud-init.yaml.tftpl` y se llama durante el despliegue de la VM con Terraform. Lo que no está cerrado todavía es su registro operativo como self-hosted runner de GitHub. Quedaría automatizar:
  1. la instalación del agente oficial de GitHub Actions Runner
  2. el registro automático contra el repositorio u organización definitivos
  3. la ejecución como servicio gestionado
  4. la parametrización completa para reprovisión
  5. el uso del runner privado desde workflows que hagan login en Azure mediante OIDC
- Sobre OIDC:
  - ya existe la infraestructura base:
    - módulo Terraform para OIDC
    - App Registration
    - Service Principal
    - Federated Identity Credential
    - variables `GITHUB_OWNER`, `GITHUB_REPOSITORY`, `GITHUB_MAIN_BRANCH`, `GITHUB_OIDC_ROLE_DEFINITION_NAME`
    - outputs `github_oidc_application_client_id`, `github_oidc_tenant_id`, `github_oidc_branch_subject`
  - lo pendiente es cerrarlo operativamente:
    1. decidir owner, repository y branch definitivos
    2. regenerar configuración
    3. aplicar Terraform con esos valores reales
- Pipelines CI/CD finales de `training`. En `README_mlopsplatform.md`, en el bloque `Cómo sacar datos para CI/CD`, aparece el resumen para consumir los outputs de Terraform.
- Pipelines CI/CD finales de `serving`. En `README_mlopsplatform.md`, en el bloque `Cómo sacar datos para CI/CD`, aparece el resumen para consumir los outputs de Terraform.

## Problema encontrado con AML Compute en subnet propia

Durante el diseño inicial se intentó desplegar el `AML Compute Cluster` de training en una subnet propia del spoke, siguiendo un enfoque de red inyectada. Sin embargo, el `Azure Machine Learning Workspace` validado quedó configurado en modo `Managed Virtual Network`, y en ese modelo Microsoft no soportaba mantener el patrón anterior de `AmlCompute` en una subnet custom del spoke dentro del mismo workspace.

No se pudo mantener `cpu-cluster-stg` en `snet-mlops-aml-compute` porque existía una incompatibilidad entre estos dos objetivos dentro del mismo workspace:

- mantener el compute de training en una subnet privada propia del spoke
- mantener el workspace bajo el modelo de red administrada soportado por Azure

### Decisión adoptada

Se decidió mantener el `AML Workspace` en `Managed Virtual Network` y abandonar el despliegue del compute de training en una subnet custom del spoke.

El spoke se mantuvo para alojar:

- la conectividad privada del workload
- los `Private Endpoints`
- la `Runner VM`

El `AML Compute Cluster` pasó a quedar alineado con el modelo de red administrada del propio workspace.

Referencias:

- `Workspace Managed Virtual Network Isolation - Azure Machine Learning | Microsoft Learn`
  - https://learn.microsoft.com/en-us/azure/machine-learning/how-to-managed-network?view=azureml-api-2
- `Use managed compute in a managed virtual network - Azure Machine Learning | Microsoft Learn`
  - https://learn.microsoft.com/en-us/azure/machine-learning/how-to-managed-network-compute?view=azureml-api-2
