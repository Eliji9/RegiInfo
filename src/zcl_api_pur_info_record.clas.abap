"! Clase única y consolidada (sin wrapper interfaz/factory).
"! Usa ZCL_API_REQUEST (ya existente) para toda la comunicación HTTP -
"! esa clase resuelve el destino SM59 internamente vía IV_DESTINATION,
"! así que aquí no se toca CL_OUTBOUND_PROVIDER_HTTP ni nada no liberado.
CLASS zcl_api_pur_info_record DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    "! (TYPES ya existentes en tu clase: se mantienen sin cambios -
    "! ty_pricingcndnrecdscale, ty_recdsuplmntprcgcndn, ty_info_rec_prcgcndn,
    "! ty_info_rec_prcg_validity, ty_info_rec_org_plan_data(_json),
    "! ty_info_rec_text, ty_info_record, ty_update_info_record,
    "! ty_error(_detail) y sus TT_/results wrappers.)

    CLASS-METHODS create_info_record
      IMPORTING it_pricingcndnrecdscale   TYPE tt_pricingcndnrecdscale OPTIONAL
                it_recdsuplmntprcgcndn    TYPE tt_recdsuplmntprcgcndn OPTIONAL
                it_info_rec_prcgcndn      TYPE tt_info_rec_prcgcndn OPTIONAL
                it_info_rec_prcg_validity TYPE tt_info_rec_prcg_validity OPTIONAL
                it_info_rec_org_plan_data TYPE tt_info_rec_org_plan_data OPTIONAL
                it_info_rec_text          TYPE tt_info_rec_text OPTIONAL
                is_update_info_record     TYPE ty_update_info_record
      EXPORTING ev_purchasinginforecord   TYPE ebeln
                ev_po_response            TYPE ty_info_record
      RETURNING VALUE(rt_error)           TYPE tt_error.

    CLASS-METHODS create_json
      IMPORTING it_pricingcndnrecdscale   TYPE tt_pricingcndnrecdscale OPTIONAL
                it_recdsuplmntprcgcndn    TYPE tt_recdsuplmntprcgcndn OPTIONAL
                it_info_rec_prcgcndn      TYPE tt_info_rec_prcgcndn OPTIONAL
                it_info_rec_prcg_validity TYPE tt_info_rec_prcg_validity OPTIONAL
                it_info_rec_org_plan_data TYPE tt_info_rec_org_plan_data OPTIONAL
                it_info_rec_text          TYPE tt_info_rec_text OPTIONAL
                is_update_info_record     TYPE ty_update_info_record
      RETURNING VALUE(rv_json_string)     TYPE string.

    "! NOTA: corregir en tu sistema el RETURNING actual
    "! (TYPE ty_update_info_record, estructura única) por una TABLA de
    "! TY_INFO_RECORD - una estructura no puede devolver una "lista".
    CLASS-METHODS get_info_record_list
      IMPORTING supplier                 TYPE lifnr
                material                 TYPE matnr
                purchasingorganization   TYPE ekorg
                plant                    TYPE werks_d OPTIONAL
      RETURNING VALUE(rt_info_record)    TYPE STANDARD TABLE OF ty_info_record WITH EMPTY KEY.

    CLASS-METHODS exists_info_record
      IMPORTING iv_supplier                    TYPE lifnr
                iv_material                    TYPE matnr
                iv_ekorg                       TYPE ekorg
                iv_werks                       TYPE werks_d OPTIONAL
      RETURNING VALUE(rv_purchasinginforecord) TYPE ebeln.

    CLASS-METHODS update_info_record
      IMPORTING iv_purchasinginforecord TYPE string
                iv_ekorg                TYPE string
                iv_werks                TYPE string
                iv_aplfz                TYPE string OPTIONAL
                iv_netpr                TYPE string OPTIONAL
                iv_mwskz                TYPE string OPTIONAL
      RETURNING VALUE(rt_error)         TYPE tt_error.

  PRIVATE SECTION.

    "! (Ya existentes en tu clase - se mantienen: C_DESTINATION
    "! 'S4_REG_INFO', C_URI_HEADER, C_URI_ORG_PLANT)

ENDCLASS.


CLASS zcl_api_pur_info_record IMPLEMENTATION.

  METHOD create_json.
    " SUPUESTO A VERIFICAR: claves de enlace CONDITIONRECORD (+
    " CONDITIONSEQUENTIALNUMBER) y PURCHASINGINFORECORD +
    " PURCHASINGORGANIZATION + PLANT entre las tablas planas.

    DATA(ls_info_record) = CORRESPONDING ty_info_record( is_update_info_record ).

    LOOP AT it_info_rec_org_plan_data INTO DATA(ls_org_plan).
      DATA(ls_org_plan_json) = CORRESPONDING ty_info_rec_org_plan_data_json( ls_org_plan ).

      LOOP AT it_info_rec_prcg_validity INTO DATA(ls_validity)
        WHERE purchasinginforecord   = ls_org_plan-purchasinginforecord
          AND purchasingorganization = ls_org_plan-purchasingorganization
          AND plant                  = ls_org_plan-plant.

        DATA(ls_validity_json) = CORRESPONDING ty_info_rec_prcg_validity_json( ls_validity ).

        LOOP AT it_info_rec_prcgcndn INTO DATA(ls_cndn)
          WHERE conditionrecord = ls_validity-conditionrecord.

          DATA(ls_cndn_json) = CORRESPONDING ty_info_rec_prcgcndn_json( ls_cndn ).

          LOOP AT it_pricingcndnrecdscale INTO DATA(ls_scale)
            WHERE conditionrecord           = ls_cndn-conditionrecord
              AND conditionsequentialnumber = ls_cndn-conditionsequentialnumber.
            APPEND ls_scale TO ls_cndn_json-to_purginfopricingcndnrecdscal-results.
          ENDLOOP.

          LOOP AT it_recdsuplmntprcgcndn INTO DATA(ls_suplmnt)
            WHERE conditionrecord           = ls_cndn-conditionrecord
              AND conditionsequentialnumber = ls_cndn-conditionsequentialnumber.
            APPEND ls_suplmnt TO ls_cndn_json-to_purinforecdsuplmntprcgcndn-results.
          ENDLOOP.

          APPEND ls_cndn_json TO ls_validity_json-to_purinforecdprcgcndn-results.
        ENDLOOP.

        APPEND ls_validity_json TO ls_org_plan_json-to_purinforecdprcgcndnvalidity-results.
      ENDLOOP.

      LOOP AT it_info_rec_text INTO DATA(ls_text)
        WHERE purchasinginforecord   = ls_org_plan-purchasinginforecord
          AND purchasingorganization = ls_org_plan-purchasingorganization
          AND plant                  = ls_org_plan-plant.
        APPEND ls_text TO ls_org_plan_json-to_purinforecdpurorgtext-results.
      ENDLOOP.

      APPEND ls_org_plan_json TO ls_info_record-to_purginforecdorgplantdata-results.
    ENDLOOP.

    DATA(lt_name_mapping) = VALUE /ui2/cl_json=>name_mappings(
      ( abap = 'SUPPLIER'                    json = 'Supplier' )
      ( abap = 'MATERIAL'                    json = 'Material' )
      ( abap = 'PURCHASINGORGANIZATION'      json = 'PurchasingOrganization' )
      ( abap = 'PLANT'                       json = 'Plant' )
      ( abap = 'MATERIALPLANNEDDELIVERYDURN' json = 'MaterialPlannedDeliveryDurn' )
      ( abap = 'NETPRICEAMOUNT'              json = 'NetPriceAmount' )
      ( abap = 'TAXCODE'                     json = 'TaxCode' )
      ( abap = 'CURRENCY'                    json = 'Currency' )
      ( abap = 'PURCHASINGGROUP'             json = 'PurchasingGroup' )
    ).
    " TODO: extender lt_name_mapping con cualquier otro campo que
    " confirmes necesario para el POST real, siguiendo el mismo patrón.

    rv_json_string = /ui2/cl_json=>serialize(
      data         = ls_info_record
      compress     = abap_true
      pretty_name  = /ui2/cl_json=>pretty_mode-camel_case
      name_mappings = lt_name_mapping ).
  ENDMETHOD.


  METHOD create_info_record.
    CLEAR: ev_purchasinginforecord, ev_po_response, rt_error.

    DATA(lv_json_string) = create_json(
      it_pricingcndnrecdscale   = it_pricingcndnrecdscale
      it_recdsuplmntprcgcndn    = it_recdsuplmntprcgcndn
      it_info_rec_prcgcndn      = it_info_rec_prcgcndn
      it_info_rec_prcg_validity = it_info_rec_prcg_validity
      it_info_rec_org_plan_data = it_info_rec_org_plan_data
      it_info_rec_text          = it_info_rec_text
      is_update_info_record     = is_update_info_record ).

    IF lv_json_string IS INITIAL.
      APPEND VALUE #( message = 'No se pudo construir el JSON de salida' ) TO rt_error.
      RETURN.
    ENDIF.

    DATA(lv_uri) = c_uri_header.
    DATA lv_response TYPE string.
    DATA lv_error    TYPE string.

    DATA(lv_status) = zcl_api_request=>post_api_service(
      EXPORTING iv_data        = lv_json_string
                iv_uri         = lv_uri
                iv_destination = c_destination
      IMPORTING ev_response    = lv_response
                ev_error       = lv_error ).

    IF lv_error IS NOT INITIAL.
      APPEND VALUE #( code = 'HTTP_SEND' message = lv_error target = 'HTTP' ) TO rt_error.
      RETURN.
    ENDIF.

    IF lv_status <> 201.
      APPEND VALUE #( code = |HTTP_{ lv_status }| message = lv_response ) TO rt_error.
      RETURN.
    ENDIF.

    " Mismo patrón que ya usas para el parseo de errores: deserializar
    " con /UI2/CL_JSON sobre TY_ODATA_RESPONSE.
    DATA ls_odata_response TYPE ty_odata_response.

    TRY.
        /ui2/cl_json=>deserialize(
          EXPORTING json = lv_response
          CHANGING  data = ls_odata_response ).
      CATCH cx_root.
        APPEND VALUE ty_error(
          code    = |{ lv_status }|
          message = lv_response
          target  = 'HTTP_RESPONSE'
        ) TO rt_error.
        RETURN.
    ENDTRY.

    IF ls_odata_response-error-code IS NOT INITIAL.
      APPEND VALUE ty_error(
        code       = ls_odata_response-error-code
        message    = ls_odata_response-error-message
        target     = ls_odata_response-error-target
        innererror = lv_response
      ) TO rt_error.
      RETURN.
    ENDIF.

    " TODO: confirmar el nombre real del componente que contiene el
    " payload exitoso en TY_ODATA_RESPONSE (asumido "d", estándar OData V2).
    ev_po_response          = ls_odata_response-d.
    ev_purchasinginforecord = ev_po_response-purchasinginforecord.
  ENDMETHOD.


  METHOD get_info_record_list.
    " ZCL_API_REQUEST no tiene método GET - consulta local vía CDS
    " liberadas, igual que EXISTS_INFO_RECORD pero trayendo más campos.
    " Ajustar el SELECT según los campos que realmente necesites de
    " TY_INFO_RECORD (aquí solo se listan los de cabecera + org/planta
    " ya confirmados).

    IF plant IS NOT INITIAL.
      SELECT a~purchasinginforecord, a~supplier, a~material,
             b~purchasingorganization, b~plant, b~purchasinggroup,
             b~currency, b~materialplanneddeliverydurn
        FROM i_purchasinginforecordtp AS a
        INNER JOIN i_purginforecdorgplantdata AS b
          ON b~purchasinginforecord = a~purchasinginforecord
        WHERE a~supplier              = @supplier
          AND a~material               = @material
          AND b~purchasingorganization = @purchasingorganization
          AND b~plant                  = @plant
        INTO CORRESPONDING FIELDS OF TABLE @rt_info_record.
    ELSE.
      SELECT a~purchasinginforecord, a~supplier, a~material,
             b~purchasingorganization, b~plant, b~purchasinggroup,
             b~currency, b~materialplanneddeliverydurn
        FROM i_purchasinginforecordtp AS a
        INNER JOIN i_purginforecdorgplantdata AS b
          ON b~purchasinginforecord = a~purchasinginforecord
        WHERE a~supplier              = @supplier
          AND a~material               = @material
          AND b~purchasingorganization = @purchasingorganization
        INTO CORRESPONDING FIELDS OF TABLE @rt_info_record.
    ENDIF.
  ENDMETHOD.


  METHOD exists_info_record.
    IF iv_werks IS NOT INITIAL.
      SELECT SINGLE b~purchasinginforecord
        FROM i_purchasinginforecordtp AS a
        INNER JOIN i_purginforecdorgplantdata AS b
          ON b~purchasinginforecord = a~purchasinginforecord
        WHERE a~supplier              = @iv_supplier
          AND a~material               = @iv_material
          AND b~purchasingorganization = @iv_ekorg
          AND b~plant                  = @iv_werks
        INTO @rv_purchasinginforecord.
    ELSE.
      SELECT SINGLE b~purchasinginforecord
        FROM i_purchasinginforecordtp AS a
        INNER JOIN i_purginforecdorgplantdata AS b
          ON b~purchasinginforecord = a~purchasinginforecord
        WHERE a~supplier              = @iv_supplier
          AND a~material               = @iv_material
          AND b~purchasingorganization = @iv_ekorg
        INTO @rv_purchasinginforecord.
    ENDIF.
  ENDMETHOD.


  METHOD update_info_record.
    DATA(lv_uri) = |{ c_uri_org_plant }(PurchasingInfoRecord='{ iv_purchasinginforecord }',| &&
                   |PurchasingOrganization='{ iv_ekorg }',Plant='{ iv_werks }')|.

    DATA(lt_field) = VALUE string_table( ).
    IF iv_aplfz IS NOT INITIAL.
      APPEND |"MaterialPlannedDeliveryDurn": "{ iv_aplfz }"| TO lt_field.
    ENDIF.
    IF iv_netpr IS NOT INITIAL.
      APPEND |"NetPriceAmount": "{ iv_netpr }"| TO lt_field.
    ENDIF.
    IF iv_mwskz IS NOT INITIAL.
      APPEND |"TaxCode": "{ iv_mwskz }"| TO lt_field.
    ENDIF.

    DATA(lv_body) = |\{ { concat_lines_of( table = lt_field sep = `, ` ) } \}|.

    DATA lv_response TYPE string.
    DATA lv_error    TYPE string.

    DATA(lv_status) = zcl_api_request=>patch_api_service(
      EXPORTING iv_data        = lv_body
                iv_uri         = lv_uri
                iv_destination = c_destination
      IMPORTING ev_response    = lv_response
                ev_error       = lv_error ).

    IF lv_error IS NOT INITIAL.
      APPEND VALUE #( code = 'HTTP_SEND' message = lv_error target = 'HTTP' ) TO rt_error.
    ELSEIF lv_status <> 200 AND lv_status <> 204.
      APPEND VALUE #( code = |HTTP_{ lv_status }| message = lv_response ) TO rt_error.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
