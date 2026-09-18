"! Factory liberada (C1 + Use in Cloud Development), junto con
"! ZIF_S4_REG_INFO_DEST. Es lo único que el código ABAP Cloud
"! consumidor conoce - nunca referencia ZCL_S4_REG_INFO_DEST
"! (la implementación) directamente.
"!
"! Patrón documentado por SAP (Tier 2 - Mitigating Missing Released
"! SAP APIs): interfaz + clase factory se liberan; la clase de
"! implementación concreta permanece sin liberar.
CLASS zcl_s4_reg_info_dest_factory DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    CLASS-METHODS create
      RETURNING VALUE(ro_instance) TYPE REF TO zif_s4_reg_info_dest.

ENDCLASS.


CLASS zcl_s4_reg_info_dest_factory IMPLEMENTATION.

  METHOD create.
    ro_instance = NEW zcl_s4_reg_info_dest( ).
  ENDMETHOD.

ENDCLASS.
