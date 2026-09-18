"! Cliente HTTP genérico, ABAP Cloud (language version: ABAP for Cloud
"! Development). No es específico de Info Records: cualquier consumo
"! OData/HTTP saliente puede reutilizarlo.
"!
"! Maneja el ciclo CSRF requerido por servicios OData V2 (como
"! API_INFORECORD_PROCESS_SRV) para operaciones de escritura:
"!   1) GET con header X-CSRF-Token: Fetch
"!   2) Reutiliza la MISMA instancia de cliente (cookies de sesión) para
"!      el POST/PATCH real, enviando el token recibido.
CLASS zcl_api_http_client DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES: BEGIN OF ty_response,
             status_code TYPE i,
             body        TYPE string,
             is_success  TYPE abap_bool,
             message     TYPE string,
           END OF ty_response.

    "! GET simple, sin manejo de CSRF (no aplica para lectura).
    "! @parameter iv_path | Path relativo al servicio, ej.
    "!   '/sap/opu/odata/sap/API_INFORECORD_PROCESS_SRV/A_PurgInfoRecdOrgPlantData'
    CLASS-METHODS get
      IMPORTING iv_path           TYPE string
      RETURNING VALUE(rs_response) TYPE ty_response.

    "! POST (create) con ciclo CSRF completo.
    CLASS-METHODS post
      IMPORTING iv_path            TYPE string
                iv_body            TYPE string
      RETURNING VALUE(rs_response) TYPE ty_response.

    "! PATCH (update) con ciclo CSRF completo.
    CLASS-METHODS patch
      IMPORTING iv_path            TYPE string
                iv_body            TYPE string
      RETURNING VALUE(rs_response) TYPE ty_response.

  PRIVATE SECTION.

    CLASS-METHODS execute_write
      IMPORTING iv_method          TYPE string
                iv_path            TYPE string
                iv_body            TYPE string
      RETURNING VALUE(rs_response) TYPE ty_response.

    CLASS-METHODS fetch_csrf_token
      IMPORTING io_http_client   TYPE REF TO if_web_http_client
                iv_path          TYPE string
      RETURNING VALUE(rv_token)  TYPE string.

ENDCLASS.


CLASS zcl_api_http_client IMPLEMENTATION.

  METHOD get.

    TRY.
        DATA(lo_destination) = NEW zcl_s4_reg_info_dest( )->zif_s4_reg_info_dest~get_destination( ).
        DATA(lo_http_client) = cl_web_http_client_manager=>create_by_http_destination( lo_destination ).

        DATA(lo_request) = lo_http_client->get_http_request( ).
        lo_request->set_header_field( i_name = 'Accept' i_value = 'application/json' ).
        lo_request->set_uri_path( iv_path ).

        DATA(lo_response) = lo_http_client->execute( if_web_http_client=>get ).

        rs_response-status_code = lo_response->get_status( )-code.
        rs_response-body        = lo_response->get_text( ).
        rs_response-is_success  = xsdbool( rs_response-status_code BETWEEN 200 AND 299 ).

      CATCH cx_root INTO DATA(lx_get_error).
        rs_response-is_success = abap_false.
        rs_response-message    = lx_get_error->get_text( ).
    ENDTRY.

  ENDMETHOD.


  METHOD post.
    rs_response = execute_write(
      iv_method = if_web_http_client=>post
      iv_path   = iv_path
      iv_body   = iv_body ).
  ENDMETHOD.


  METHOD patch.
    rs_response = execute_write(
      iv_method = if_web_http_client=>patch
      iv_path   = iv_path
      iv_body   = iv_body ).
  ENDMETHOD.


  METHOD execute_write.

    TRY.
        DATA(lo_destination) = NEW zcl_s4_reg_info_dest( )->zif_s4_reg_info_dest~get_destination( ).
        DATA(lo_http_client) = cl_web_http_client_manager=>create_by_http_destination( lo_destination ).

        " 1) Ciclo CSRF - misma instancia de cliente conserva las cookies
        DATA(lv_csrf_token) = fetch_csrf_token(
          io_http_client = lo_http_client
          iv_path        = iv_path ).

        IF lv_csrf_token IS INITIAL.
          rs_response-is_success = abap_false.
          rs_response-message    = 'No fue posible obtener el token CSRF'.
          RETURN.
        ENDIF.

        " 2) Llamada real reutilizando el mismo cliente
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

      CATCH cx_root INTO DATA(lx_write_error).
        rs_response-is_success = abap_false.
        rs_response-message    = lx_write_error->get_text( ).
    ENDTRY.

  ENDMETHOD.


  METHOD fetch_csrf_token.

    DATA(lo_token_request) = io_http_client->get_http_request( ).
    lo_token_request->set_header_field( i_name = 'X-CSRF-Token' i_value = 'Fetch' ).
    lo_token_request->set_uri_path( iv_path ).

    DATA(lo_token_response) = io_http_client->execute( if_web_http_client=>get ).

    rv_token = lo_token_response->get_header_field( 'X-CSRF-Token' ).

  ENDMETHOD.

ENDCLASS.
