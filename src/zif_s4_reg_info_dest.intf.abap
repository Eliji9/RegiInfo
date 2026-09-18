"! Interfaz liberada (C1) del wrapper de destino SM59.
"! El código ABAP Cloud depende de esta interfaz, no de la clase
"! concreta ZCL_S4_REG_INFO_DEST - permite sustituirla por un doble
"! de prueba en tests unitarios sin tocar el consumidor.
INTERFACE zif_s4_reg_info_dest
  PUBLIC.

  METHODS get_destination
    RETURNING VALUE(ro_destination) TYPE REF TO if_http_destination
    RAISING   cx_http_dest_provider_error.

ENDINTERFACE.
