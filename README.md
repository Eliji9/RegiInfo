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
