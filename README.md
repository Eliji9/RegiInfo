# RegiInfo

Migración a S/4HANA Cloud Private (ABAP Cloud) del reporte clásico
`ZMM_BAPI_PO_CREATE` que crea/actualiza registros info de compras
(EINA/EINE), incluyendo el seteo de `APLFZ` (Planned Delivery Time),
antes hecho vía ME12/`ZMM_CHANGE_CONDITION_INFO`.

## Objeto

- `src/zcl_api_pur_info_record.clas.abap` — clase única y consolidada
  (sin wrapper interfaz/factory separado). Usa `ZCL_API_REQUEST`
  (clase genérica ya existente en el sistema: `POST_API_SERVICE`,
  `PATCH_API_SERVICE`, `DELETE_API_SERVICE`, resuelve destino SM59
  internamente vía `IV_DESTINATION`) para toda la comunicación HTTP.
  Métodos: `CREATE_JSON`, `CREATE_INFO_RECORD`, `GET_INFO_RECORD_LIST`
  (consulta local vía CDS, ya que `ZCL_API_REQUEST` no expone GET),
  `EXISTS_INFO_RECORD`, `UPDATE_INFO_RECORD`.

## Nota importante sobre GET_INFO_RECORD_LIST

El `RETURNING` visto en el sistema real está tipado como
`TY_UPDATE_INFO_RECORD` (estructura única) — no puede ser correcto para
un método que devuelve una "lista". Se corrigió en este archivo a una
tabla de `TY_INFO_RECORD`; falta aplicar esa corrección en el sistema.

También se detectó, en el cuerpo actual de `GET_INFO_RECORD_LIST` en el
sistema, lógica de creación (POST + `IF lv_status = 201` +
`"Purchase Order created"`) que no corresponde a ese método — revisar
si es código de otro objeto pegado como plantilla.

## Pendiente de verificar en sistema real

- Claves de enlace exactas entre las tablas planas del deep-insert
  (asumidas: `CONDITIONRECORD`/`CONDITIONSEQUENTIALNUMBER` y
  `PURCHASINGINFORECORD`/`PURCHASINGORGANIZATION`/`PLANT`).
- Sintaxis exacta de navegación de `XCO_CP_JSON` para parsear la
  respuesta OData V2 (envuelta en `{"d": {...}}`).
- Valores reales de `C_URI_HEADER` / `C_URI_ORG_PLANT` (ya existentes
  en la clase; se asume que apuntan a `A_PurchasingInfoRecord` y
  `A_PurgInfoRecdOrgPlantData` respectivamente).

## Actualización — JSON con /UI2/CL_JSON (no XCO_CP_JSON)

Se reemplazó `XCO_CP_JSON` por `/UI2/CL_JSON`, ya usado en el sistema
real para deserializar la respuesta (`TY_ODATA_RESPONSE`). Para la
serialización de salida se usa `pretty_name = camel_case` +
`name_mappings` explícito solo para los campos críticos del flujo
(Supplier, Material, PurchasingOrganization, Plant,
MaterialPlannedDeliveryDurn, NetPriceAmount, TaxCode, Currency,
PurchasingGroup).

**Riesgo señalado, no resuelto automáticamente:** los campos ABAP están
declarados sin guion bajo (`materialplanneddeliverydurn`), por lo que
`camel_case` no puede reconstruir el PascalCase real de OData sin la
ayuda del `name_mapping`. Verificar en el sistema si además falta
extender el mapping a otros campos usados en producción.

**Pendiente de confirmar:** el nombre del componente que contiene el
payload exitoso en `TY_ODATA_RESPONSE` (asumido `d`, estándar OData V2)
para completar `ev_po_response` / `ev_purchasinginforecord`.

## Corrección — GET_INFO_RECORD_LIST devolvía TY_INFO_RECORD (anidado)

`TY_INFO_RECORD` no tiene `purchasingorganization`/`plant`/`purchasinggroup`
/`currency`/`materialplanneddeliverydurn` como campos planos (van dentro
del nodo anidado `to_purginforecdorgplantdata`), por lo que el
`SELECT ... INTO CORRESPONDING FIELDS OF TABLE` fallaba en activación.
Se agregó un tipo propio `TY_INFO_RECORD_ROW` (y su tabla
`TT_INFO_RECORD_ROW`), plano, solo con los campos que esta consulta
local trae. `GET_INFO_RECORD_LIST` ahora devuelve `TT_INFO_RECORD_ROW`.

## Nuevo — UPSERT_INFO_RECORD (orquestador check-existencia → create/update)

Replica la lógica del reporte ECC original (`ZMM_BAPI_PO_CREATE`):
1. `EXISTS_INFO_RECORD` (equivalente a `BAPI_INFORECORD_GETLIST` + SELECT
   sobre EINE).
2. Si existe → `UPDATE_INFO_RECORD` (equivalente a `ME_UPDATE_INFORECORD`).
3. Si no existe → `CREATE_INFO_RECORD` (equivalente a
   `ME_INITIALIZE_INFORECORD` + `ME_DIRECT_INPUT_INFORECORD` +
   `ME_POST_INFORECORD`).

Este es el método público a invocar desde el consumidor final en vez de
llamar `CREATE_INFO_RECORD`/`UPDATE_INFO_RECORD` por separado.

## Corrección — UPSERT_INFO_RECORD: incompatibilidad de tipos STRING/LIFNR-MATNR

`IS_UPDATE_INFO_RECORD-SUPPLIER`/`-MATERIAL` son `STRING` (así está
tipada toda `TY_UPDATE_INFO_RECORD`), pero `EXISTS_INFO_RECORD` espera
`LIFNR`/`MATNR`. Se agregó `CONV lifnr(...)` / `CONV matnr(...)` en la
llamada dentro de `UPSERT_INFO_RECORD` en vez de debilitar el tipado de
`EXISTS_INFO_RECORD`.

## Corrección — dominio del número de registro info: INFNR, no EBELN

Todas las referencias al "PurchasingInfoRecord" (número de registro
info de compras) estaban tipadas `EBELN` (dominio de número de pedido)
como placeholder. Se corrigió a `INFNR` (dominio correcto), alineado
con lo que ya está tipado así en el sistema real
(`EXISTS_INFO_RECORD`, `UPSERT_INFO_RECORD`). También se agregó
`CONV string(...)` en la llamada a `UPDATE_INFO_RECORD` dentro de
`UPSERT_INFO_RECORD`, mismo patrón que la corrección anterior
(`IV_PURCHASINGINFORECORD` es `STRING` en `UPDATE_INFO_RECORD`).

## Corrección — IV_EKORG/IV_WERKS: EKORG/WERKS_D vs STRING

Mismo patrón otra vez: `UPSERT_INFO_RECORD` tiene `iv_ekorg`/`iv_werks`
tipados por dominio (`EKORG`/`WERKS_D`), pero `UPDATE_INFO_RECORD` los
espera como `STRING`. Se agregó `CONV string(...)` en ambos, en la
llamada dentro de `UPSERT_INFO_RECORD`.

## Nuevo — soporte para IsDeleted (equivalente al LOEKZ del ECC)

En el ECC, `ME_UPDATE_INFORECORD` limpiaba/marcaba
`IT_EINA-LOEKZ`/`IT_EINE-LOEKZ` (indicador de borrado) en cada
actualización. En la API el campo equivalente es `IsDeleted`
(booleano, en `A_PurgInfoRecdOrgPlantData`).

Se agregó `iv_isdeleted TYPE abap_bool OPTIONAL` a `UPDATE_INFO_RECORD`
y se propagó a través de `UPSERT_INFO_RECORD`. Solo se envía
`"IsDeleted": true` en el body cuando se pasa `abap_true` explícito -
no se manda `false` automáticamente cuando el parámetro simplemente no
se pasa (`ABAP_BOOL` no distingue "no pasado" de "false": ambos son el
valor inicial `' '`).

## Ajuste — IsDeleted se manda SIEMPRE en cada update (no condicional)

Corrección sobre la entrada anterior: no es "solo cuando se pide
borrar" - el ECC limpiaba `LOEKZ` de forma incondicional en cada
`ME_UPDATE_INFORECORD`. Ahora `UPDATE_INFO_RECORD` manda
`"IsDeleted": true/false` en TODA actualización. Si el llamador no
pasa `iv_isdeleted`, el default de `ABAP_BOOL` (`abap_false`) ya
produce `"IsDeleted": false`, que es el comportamiento correcto por
defecto (mantener el registro activo).
