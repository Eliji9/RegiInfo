# RegiInfo

Migración a S/4HANA Cloud Private (ABAP Cloud) del reporte clásico
`ZMM_BAPI_PO_CREATE` que crea/actualiza registros info de compras
(EINA/EINE), incluyendo el seteo de `APLFZ` (Planned Delivery Time),
antes hecho vía ME12/`ZMM_CHANGE_CONDITION_INFO`.

## Objetos

- `src/zif_s4_reg_info_dest.intf.abap` — interfaz liberada (C1) del
  wrapper de destino SM59.
- `src/zcl_s4_reg_info_dest.clas.abap` — implementación del wrapper
  (language version Standard, fuera de ABAP for Cloud Development).
  Resuelve el destino SM59 `S4_REG_INFO`.
- `src/zcl_api_http_client.clas.abap` — cliente HTTP genérico ABAP
  Cloud, con manejo de token CSRF para escritura OData V2.
- `src/zcl_api_pur_info_record_methods.abap` — métodos a incorporar en
  `ZCL_API_PUR_INFO_RECORD` (ya existente en el sistema): `CREATE_JSON`,
  `CREATE_INFO_RECORD`, `GET_INFO_RECORD_LIST`, `EXISTS_INFO_RECORD`,
  `UPDATE_INFO_RECORD`, contra `API_INFORECORD_PROCESS_SRV`.

## Pendiente de verificar en sistema real

- Claves de enlace exactas entre las tablas planas del deep-insert
  (asumidas: `CONDITIONRECORD`/`CONDITIONSEQUENTIALNUMBER` y
  `PURCHASINGINFORECORD`/`PURCHASINGORGANIZATION`/`PLANT`).
- Sintaxis exacta de navegación de `XCO_CP_JSON` para parsear la
  respuesta OData V2 (envuelta en `{"d": {...}}`).

## Actualización — patrón Tier 2 completo

Se agregó `src/zcl_s4_reg_info_dest_factory.clas.abap`, la clase factory
que junto con `zif_s4_reg_info_dest.intf.abap` es lo único que el código
ABAP Cloud consumidor referencia. `zcl_s4_reg_info_dest.clas.abap` (la
implementación concreta) permanece sin liberar, según el patrón
documentado por SAP:
https://developers.sap.com/tutorials/abap-s4hanacloud-purchasereq-create-wrapper

Al liberar en el sistema real: Release Contract C1 (System-Internal Use)
+ "Use in Cloud Development" sobre la interfaz y la clase factory
únicamente.
