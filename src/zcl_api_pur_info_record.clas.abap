"! Clase única: destino SM59, cliente HTTP y lógica de negocio de
"! Info Records, todo consolidado (sin wrapper interfaz/factory).
"!
"! ADVERTENCIA DE COMPLIANCE: el método GET_DESTINATION llama a
"! CL_OUTBOUND_PROVIDER_HTTP=>create_by_destination( ), que NO está
"! liberada para ABAP for Cloud Development. Esta clase no pasará el
"! chequeo ATC "Cloud Development" sin una exención (pragma) sobre
"! esa llamada puntual. Decisión de diseño explícita: sin wrapper
"! formal (interfaz + factory) separado.
"!
"! Se agregan aquí, respecto a la versión anterior:
"!   - GET_DESTINATION, HTTP_GET, HTTP_POST, HTTP_PATCH  (antes en
"!     ZCL_S4_REG_INFO_DEST / ZCL_API_HTTP_CLIENT, ahora privados aquí)
"!   - EXISTS_INFO_RECORD, UPDATE_INFO_RECORD            (nuevos)
"!   - CREATE_JSON, CREATE_INFO_RECORD, GET_INFO_RECORD_LIST (ajustados)
CLASS zcl_api_pur_info_record DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    "! (Aquí van los TYPES ya existentes en tu clase: ty_pricingcndnrecdscale,
    "! ty_recdsuplmntprcgcndn, ty_info_rec_prcgcndn, ty_info_rec_prcg_validity,
    "! ty_info_rec_org_plan_data(_json), ty_info_rec_text, ty_info_record,
    "! ty_update_info_record, ty_error(_detail) y sus TT_/results wrappers.
    "! No se repiten aquí para no duplicar - van sin cambios.)

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
      RETURNING VALUE(rv_json)            TYPE string.

    CLASS-METHODS get_info_record_list
      IMPORTING is_update_info_record TYPE ty_update_info_record
      RETURNING VALUE(rt_info_record) TYPE tt_info_record.

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

    TYPES: BEGIN OF ty_http_response,
             status_code TYPE i,
             body        TYPE string,
             is_success  TYPE abap_bool,
             message     TYPE string,
           END OF ty_http_response.

    CONSTANTS gc_destination TYPE string VALUE 'S4_REG_INFO'.
    CONSTANTS gc_uri_header  TYPE string VALUE
      '/sap/opu/odata/sap/API_INFORECORD_PROCESS_SRV/A_PurchasingInfoRecord'.
    CONSTANTS gc_uri_org_plant TYPE string VALUE
      '/sap/opu/odata/sap/API_INFORECORD_PROCESS_SRV/A_PurgInfoRecdOrgPlantData'.

    "! Resuelve el destino SM59. NO liberado para ABAP Cloud - requiere
    "! exención de ATC sobre esta llamada puntual.
    CLASS-METHODS get_destination
      RETURNING VALUE(ro_destination) TYPE REF TO if_http_destination
      RAISING   cx_http_dest_provider_error.

    CLASS-METHODS http_get
      IMPORTING iv_path            TYPE string
      RETURNING VALUE(rs_response) TYPE ty_http_response.

    CLASS-METHODS http_post
      IMPORTING iv_path            TYPE string
                iv_body            TYPE string
      RETURNING VALUE(rs_response) TYPE ty_http_response.

    CLASS-METHODS http_patch
      IMPORTING iv_path            TYPE string
                iv_body            TYPE string
      RETURNING VALUE(rs_response) TYPE ty_http_response.

    CLASS-METHODS execute_write
      IMPORTING iv_method          TYPE string
                iv_path            TYPE string
                iv_body            TYPE string
      RETURNING VALUE(rs_response) TYPE ty_http_response.

ENDCLASS.


CLASS zcl_api_pur_info_record IMPLEMENTATION.

  " ---------------------------------------------------------------
  " Destino / HTTP (antes en ZCL_S4_REG_INFO_DEST / ZCL_API_HTTP_CLIENT)
  " ---------------------------------------------------------------

  METHOD get_destination.
    "#EC CI_NOTIFIER   " TODO: reemplazar por el pragma real de exención ATC
    ro_destination = cl_outbound_provider_http=>create_by_destination( gc_destination ).
  ENDMETHOD.


  METHOD http_get.
    TRY.
        DATA(lo_destination) = get_destination( ).
        DATA(lo_http_client)  = cl_web_http_client_manager=>create_by_http_destination( lo_destination ).

        DATA(lo_request) = lo_http_client->get_http_request( ).
        lo_request->set_header_field( i_name = 'Accept' i_value = 'application/json' ).
        lo_request->set_uri_path( iv_path ).

        DATA(lo_response) = lo_http_client->execute( if_web_http_client=>get ).

        rs_response-status_code = lo_response->get_status( )-code.
        rs_response-body        = lo_response->get_text( ).
        rs_response-is_success  = xsdbool( rs_response-status_code BETWEEN 200 AND 299 ).

      CATCH cx_root INTO DATA(lx_error).
        rs_response-is_success = abap_false.
        rs_response-message    = lx_error->get_text( ).
    ENDTRY.
  ENDMETHOD.


  METHOD http_post.
    rs_response = execute_write(
      iv_method = if_web_http_client=>post
      iv_path   = iv_path
      iv_body   = iv_body ).
  ENDMETHOD.


  METHOD http_patch.
    rs_response = execute_write(
      iv_method = if_web_http_client=>patch
      iv_path   = iv_path
      iv_body   = iv_body ).
  ENDMETHOD.


  METHOD execute_write.
    TRY.
        DATA(lo_destination) = get_destination( ).
        DATA(lo_http_client)  = cl_web_http_client_manager=>create_by_http_destination( lo_destination ).

        " Ciclo CSRF (obligatorio para escritura OData V2)
        DATA(lo_token_request) = lo_http_client->get_http_request( ).
        lo_token_request->set_header_field( i_name = 'X-CSRF-Token' i_value = 'Fetch' ).
        lo_token_request->set_uri_path( iv_path ).
        DATA(lo_token_response) = lo_http_client->execute( if_web_http_client=>get ).
        DATA(lv_csrf_token) = lo_token_response->get_header_field( 'X-CSRF-Token' ).

        IF lv_csrf_token IS INITIAL.
          rs_response-is_success = abap_false.
          rs_response-message    = 'No fue posible obtener el token CSRF'.
          RETURN.
        ENDIF.

        DATA(lo_request) = lo_http_client->get_http_request( ).
        lo_request->set_header_field( i_name = 'X-CSRF-Token' i_value = lv_csrf_token ).
        lo_request->set_header_field( i_name = 'Content-Type' i_value = 'application/json' ).
        lo_request->set_header_field( i_name = 'Accept' i_value = 'application/json' ).
        lo_request->set_uri_path( iv_path ).
        lo_request->set_text( iv_body ).

        DATA(lo_response) = lo_http_client->execute( iv_method ).

        rs_response-status_code = lo_response->get_status( )-code.
        rs_response-body        = lo_response->get_text( ).
        rs_response-is_success  = xsdbool( rs_response-status_code BETWEEN 200 AND 299 ).

        IF rs_response-is_success = abap_false.
          rs_response-message = rs_response-body.
        ENDIF.

      CATCH cx_root INTO DATA(lx_error).
        rs_response-is_success = abap_false.
        rs_response-message    = lx_error->get_text( ).
    ENDTRY.
  ENDMETHOD.


  " ---------------------------------------------------------------
  " Lógica de negocio (igual que la versión anterior, sin cambios
  " de fondo - solo las llamadas ahora son a los métodos privados
  " de arriba en vez de a ZCL_API_HTTP_CLIENT)
  " ---------------------------------------------------------------

  METHOD create_json.
    " SUPUESTO A VERIFICAR: claves de enlace CONDITIONRECORD (+
    " CONDITIONSEQUENTIALNUMBER) y PURCHASINGINFORECORD +
    " PURCHASINGORGANIZATION + PLANT - ver nota en entregas anteriores.

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

    DATA(ls_response) = http_post(
      iv_path = gc_uri_header
      iv_body = lv_json_string ).

    IF ls_response-is_success = abap_false.
      APPEND VALUE #( message = ls_response-message ) TO rt_error.
      RETURN.
    ENDIF.

    " TODO: confirmar sintaxis exacta de navegación de XCO_CP_JSON en tu
    " release para leer la respuesta (envuelta en {"d": {...}}).
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

    DATA(lv_uri) = gc_uri_header &&
      |?$filter={ lv_filter }&$expand=to_PurgInforecdOrgPlantData&$format=json|.

    DATA(ls_response) = http_get( lv_uri ).

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
    " Chequeo local vía CDS liberadas - sin HTTP.
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
    DATA(lv_uri) = |{ gc_uri_org_plant }(PurchasingInfoRecord='{ iv_purchasinginforecord }',| &&
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

    DATA(ls_response) = http_patch(
      iv_path = lv_uri
      iv_body = lv_body ).

    IF ls_response-is_success = abap_false.
      APPEND VALUE #( message = ls_response-message ) TO rt_error.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
