# Pruebas manuales — /IWFND/GW_CLIENT (Cliente SAP Gateway)

Ejecutar en este orden. El token CSRF del paso 0 se reutiliza en los
pasos 2 y 3 (misma sesión/pestaña del Gateway Client).

## 0. Token CSRF (obligatorio antes de POST/PATCH)

- Método: `GET`
- URI:
```
/sap/opu/odata/sap/API_INFORECORD_PROCESS_SRV/?$format=json
```
- Header: `X-CSRF-Token: Fetch`
- Copiar el header `X-CSRF-Token` de la respuesta.

---

## 1. GET — validar existencia

Datos: proveedor `11783`, material `300145`, org. compras `CR01`,
centro `CR01`.

- Método: `GET`
- URI:
```
/sap/opu/odata/sap/API_INFORECORD_PROCESS_SRV/A_PurgInfoRecdOrgPlantData?$filter=Supplier eq '11783' and Material eq '300145' and PurchasingOrganization eq 'CR01' and Plant eq 'CR01'&$format=json
```
- Resultado esperado: el registro con su `PurchasingInfoRecord` (usar
  el valor real que devuelva, no el que se alcanza a leer en capturas).

---

## 2. POST — crear

Datos: proveedor `11605`, material `300145`, org./centro `CR01`, grupo
compras `CRC`, cantidad estándar `1`, plazo entrega `7` días, moneda
`CRC`.

- Método: `POST`
- Headers: `Content-Type: application/json`,
  `X-CSRF-Token: <token del paso 0>`
- URI:
```
/sap/opu/odata/sap/API_INFORECORD_PROCESS_SRV/A_PurgInfoRecdOrgPlantData
```
- Body:
```json
{
  "Supplier": "11605",
  "Material": "300145",
  "PurchasingOrganization": "CR01",
  "Plant": "CR01",
  "PurchasingInfoRecordCategory": "0",
  "PurchasingGroup": "CRC",
  "StandardPurchaseOrderQuantity": "1",
  "PurgDocOrderQuantityUnit": "<UM base del material 300145 - ver MM03/MARA-MEINS>",
  "MaterialPlannedDeliveryDurn": "7",
  "Currency": "CRC"
}
```
**Nota:** el campo `PurgDocOrderQuantityUnit` es obligatorio en la
práctica aunque no aparezca marcado como `Required` en el metadata -
sin él, el servicio devuelve `500` / código `06/340`
("compruebe las unidades de medida y el factor de conversión"),
confirmado en prueba real (ver bitácora al final del archivo).

**Si falla** (algunos servicios exigen cabecera primero), probar en dos
pasos:

1. `POST` a `A_PurchasingInfoRecord`:
```json
{
  "Supplier": "11605",
  "Material": "300145"
}
```
2. Tomar el `PurchasingInfoRecord` devuelto y repetir el body de arriba
   agregando `"PurchasingInfoRecord": "<ese número>"`.

---

## 3. PATCH — actualizar APLFZ

Sobre el registro existente del paso 1. Reemplazar `<PIR>` por el
`PurchasingInfoRecord` real devuelto en el paso 1.

- Método: `PATCH`
- Headers: `Content-Type: application/json`,
  `X-CSRF-Token: <mismo token>`
- URI:
```
/sap/opu/odata/sap/API_INFORECORD_PROCESS_SRV/A_PurgInfoRecdOrgPlantData(PurchasingInfoRecord='<PIR>',PurchasingOrganization='CR01',Plant='CR01')
```
- Body:
```json
{
  "MaterialPlannedDeliveryDurn": "1"
}
```

---

## 4. Prueba de ZCL_API_PUR_INFO_RECORD=>UPSERT_INFO_RECORD (una vez 1-3 OK)

Caso A — actualización (registro existente, datos del paso 1):
```abap
DATA(lt_error) = zcl_api_pur_info_record=>upsert_info_record(
  EXPORTING
    is_update_info_record = VALUE #( supplier = '11783' material = '300145' )
    iv_ekorg               = 'CR01'
    iv_werks                = 'CR01'
    iv_aplfz                 = '1'
  IMPORTING
    ev_purchasinginforecord = DATA(lv_pir)
    ev_created              = DATA(lv_created) ).
```
Esperado: `lv_created = abap_false`, `lv_pir` = el mismo `PurchasingInfoRecord`
del paso 1, `lt_error` vacío.

Caso B — creación (datos del paso 2, proveedor/material que NO tengan
registro info previo):
```abap
DATA(lt_error) = zcl_api_pur_info_record=>upsert_info_record(
  EXPORTING
    is_update_info_record     = VALUE #( supplier = '11605' material = '300145' )
    it_info_rec_org_plan_data = VALUE #( (
      purchasingorganization      = 'CR01'
      plant                       = 'CR01'
      purchasinginforecordcategory = '0'
      purchasinggroup             = 'CRC'
      standardpurchaseorderquantity = '1'
      materialplanneddeliverydurn = '7'
      currency                    = 'CRC' ) )
    iv_ekorg = 'CR01'
    iv_werks = 'CR01'
  IMPORTING
    ev_purchasinginforecord = DATA(lv_pir)
    ev_created              = DATA(lv_created) ).
```
Esperado: `lv_created = abap_true`, `lv_pir` con el número nuevo
asignado, `lt_error` vacío.

## Pendiente de completar con resultados reales

Reemplazar este bloque con el status/body real que devuelva cada paso
al ejecutarlo, para dejar registro de qué quedó validado y qué no.


## Bitácora de resultados reales

### Paso 2 (POST crear) - intento 1
- **Resultado:** `500 Internal Server Error`
- **Código:** `06/340`
- **Mensaje:** "Por favor, compruebe las unidades de medida y el factor de conversión"
- **Componente:** MM-PUR-VM-REC
- **Causa:** faltaba `PurgDocOrderQuantityUnit` en el body (se envió
  `StandardPurchaseOrderQuantity` sin su unidad de medida).
- **Siguiente intento:** repetir con `PurgDocOrderQuantityUnit` seteado
  a la UM base real del material `300145`.
