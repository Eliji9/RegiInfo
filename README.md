# RegiInfo

Migración a S/4HANA Cloud Private (ABAP Cloud) del reporte clásico
`ZMM_BAPI_PO_CREATE` que crea/actualiza registros info de compras
(EINA/EINE), incluyendo el seteo de `APLFZ` (Planned Delivery Time),
antes hecho vía ME12/`ZMM_CHANGE_CONDITION_INFO`.

## Objeto

- `src/zcl_api_pur_info_record.clas.abap` — clase única y consolidada
  (decisión explícita: sin wrapper interfaz/factory separado) con:
  - Resolución del destino SM59 `S4_REG_INFO` (método privado
    `GET_DESTINATION`, vía `CL_OUTBOUND_PROVIDER_HTTP`)
  - Cliente HTTP con ciclo CSRF para OData V2 (métodos privados
    `HTTP_GET` / `HTTP_POST` / `HTTP_PATCH`)
  - Lógica de negocio: `CREATE_JSON`, `CREATE_INFO_RECORD`,
    `GET_INFO_RECORD_LIST`, `EXISTS_INFO_RECORD`, `UPDATE_INFO_RECORD`
    contra `API_INFORECORD_PROCESS_SRV`

## Nota de compliance ABAP Cloud

`GET_DESTINATION` llama a `CL_OUTBOUND_PROVIDER_HTTP=>create_by_destination()`,
API no liberada para ABAP for Cloud Development. Al no usarse el patrón
de wrapper formal (interfaz + factory liberadas / implementación sin
liberar), esta clase requiere una **exención de ATC** sobre esa llamada
puntual para pasar el chequeo "Cloud Development" — marcado con `"#EC`
en el código como placeholder del pragma real.

## Pendiente de verificar en sistema real

- Claves de enlace exactas entre las tablas planas del deep-insert
  (asumidas: `CONDITIONRECORD`/`CONDITIONSEQUENTIALNUMBER` y
  `PURCHASINGINFORECORD`/`PURCHASINGORGANIZATION`/`PLANT`).
- Sintaxis exacta de navegación de `XCO_CP_JSON` para parsear la
  respuesta OData V2 (envuelta en `{"d": {...}}`).
