# OPNsense Reuse Checklist

Esta guía sirve para que otro compañero pueda importar una copia del OPNsense ya validado y reproducir rápidamente el entorno del TFM sin rehacer toda la configuración desde cero.

La idea es:

1. desplegar una nueva VM OPNsense con el mismo diseño hub-and-spoke
2. importar el backup XML
3. revisar los puntos que dependen de las NICs, IPs, DNS, VPN y Azure
4. validar conectividad privada extremo a extremo

## Alcance

Esta guía asume que el diseño objetivo sigue siendo el mismo:

- hub VNet: `10.0.0.0/22`
- subnet untrust: `10.0.0.64/26`
- subnet trust: `10.0.0.128/26`
- IP trust OPNsense: `10.0.0.132`
- red OpenVPN clientes: `172.16.100.0/24`
- spoke MLOps: `10.1.0.0/22`

Si se cambia alguno de esos CIDRs, habrá que adaptar los puntos indicados más abajo.

## 1. Importar la configuración

Ruta:

- `System > Configuration > Backups`

Acción:

- importar el XML del OPNsense ya validado
- aplicar la restauración
- reiniciar si es necesario

Credenciales operativas:

- antes del restore:
  - usuario: `root`
  - contraseña: `opnsense`
- después del restore:
  - usuario: `root`
  - contraseña: `Passw0rd.2018`

Objetivo:

- partir de una configuración funcional con OpenVPN, Unbound, rutas y reglas ya montadas

## 2. Revisar interfaces

Ruta:

- `Interfaces > Assignments`

Qué revisar:

- que las NICs de la nueva VM estén asignadas correctamente
- que `WAN`, `trust` y `untrust` correspondan a las interfaces reales de Azure

Cómo debe quedar:

- `WAN`: interfaz conectada a la red pública o externa
- `trust`: interfaz conectada a la subnet `10.0.0.128/26`
- `untrust`: interfaz conectada a la subnet `10.0.0.64/26`, si el diseño mantiene esa separación

Cómo validarlo:

- abrir cada interfaz y comprobar la IP asociada
- la interfaz `trust` debe quedar con `10.0.0.132/26` si se mantiene el mismo diseño

Problema típico:

- si las NICs cambian de orden al crear la VM, OPNsense puede importar bien pero quedar con las interfaces cruzadas

## 3. Revisar IPs de interfaces

Ruta:

- `Interfaces > WAN`
- `Interfaces > trust`
- `Interfaces > untrust`

Qué revisar:

- IP estática
- máscara
- gateway en WAN

Cómo debe quedar si se mantiene el diseño actual:

- hub CIDR: `10.0.0.0/22`
- subnet untrust: `10.0.0.64/26`
- subnet trust: `10.0.0.128/26`
- IP trust OPNsense: `10.0.0.132`

Qué adaptar si cambian la red:

- IP de `trust`
- gateway
- cualquier referencia posterior a `10.0.0.132`

## 4. Revisar la ruta estática de clientes VPN

Ruta:

- `System > Routes > Configuration`

Qué revisar:

- que exista la ruta de retorno para la red de clientes OpenVPN

Cómo debe quedar:

- destino: `172.16.100.0/24`
- gateway: `10.0.0.129`

Explicación:

- `172.16.100.0/24` es la red de clientes VPN
- `10.0.0.129` es la gateway Azure de la subnet trust `10.0.0.128/26`

Qué adaptar si cambian la red:

- si cambia la red del túnel OpenVPN, cambia el destino
- si cambia la subnet trust, la gateway puede dejar de ser `10.0.0.129`

## 5. Revisar el servidor OpenVPN

Ruta:

- `VPN > OpenVPN > Servers`

Qué revisar:

- modo del servidor
- red del túnel
- redes anunciadas
- DNS entregado a clientes
- advanced options

Cómo debe quedar:

- `Server Mode`: `Remote Access ( SSL/TLS + User Auth )`
- `Protocol`: `UDP`
- `Device Mode`: `tun`
- `IPv4 Tunnel Network`: `172.16.100.0/24`
- `IPv4 Local Network`: `10.0.0.0/22,10.1.0.0/22`
- `Topology`: `subnet`
- `DNS Server #1`: `10.0.0.132`

En `Advanced configuration` debe quedar:

```text
push "dhcp-option DNS 10.0.0.132"
push "register-dns"
```

Qué no dejar:

```text
block-outside-dns
```

Motivo:

- en la validación real, `block-outside-dns` hizo que `OpenVPN Connect` en Windows se quedara en `Trying to connect`

Qué adaptar si cambian la red:

- si cambia la IP trust, cambiar `10.0.0.132`
- si cambia el spoke CIDR, ajustar `IPv4 Local Network`
- si cambia la red OpenVPN, ajustar `172.16.100.0/24`

## 6. Revisar DNS del sistema en OPNsense

Ruta:

- `System > Settings > General`

Qué revisar:

- que OPNsense use el DNS especial de Azure

Cómo debe quedar:

- `DNS Server`: `168.63.129.16`
- sin DNS públicos tipo `8.8.8.8`
- desactivado el override de DNS por WAN

Motivo:

- `168.63.129.16` conoce las `Private DNS Zones` enlazadas al hub y al spoke

## 7. Revisar Unbound DNS

Ruta:

- `Services > Unbound DNS > General`

Qué revisar:

- que Unbound esté activo y reenviando consultas

Cómo debe quedar:

- `Enable Unbound`: activado
- `Enable Forwarding Mode`: activado
- `Network Interfaces`: `All`
- `Outgoing Network Interfaces`: `All`

## 8. Revisar Query Forwarding / Domain Overrides

Ruta:

- `Services > Unbound DNS > Query Forwarding`
- o `Services > Unbound DNS > Overrides`, según la vista disponible

Qué revisar:

- que existan todas las entradas necesarias para Azure Private Link y Azure ML Studio

Cómo debe quedar:

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

Qué adaptar si cambian de región:

- sustituir `westeurope` en `inference.westeurope.api.azureml.ms`

Problema típico:

- si faltan los forwarders públicos de AML, Studio puede seguir resolviendo por la cadena pública y mostrar `unauthorized network location`

## 8.b Reglas de firewall para el spoke MLOps

Ruta:

- `Firewall > Rules > LAN`

Qué revisar:

- que exista una regla explícita que permita tráfico desde el spoke MLOps hacia el firewall y hacia Internet

Cómo debe quedar para este entorno:

- regla `pass`
- interfaz: `LAN` o la interfaz que corresponda al `trust`
- protocolo: `any`
- origen: `10.1.0.0/22`
- destino: `any`
- descripción sugerida: `Allow spoke mlops to any`

Posición recomendada:

- por encima de reglas específicas del ejemplo como `WindowsVMSubnet`

Problema real detectado:

- sin esta regla, el runner del spoke no podía ni siquiera hacer `ping` a `10.0.0.132`

## 8.c Outbound NAT para el spoke MLOps

Ruta:

- `Firewall > NAT > Outbound`

Qué revisar:

- que exista NAT de salida hacia `WAN` para el spoke MLOps

Cómo debe quedar:

- modo: `Hybrid` o `Manual`
- interfaz: `WAN`
- origen: `10.1.0.0`
- máscara: `22`
- destino: `any`
- traducción: `Interface address` o `WAN address`
- `Static Port`: `NO`
- descripción sugerida: `NAT spoke mlops to WAN`

Problema real detectado:

- sin esta regla, el runner podía llegar a OPNsense pero no salir a Internet
- eso hizo fallar el `cloud-init` del runner al intentar llegar a:
  - `azure.archive.ubuntu.com`
  - `packages.microsoft.com`
  - `apt.releases.hashicorp.com`

## 9. Revisar reglas de firewall de OpenVPN

Ruta:

- `Firewall > Rules > OpenVPN`

Qué revisar:

- permiso de DNS hacia el firewall
- permiso general desde la red VPN

Cómo debe quedar como mínimo:

- regla DNS:
  - protocolo: `TCP/UDP`
  - origen: `172.16.100.0/24`
  - destino: `This Firewall`
  - puerto destino: `53`
- regla general:
  - origen: `172.16.100.0/24`
  - destino: `any`
  - acción: `pass`

Problema típico:

- el cliente conecta pero no resuelve DNS o no accede a hub y spoke

## 10. Revisar certificados y usuarios

Rutas:

- `System > Trust > Authorities`
- `System > Trust > Certificates`
- `System > Access > Users`

Qué revisar:

- que existan la CA, el certificado del servidor y el usuario VPN

Cómo debe quedar:

- el servidor OpenVPN debe seguir apuntando a una CA y certificado válidos
- el usuario exportado debe existir y poder autenticarse

Nota:

- si se comparte el backup tal cual, se pueden reutilizar certificados y usuarios ya existentes
- si luego quieren independizarse, tendrán que regenerarlos

## 11. Exportar cliente OpenVPN

Ruta:

- `VPN > OpenVPN > Client Export`

Qué revisar:

- que el perfil exportado corresponde al servidor correcto
- que el usuario existe
- que `Host Name Resolution` apunta a la IP pública real del nuevo OPNsense

Cómo debe quedar:

- si se reutiliza el mismo direccionamiento interno del entorno original, no suele hacer falta cambiar rutas o IPs internas del backup
- el cambio mínimo obligatorio antes de exportar el cliente es actualizar `Host Name Resolution` con la IP pública del nuevo firewall
- el cliente importado en Windows debe conectarse y recibir una IP `172.16.100.x`

## 12. Validar el cliente Windows

Tras conectar el cliente OpenVPN:

```cmd
ipconfig /all
```

Qué revisar:

- el adaptador `TAP-Windows Adapter V9 for OpenVPN Connect` debe tener IP tipo `172.16.100.x`
- idealmente debe usar `10.0.0.132` como DNS

Problema real detectado:

- `OpenVPN Connect` en Windows puede no aplicar correctamente el DNS empujado por el servidor
- en la validación real, el portátil seguía resolviendo por el DNS del Wi-Fi

Cómo comprobar el DNS del adaptador correcto:

```cmd
netsh interface ipv4 show dnsservers name="Local Area Connection"
```

Cómo debe quedar:

- `Statically Configured DNS Servers: 10.0.0.132`

Si no ocurre:

- fijar manualmente `10.0.0.132` como DNS en el adaptador `TAP-Windows Adapter V9 for OpenVPN Connect`

## 13. Validar red básica desde el portátil VPN

Comandos:

```cmd
ping 172.16.100.1
ping 10.0.0.132
```

Cómo debe quedar:

- ambos deben responder

## 14. Validar DNS privado base

Comandos:

```cmd
nslookup kv-mlops-stg-weu-01.privatelink.vaultcore.azure.net 10.0.0.132
nslookup stmlopsstgweu01.privatelink.blob.core.windows.net 10.0.0.132
nslookup acrmlopsstgweu01.privatelink.azurecr.io 10.0.0.132
```

Cómo debe quedar:

- respuestas privadas `10.1.1.x`

Si devuelve IP pública:

- revisar `Query Forwarding / Domain Overrides`
- revisar que `System DNS` use `168.63.129.16`

## 15. Validar Azure ML Studio

No usar nombres inventados como `mlw-...api.azureml.ms`.

Primero, obtener los FQDN reales del `Private Endpoint` del workspace:

```bash
az network private-endpoint show \
  --name pep-aml-workspace \
  --resource-group rg-mlops-workload-stg-weu-01 \
  --query "networkInterfaces[0].id" -o tsv

az network nic show \
  --ids "<NIC_ID>" \
  --query "ipConfigurations[*].{ip:privateIPAddress,fqdns:privateLinkConnectionProperties.fqdns}" \
  -o json
```

En la validación real del entorno se obtuvieron:

- `9332539b-ef8b-4cb9-8fc1-22af35747521.workspace.westeurope.api.azureml.ms` -> `10.1.1.8`
- `9332539b-ef8b-4cb9-8fc1-22af35747521.workspace.westeurope.cert.api.azureml.ms` -> `10.1.1.8`
- `ml-mlw-mlops-st-westeurope-9332539b-ef8b-4cb9-8fc1-22af35747521.westeurope.notebooks.azure.net` -> `10.1.1.9`

Comprobación desde el portátil:

```cmd
nslookup 9332539b-ef8b-4cb9-8fc1-22af35747521.workspace.westeurope.api.azureml.ms
nslookup ml-mlw-mlops-st-westeurope-9332539b-ef8b-4cb9-8fc1-22af35747521.westeurope.notebooks.azure.net
```

Cómo debe quedar:

- `Server: OPNsense.localhost`
- `Address: 10.0.0.132`
- respuestas privadas:
  - `10.1.1.8`
  - `10.1.1.9`

Si sigue resolviendo por DNS público:

- el problema no está en Azure
- el problema está en el DNS efectivo del cliente Windows

## 15.b Validar el runner del spoke

Una vez desplegada la VM runner, validar:

```bash
ssh azureuser@10.1.1.68
docker --version
az version
terraform version
az extension show --name ml
```

Cómo debe quedar:

- acceso SSH correcto por VPN
- `docker` instalado
- `az` instalado
- `terraform` instalado
- extensión `ml` presente

## 16. Dependencias fuera de OPNsense

Aunque el backup de OPNsense esté bien, también tienen que existir en Azure:

- hub con el mismo direccionamiento
- spoke con el mismo direccionamiento o equivalente adaptado
- peering Hub <-> Spoke
- `Private DNS Zones` enlazadas al hub y al spoke
- `Private Endpoints` del workload creados
- UDRs correctas

Sin eso, OPNsense puede arrancar bien pero no tendrá nada útil detrás.

## Resumen rápido para compartir

Si se importa esta configuración en una nueva VM OPNsense, revisar siempre:

1. asignación correcta de NICs
2. IP trust `10.0.0.132`
3. ruta `172.16.100.0/24 -> 10.0.0.129`
4. OpenVPN con `172.16.100.0/24` y `10.0.0.0/22,10.1.0.0/22`
5. DNS entregado a clientes `10.0.0.132`
6. forwarders de Unbound a `168.63.129.16`
7. que el cliente Windows realmente use `10.0.0.132` como DNS
8. validación con `nslookup` de Key Vault, Storage, ACR y Azure ML Studio
