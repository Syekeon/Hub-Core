# Hub Foundation

Documento técnico del repositorio `hub-core-repo`.

Su responsabilidad final en `delivery-tfm` es crear solo la base compartida de conectividad. El spoke del workload ya no se despliega aquí.

Los valores que aparecen en ejemplos, credenciales, rutas y naming deben entenderse como referencia del entorno validado. Cada despliegue puede y debe adaptarlos a la suscripción, región e instancia que corresponda.

## Qué despliega

Este bloque crea:

- `rg-hub`
- `hub-vnet`
- subredes de la NVA
- OPNsense / NVA
- `Log Analytics Workspace` compartido
- `Application Insights` compartido
- Private DNS Zones compartidas
- enlaces DNS del hub
- diagnostic settings del hub
- policy de ubicaciones permitidas
- policies de tags del RG del hub

## Qué ya no despliega

Este repo ya no crea:

- `rg-mlops-infra-*`
- spoke VNet
- subredes del workload
- peering hub <-> spoke
- route tables del spoke
- enlaces DNS del spoke

Todo eso pasa a `mlops-platform-repo`.

## Decisiones de diseño

- el hub queda como bloque reutilizable y compartido
- el nombre operativo del hub se mantiene estable en `rg-hub` y `hub-vnet` para representar la infraestructura central compartida
- se decidió centralizar `Log Analytics` y `Application Insights` en el hub para que el workload no crease observabilidad duplicada
- se decidió conservar el mismo direccionamiento privado del entorno validado original:
  - `10.0.0.0/22` para el hub
  - `10.1.0.0/22` para el spoke
  - `172.16.100.0/24` para clientes OpenVPN
- se decidió alojar también en el hub todas las `Private DNS Zones` y enlazarlas tanto al hub como al spoke
- los recursos del hub se etiquetan con `environment=shared`
- la copia `delivery-tfm` se simplifica a un único flujo `shared`
- se eligió OPNsense como NVA para cubrir en una sola pieza:
  - acceso remoto por VPN
  - forwarding DNS
  - salida a Internet controlada para recursos privados
  - se validó operativamente que, reutilizando los mismos CIDRs, el backup de OPNsense no requería cambios en IPs internas ni rutas; el único ajuste obligatorio al reprovisionar fue reexportar OpenVPN con la IP pública nueva en `Host Name Resolution`
- se mantuvo el patrón de `audit policies` y `required tags` como parte del baseline de gobierno del entorno
- se mantuvo la interacción por script para poder variar `Instance` cuando haga falta reprobar sin colisionar con nombres retenidos por Azure


## Recursos principales

### Resource groups

- `rg-hub`
- `rg-tfstate-platform-<env>-<region>-<instance>`

### Red del hub

- `hub-vnet`
- `snet-nva-untrust`
- `snet-nva-trust`
- Public IP de la NVA
- NICs de la NVA
- VM base de OPNsense

### Observabilidad

- `Log Analytics Workspace`
- `Application Insights`

### DNS privado

Zonas privadas compartidas:

- `privatelink.api.azureml.ms`
- `privatelink.notebooks.azure.net`
- `privatelink.blob.core.windows.net`
- `privatelink.file.core.windows.net`
- `privatelink.dfs.core.windows.net`
- `privatelink.vaultcore.azure.net`
- `privatelink.azurecr.io`

Cada zona se enlaza al `hub-vnet`. El spoke se enlaza más tarde desde `mlops-platform-repo`.

## Scripts

### `bootstrap-tf-backend.sh`

Prepara:

- Resource Group del backend
- Storage Account del backend
- contenedor `tfstate`

Los tags del backend del hub también quedan como compartidos.

### `render-infra-config.sh`

Genera:

- `config/shared.env`
- `infrastructure/envs/shared/terraform.tfvars`
- `infrastructure/backend/backend-shared.hcl`

El script ya no pide datos del spoke ni del workload. Mantiene un flujo más estable:

- `WORKLOAD=mlops`
- `ENVIRONMENT=staging`
- `ENVIRONMENT_SHORT=stg`
- `ALLOWED_LOCATIONS=westeurope,francecentral`

Además deriva automáticamente:

- `TFSTATE_RESOURCE_GROUP`
- `TFSTATE_STORAGE_ACCOUNT`
- `TFSTATE_KEY`

### Valores que solicita

El script pide o reutiliza estos valores:

- `SUBSCRIPTION_ID`
- `LOCATION`
- `LOCATION_SHORT`
- `INSTANCE`
- `HUB_NAME`
- `TFSTATE_RESOURCE_GROUP`
- `TFSTATE_STORAGE_ACCOUNT`
- `TFSTATE_CONTAINER`
- `TFSTATE_KEY`
- `RG_INFRA_NAME`
- `HUB_VNET_CIDR`
- `HUB_NVA_UNTRUST_SUBNET_CIDR`
- `HUB_NVA_TRUST_SUBNET_CIDR`
- `HUB_NVA_TRUST_PRIVATE_IP`
- `OPNSENSE_VM_SIZE`
- `OPNSENSE_ADMIN_USERNAME`
- `OPNSENSE_ADMIN_PASSWORD`
- `TAG_OWNER`
- `TAG_COST_CENTER`

Además fija internamente, como valores base del bloque compartido:

- `ALLOWED_LOCATIONS=westeurope,francecentral`
- `WORKLOAD=mlops`
- `ENVIRONMENT=staging`
- `ENVIRONMENT_SHORT=stg`

### Qué valores se pueden cambiar y cuáles no

Valores que normalmente sí se pueden adaptar por despliegue:

- `SUBSCRIPTION_ID`
- `LOCATION`
- `LOCATION_SHORT`
- `INSTANCE`
- `TFSTATE_RESOURCE_GROUP`
- `TFSTATE_STORAGE_ACCOUNT`
- `TFSTATE_CONTAINER`
- `TFSTATE_KEY`
- `OPNSENSE_ADMIN_USERNAME`
- `OPNSENSE_ADMIN_PASSWORD`
- `TAG_OWNER`
- `TAG_COST_CENTER`

Valores que conviene mantener salvo decisión consciente de rediseño:

- `HUB_NAME=hub`
- `RG_INFRA_NAME=rg-hub`
- `HUB_VNET_CIDR=10.0.0.0/22`
- `HUB_NVA_UNTRUST_SUBNET_CIDR=10.0.0.64/26`
- `HUB_NVA_TRUST_SUBNET_CIDR=10.0.0.128/26`
- `HUB_NVA_TRUST_PRIVATE_IP=10.0.0.132`
- `ALLOWED_LOCATIONS=westeurope,francecentral`
- `WORKLOAD=mlops`

Valores internos que hoy se mantienen por compatibilidad de naming:

- `ENVIRONMENT=staging`
- `ENVIRONMENT_SHORT=stg`

Aunque el bloque sea `shared`, esos dos valores siguen formando parte del naming derivado y del backend del entorno validado.

### Ejemplo de valores esperados

Ejemplo del entorno validado en `francecentral`:

```text
SUBSCRIPTION_ID=<tu-subscription-id>
LOCATION=francecentral
LOCATION_SHORT=frc
INSTANCE=02
HUB_NAME=hub
TFSTATE_RESOURCE_GROUP=rg-tfstate-platform-stg-frc-02
TFSTATE_STORAGE_ACCOUNT=sttfplatformstgfrc02
TFSTATE_CONTAINER=tfstate
TFSTATE_KEY=hub-core-shared.tfstate
RG_INFRA_NAME=rg-hub
HUB_VNET_CIDR=10.0.0.0/22
HUB_NVA_UNTRUST_SUBNET_CIDR=10.0.0.64/26
HUB_NVA_TRUST_SUBNET_CIDR=10.0.0.128/26
HUB_NVA_TRUST_PRIVATE_IP=10.0.0.132
OPNSENSE_VM_SIZE=Standard_D2s_v3
OPNSENSE_ADMIN_USERNAME=azureuser
OPNSENSE_ADMIN_PASSWORD=<consultar-documentacion-operativa>
TAG_OWNER=tfm
TAG_COST_CENTER=master
```

Interpretación:

- es un ejemplo esperado del entorno validado
- no es obligatorio reutilizar exactamente `frc` ni `02`
- cada compañero debe adaptar subscription, región, instancia, credenciales y naming si su despliegue cambia

### Dónde consultar la password

La password no se deja fijada en esta sección como valor obligatorio del script. Debe consultarse en la documentación operativa del propio paquete:

- credencial de la VM base del hub
- credenciales de OPNsense antes y después del restore

Referencias:

- sección `Credenciales operativas` de este mismo documento
- `hub-core-repo/docs/opnsense-reuse-checklist.md`

## Flujo de despliegue

```bash
cd /home/lfernanz/mlopsproject/repo-root/delivery-tfm/hub-core-repo/scripts
./render-infra-config.sh
./bootstrap-tf-backend.sh
```

```bash
cd /home/lfernanz/mlopsproject/repo-root/delivery-tfm/hub-core-repo/infrastructure/envs/shared
terraform init -reconfigure -backend-config=../../backend/backend-shared.hcl
terraform plan
terraform apply
```

## Outputs que consume el workload

Este repo publica para `mlops-platform-repo`:

- `hub_resource_group_name`
- `hub_vnet_id`
- `hub_vnet_name`
- `hub_firewall_private_ip`
- `log_analytics_workspace_id`
- `application_insights_id`
- IDs de las `Private DNS Zones`

## OPNsense

La restauración y validación operativa de OPNsense sigue siendo parte del flujo del hub.

### Credenciales operativas

- acceso a la VM base del hub: `azureuser / TfM-Hub-2026!`
- acceso a OPNsense antes del restore: `root / opnsense`
- acceso a OPNsense después del restore validado: `root / Passw0rd.2018`

Referencias útiles:

- `hub-core-repo/docs/config-OPNsense.staging-validated-20260330.xml`
- `hub-core-repo/docs/opnsense-reuse-checklist.md`
