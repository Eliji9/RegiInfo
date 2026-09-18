"! Wrapper NO ABAP Cloud (language version: Standard).
"! Implementa ZIF_S4_REG_INFO_DEST (la interfaz es lo liberado C1;
"! esta clase concreta es su implementación por defecto).
"! Resuelve el destino SM59 'S4_REG_INFO' a una referencia
"! IF_HTTP_DESTINATION, ya que CL_OUTBOUND_PROVIDER_HTTP no está
"! liberada para el language version ABAP for Cloud Development.
CLASS zcl_s4_reg_info_dest DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_s4_reg_info_dest.

    "! Nombre del destino SM59. Literal a propósito (decisión de
    "! diseño confirmada: sin tabla Z de configuración).
    CONSTANTS gc_destination TYPE string VALUE 'S4_REG_INFO'.

ENDCLASS.


CLASS zcl_s4_reg_info_dest IMPLEMENTATION.

  METHOD zif_s4_reg_info_dest~get_destination.
    ro_destination = cl_outbound_provider_http=>create_by_destination( gc_destination ).
  ENDMETHOD.

ENDCLASS.
