# Diagrama textual con cajas anidadas — Arquitectura MLOps WEU

```text
┌───────────────────────┐
│  USUARIO / PORTÁTIL   │
│  Admin + AML Studio   │
└───────────┬───────────┘
            │
            │ acceso remoto
            v
┌───────────────────────┐
│        OPENVPN        │
│  túnel privado WEU    │
└───────────┬───────────┘
            │
            v
╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗
║                                                    AZURE · WEST EUROPE                                                           ║
║                                                                                                                                      ║
║  ┌──────────────────────────────────────────────────────────────────────────────┐                                                  ║
║  │ OBSERVABILIDAD CENTRALIZADA                                                 │                                                  ║
║  │ Azure Monitor                                                               │                                                  ║
║  │ ┌──────────────────────────────┐    ┌─────────────────────────────────────┐ │                                                  ║
║  │ │ Log Analytics                │    │ Application Insights                │ │                                                  ║
║  │ │ log-hub-weu-01               │    │ appi-hub-weu-01                     │ │                                                  ║
║  │ └──────────────────────────────┘    └─────────────────────────────────────┘ │                                                  ║
║  └──────────────────────────────────────────────────────────────────────────────┘                                                  ║
║                 ^                                   ^                                   ^                                            ║
║                 : logs/métricas                     : logs/métricas                     : logs/métricas                              ║
║                 :                                   :                                   :                                            ║
║                                                                                                                                      ║
║  ┌────────────────────────────────────────────────┐        VNet Peering        ┌────────────────────────────────────────────────┐  ║
║  │ HUB / CONECTIVIDAD COMPARTIDA                  │ <────────────────────────> │ SPOKE MLOps WEU                               │  ║
║  │ Resource Group: rg-hub                         │                            │ Resource Group: rg-mlops-infra-stg-weu-01     │  ║
║  │ VNet hub · 10.0.0.0/22                         │                            │ VNet: vnet-mlops-stg-weu-01 · 10.1.0.0/22     │  ║
║  │ subnet untrust · 10.0.0.64/26                 │                            │                                                │  ║
║  │ subnet trust · 10.0.0.128/26                  │                            │                                                │  ║
║  │                                                │                            │  ┌──────────────────────────────────────────┐  │  ║
║  │  ┌──────────────────────────────────────────┐  │                            │  │ SUBREDES                                 │  │  ║
║  │  │ OPNsense / NVA                           │  │                            │  │ · snet-mlops-aml-compute  10.1.0.0/24    │  │  ║
║  │  │ untrust subnet: 10.0.0.64/26             │  │                            │  │ · snet-mlops-private-endpoints 10.1.1.0/26│ │  ║
║  │  │ trust IP: 10.0.0.132                     │  │                            │  │ · snet-mlops-devops-runner 10.1.1.64/27  │  │  ║
║  │  │ OpenVPN                                  │  │                            │  └──────────────────────────────────────────┘  │  ║
║  │  │ Unbound DNS privado                      │  │                            │                                                │  ║
║  │  └──────────────────────────────────────────┘  │                            │                                                │  ║
║  │                                                │                            │  ┌──────────────────────────────────────────┐  │  ║
║  │  ┌──────────────────────────────────────────┐  │                            │  │ ROUTING                                  │  │  ║
║  │  │ Private DNS Zones centralizadas          │  │                            │  │ · UDR hacia NVA en subnet compute        │  │  ║
║  │  │ · privatelink.api.azureml.ms             │  │                            │  │ · UDR hacia NVA en subnet runner         │  │  ║
║  │  │ · privatelink.notebooks.azure.net        │  │                            │  │ · sin UDR en private-endpoints           │  │  ║
║  │  │ · privatelink.blob.core.windows.net      │  │                            │  └──────────────────────────────────────────┘  │  ║
║  │  │ · privatelink.dfs.core.windows.net       │  │                            │                                                │  ║
║  │  │ · privatelink.vaultcore.azure.net        │  │                            │  ┌──────────────────────────────────────────┐  │  ║
║  │  │ · privatelink.azurecr.io                 │  │                            │  │ WORKLOAD MLOps                           │  │  ║
║  │  └──────────────────────────────────────────┘  │                            │  │ Resource Group:                          │  │  ║
║  │                                                │                            │  │ rg-mlops-workload-stg-weu-01             │  │  ║
║  └────────────────────────────────────────────────┘                            │  │                                          │  │  ║
║                  ^                                                             │  │  ┌────────────────────────────────────┐  │  │  ║
║                  │ DNS privado a clientes VPN                                  │  │  │ AML Workspace                        │  │  │  ║
║                  │                                                             │  │  │ mlw-mlops-stg-weu-01                │  │  │  ║
║                  │                                                             │  │  │ identidad: SystemAssigned          │  │  │  ║
║                  │                                                             │  │  │ privado por PE único amlworkspace  │  │  │  ║
║                  │                                                             │  │  └────────────────────────────────────┘  │  │  ║
║                  │                                                             │  │                                          │  │  ║
║                  │                                                             │  │  ┌────────────────┐ ┌─────────────────┐ │  │  ║
║                  │                                                             │  │  │ Storage AML    │ │ Key Vault       │ │  │  ║
║                  │                                                             │  │  │ stmlopsstgweu01│ │ kv-mlops-stg... │ │  │  ║
║                  │                                                             │  │  └────────────────┘ └─────────────────┘ │  │  ║
║                  │                                                             │  │                                          │  │  ║
║                  │                                                             │  │  ┌────────────────┐ ┌─────────────────┐ │  │  ║
║                  │                                                             │  │  │ ACR Premium    │ │ Runner VM       │ │  │  ║
║                  │                                                             │  │  │ acrmlopsstg... │ │ vm-mlops-stg... │ │  │  ║
║                  │                                                             │  │  │                │ │ IP 10.1.1.68    │ │  │  ║
║                  │                                                             │  │  └────────────────┘ └─────────────────┘ │  │  ║
║                  │                                                             │  │                                          │  │  ║
║                  │                                                             │  │  ┌────────────────┐ ┌─────────────────┐ │  │  ║
║                  │                                                             │  │  │ AML Compute    │ │ Online Endpoint │ │  │  ║
║                  │                                                             │  │  │ cpu-cluster-stg│ │ iris-pkl-stg    │ │  │  ║
║                  │                                                             │  │  └────────────────┘ └─────────────────┘ │  │  ║
║                  │                                                             │  └──────────────────────────────────────────┘  │  ║
║                  │                                                             │                                                │  ║
║                  │                                                             │  ┌──────────────────────────────────────────┐  │  ║
║                  │                                                             │  │ PRIVATE ENDPOINTS                         │  │  ║
║                  │                                                             │  │ subnet: snet-mlops-private-endpoints     │  │  ║
║                  │                                                             │  │                                          │  │  ║
║                  │                                                             │  │  ┌──────────────┐ ┌──────────────┐      │  │  ║
║                  │                                                             │  │  │ pep-storage-  │ │ pep-key-     │      │  │  ║
║                  │                                                             │  │  │ blob          │ │ vault        │      │  │  ║
║                  │                                                             │  │  └──────────────┘ └──────────────┘      │  │  ║
║                  │                                                             │  │                                          │  │  ║
║                  │                                                             │  │  ┌──────────────┐ ┌──────────────────┐   │  │  ║
║                  │                                                             │  │  │ pep-acr-     │ │ pep-aml-         │   │  │  ║
║                  │                                                             │  │  │ registry     │ │ workspace        │   │  │  ║
║                  │                                                             │  │  └──────────────┘ │ único PE AML     │   │  │  ║
║                  │                                                             │  │                   │ groupId=amlworkspace│ │  ║
║                  │                                                             │  │                   │ + api + notebooks │ │  ║
║                  │                                                             │  │                   └──────────────────┘   │  │  ║
║                  │                                                             │  └──────────────────────────────────────────┘  │  ║
║                  │                                                             │                                                │  ║
║                  │                                                             │  ┌──────────────────────────────────────────┐  │  ║
║                  │                                                             │  │ IDENTIDADES GESTIONADAS                  │  │  ║
║                  │                                                             │  │ · id-mlops-stg-runner-weu-01            │  │  ║
║                  │                                                             │  │   principal_id: bf631222-...            │  │  ║
║                  │                                                             │  │ · id-mlops-stg-endpoint-weu-01          │  │  ║
║                  │                                                             │  │   principal_id: 779d5e17-...            │  │  ║
║                  │                                                             │  │ · id-mlops-stg-compute-weu-01           │  │  ║
║                  │                                                             │  │   principal_id: 38150f43-...            │  │  ║
║                  │                                                             │  └──────────────────────────────────────────┘  │  ║
║                  │                                                             └────────────────────────────────────────────────┘  ║
║                  │                                                                                                                   ║
║                  └──────────────► flujo 1: Usuario → OpenVPN → OPNsense → DNS privado → AML Studio privado                         ║
║                                                                                                                                    ║
║                                               ┌──────────────────────────────────────────────────────────────────────────────────┐   ║
║                                               │ RBAC BASE                                                                │   ║
║                                               │ · Workspace: Storage Blob Data Contributor · AcrPush · KV Secrets Officer │   ║
║                                               │ · Endpoint:  Storage Blob Data Reader     · AcrPull · KV Secrets User    │   ║
║                                               │ · Runner:    Contributor RG + Blob Data Contributor + AcrPush + KV SO    │   ║
║                                               └──────────────────────────────────────────────────────────────────────────────────┘   ║
║                                                                                                                                    ║
║                                               ┌──────────────────────────────────────────────────────────────────────────────────┐   ║
║                                               │ POLICIES / GOBIERNO                                                          │   ║
║                                               │ · Allowed locations: westeurope, francecentral                              │   ║
║                                               │ · Audit publicNetworkAccess: Storage, KV, ACR, AML                          │   ║
║                                               │ · Audit tags obligatorios                                                   │   ║
║                                               │ · Audit tamaños permitidos:                                                 │   ║
║                                               │   VM workload D2s_v3 · AML compute DS2_v2 · online E2s_v3 / DS2_v2         │   ║
║                                               └──────────────────────────────────────────────────────────────────────────────────┘   ║
║                                                                                                                                    ║
║     runner VM ───────────────► AML Workspace                                                                                       ║
║     AML Compute ────────────► ACR ───────────► Storage ───────────► Key Vault                                                      ║
║     Online Endpoint ────────► inferencia privada AML                                                                               ║
║     Hub + Spoke + Workload :::::::::::::::::::::::::::::::::::::::::► Log Analytics / App Insights                                 ║
║                                                                                                                                      ║
╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝


┌───────────────────────────────────────────────────────────────────────────────────────────────┐
│ BACKEND TERRAFORM                                                                             │
│ Resource Group: rg-mlops-tfstate-stg-weu-01                                                   │
│ Storage Account: stmlopstfstgstgweu01                                                         │
│ Container: tfstate                                                                            │
│ Infraestructura aparte del hub/spoke; almacena el remote state de Terraform                   │
└───────────────────────────────────────────────────────────────────────────────────────────────┘


Leyenda
- Flecha continua  ─────►  tráfico / datos / dependencias operativas
- Flecha punteada  :::::►  logs / métricas / telemetría
- PE AML único = Private Endpoint único del workspace AML con groupId amlworkspace
```
