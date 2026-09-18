"=============================================================
" 1) NUEVAS DECLARACIONES A AGREGAR EN LA PUBLIC SECTION
"    (junto a CREATE_INFO_RECORD / CREATE_JSON / GET_INFO_RECORD_LIST)
"=============================================================

    CLASS-METHODS exists_info_record
      IMPORTING iv_supplier                    TYPE lifnr
                iv_material                    TYPE matnr
                iv_ekorg                       TYPE ekorg
                iv_werks                       TYPE werks_d OPTIONAL
      RETURNING VALUE(rv_purchasinginforecord) TYPE ebeln.  " ajustar Data Element si difiere

    CLASS-METHODS update_info_record
      IMPORTING iv_purchasinginforecord TYPE string
                iv_ekorg                TYPE string
                iv_werks                TYPE string
                iv_aplfz                TYPE string OPTIONAL  " MaterialPlannedDeliveryDurn
                iv_netpr                TYPE string OPTIONAL
                iv_mwskz                TYPE string OPTIONAL
      RETURNING VALUE(rt_error)         TYPE tt_error.


"=============================================================
" 2) IMPLEMENTACIONES (van dentro de CLASS zcl_api_pur_info_record
"    IMPLEMENTATION ... ENDCLASS. reemplazando/completando los
"    métodos existentes)
"=============================================================

  METHOD create_json.
"---------------------------------------------------------------
" Arma el árbol OData anidado completo a partir de las tablas
" planas recibidas, y lo serializa con XCO_CP_JSON (liberado
" para ABAP Cloud, genérico por reflexión).
"
" SUPUESTO A VERIFICAR: las claves de enlace entre tablas planas
" son CONDITIONRECORD (+ CONDITIONSEQUENTIALNUMBER donde aplica)
" para la cadena de condiciones de precio, y PURCHASINGINFORECORD
" + PURCHASINGORGANIZATION + PLANT para org/planta, validez y
" texto. Si en tu sistema el enlace real usa otra combinación de
" campos, ajusta las cláusulas WHERE de abajo - el resto del
" método no cambia.
"---------------------------------------------------------------

    DATA(ls_info_record) = CORRESPONDING ty_info_record( is_update_info_record ).

    LOOP AT it_info_rec_org_plan_data INTO DATA(ls_org_plan).

      DATA(ls_org_plan_json) = CORRESPONDING ty_info_rec_org_plan_data_json( ls_org_plan ).

      " --- nivel: validez de condición (org/planta -> validity) ---
      LOOP AT it_info_rec_prcg_validity INTO DATA(ls_validity)
        WHERE purchasinginforecord   = ls_org_plan-purchasinginforecord
          AND purchasingorganization = ls_org_plan-purchasingorganization
          AND plant                  = ls_org_plan-plant.

        DATA(ls_validity_json) = CORRESPONDING ty_info_rec_prcg_validity_json( ls_validity ).

        " --- nivel: condición de precio (validity -> condición) ---
        LOOP AT it_info_rec_prcgcndn INTO DATA(ls_cndn)
          WHERE conditionrecord = ls_validity-conditionrecord.

          DATA(ls_cndn_json) = CORRESPONDING ty_info_rec_prcgcndn_json( ls_cndn ).

          " --- nivel: escalas de precio ---
          LOOP AT it_pricingcndnrecdscale INTO DATA(ls_scale)
            WHERE conditionrecord           = ls_cndn-conditionrecord
              AND conditionsequentialnumber = ls_cndn-conditionsequentialnumber.
            APPEND ls_scale TO ls_cndn_json-to_purginfopricingcndnrecdscal-results.
          ENDLOOP.

          " --- nivel: condiciones suplementarias ---
          LOOP AT it_recdsuplmntprcgcndn INTO DATA(ls_suplmnt)
            WHERE conditionrecord           = ls_cndn-conditionrecord
              AND conditionsequentialnumber = ls_cndn-conditionsequentialnumber.
            APPEND ls_suplmnt TO ls_cndn_json-to_purinforecdsuplmntprcgcndn-results.
          ENDLOOP.

          APPEND ls_cndn_json TO ls_validity_json-to_purinforecdprcgcndn-results.
        ENDLOOP.

        APPEND ls_validity_json TO ls_org_plan_json-to_purinforecdprcgcndnvalidity-results.
      ENDLOOP.

      " --- nivel: textos (org/planta -> texto) ---
      LOOP AT it_info_rec_text INTO DATA(ls_text)
        WHERE purchasinginforecord   = ls_org_plan-purchasinginforecord
          AND purchasingorganization = ls_org_plan-purchasingorganization
          AND plant                  = ls_org_plan-plant.
        APPEND ls_text TO ls_org_plan_json-to_purinforecdpurorgtext-results.
      ENDLOOP.

      APPEND ls_org_plan_json TO ls_info_record-to_purginforecdorgplantdata-results.
    ENDLOOP.

    rv_json = xco_cp_json=>data->from_abap( ls_info_record )->to_string( ).

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

    DATA(lv_uri) = '/sap/opu/odata/sap/API_INFORECORD_PROCESS_SRV/A_PurchasingInfoRecord'.

    DATA(ls_response) = zcl_api_http_client=>post(
      iv_path = lv_uri
      iv_body = lv_json_string ).

    IF ls_response-is_success = abap_false.
      APPEND VALUE #( message = ls_response-message ) TO rt_error.
      RETURN.
    ENDIF.

    " Respuesta OData V2: viene envuelta en { "d": { ... } }.
    " TODO: confirmar la sintaxis exacta de navegación de XCO_CP_JSON en
    " tu release (el método member() puede variar de nombre); si falla,
    " es el único punto a ajustar en todo este método.
    TRY.
        xco_cp_json=>data->from_string( ls_response-body )
          ->member( 'd' )
          ->write_to( REF #( ev_po_response ) ).

        ev_purchasinginforecord = ev_po_response-purchasinginforecord.

      CATCH cx_root INTO DATA(lx_parse_error).
        APPEND VALUE #( message = lx_parse_error->get_text( ) ) TO rt_error.
    ENDTRY.

  ENDMETHOD.


  METHOD get_info_record_list.

    DATA(lv_filter) = |Supplier eq '{ is_update_info_record-supplier }' | &&
                       |and Material eq '{ is_update_info_record-material }'|.

    DATA(lv_uri) = '/sap/opu/odata/sap/API_INFORECORD_PROCESS_SRV/A_PurchasingInfoRecord' &&
      |?$filter={ lv_filter }&$expand=to_PurgInforecdOrgPlantData&$format=json|.

    DATA(ls_response) = zcl_api_http_client=>get( lv_uri ).

    IF ls_response-is_success = abap_false OR ls_response-body IS INITIAL.
      RETURN.
    ENDIF.

    TRY.
        xco_cp_json=>data->from_string( ls_response-body )
          ->member( 'd' )
          ->member( 'results' )
          ->write_to( REF #( rt_info_record ) ).
      CATCH cx_root.
        CLEAR rt_info_record.
    ENDTRY.

  ENDMETHOD.


  METHOD exists_info_record.
"---------------------------------------------------------------
" Chequeo LOCAL (sin HTTP) contra las vistas CDS liberadas ya
" confirmadas en tu sistema:
"   I_PURCHASINGINFORECORDTP        (cabecera: SUPPLIER, MATERIAL)
"   I_PURGINFORECDORGPLANTDATA      (org/planta: MATERIALPLANNEDDELIVERYDURN = APLFZ)
"---------------------------------------------------------------

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

    DATA(lv_uri) = |/sap/opu/odata/sap/API_INFORECORD_PROCESS_SRV/A_PurgInfoRecdOrgPlantData| &&
                   |(PurchasingInfoRecord='{ iv_purchasinginforecord }',| &&
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

    DATA(ls_response) = zcl_api_http_client=>patch(
      iv_path = lv_uri
      iv_body = lv_body ).

    IF ls_response-is_success = abap_false.
      APPEND VALUE #( message = ls_response-message ) TO rt_error.
    ENDIF.

  ENDMETHOD.
