CLASS zcl_sd_sales_org DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES: BEGIN OF t_def,
             vkorg TYPE tvko-vkorg,
             bukrs TYPE tvko-bukrs,
             waers TYPE tvko-waers,
           END OF t_def,

           BEGIN OF t_vkorg,
             vkorg TYPE vkorg,
           END OF t_vkorg,

           tt_vkorg     TYPE STANDARD TABLE OF t_vkorg WITH DEFAULT KEY,

           tt_vkorg_rng TYPE RANGE OF vkorg,
           tt_waers_rng TYPE RANGE OF waers.

    DATA: go_company TYPE REF TO zcl_fi_company READ-ONLY,
          gs_def     TYPE t_def                 READ-ONLY.

    CLASS-METHODS: get_instance
      IMPORTING iv_vkorg      TYPE vkorg
      RETURNING VALUE(ro_obj) TYPE REF TO zcl_sd_sales_org
      RAISING   zcx_fi_company_code_def
                zcx_sd_sales_org_def,

      get_sales_org_list
        IMPORTING it_vkorg_rng    TYPE tt_vkorg_rng OPTIONAL
                  it_waers_rng    TYPE tt_waers_rng OPTIONAL
        RETURNING VALUE(rt_vkorg) TYPE tt_vkorg,

      get_sales_org_range
        IMPORTING it_vkorg_rng        TYPE tt_vkorg_rng OPTIONAL
                  it_waers_rng        TYPE tt_waers_rng OPTIONAL
        RETURNING VALUE(rt_vkorg_rng) TYPE tt_vkorg_rng.

    METHODS get_distribution_channels RETURNING VALUE(rt_vtweg) TYPE tdt_vtweg.

    METHODS get_text                  RETURNING VALUE(result)   TYPE tvkot-vtext.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF t_multiton,
        vkorg TYPE vkorg,
        obj   TYPE REF TO zcl_sd_sales_org,
      END OF t_multiton,

      tt_multiton TYPE HASHED TABLE OF t_multiton
        WITH UNIQUE KEY primary_key
        COMPONENTS vkorg.

    CONSTANTS c_tabname_tvko TYPE tabname VALUE 'TVKO'.

    CLASS-DATA gt_multiton TYPE tt_multiton.

    DATA: gt_distribution_channels TYPE tdt_vtweg,
          gv_dist_channels_read    TYPE abap_bool,
          gv_vtext                 TYPE tvkot-vtext,
          gv_vtext_read            TYPE abap_bool.

ENDCLASS.


CLASS zcl_sd_sales_org IMPLEMENTATION.
  METHOD get_distribution_channels.
    IF gv_dist_channels_read = abap_false.
      SELECT vtweg FROM tvkov WHERE vkorg = @gs_def-vkorg INTO TABLE @gt_distribution_channels.
      gv_dist_channels_read = abap_true.
    ENDIF.

    rt_vtweg = gt_distribution_channels.
  ENDMETHOD.

  METHOD get_text.
    IF gv_vtext_read = abap_false.
      SELECT SINGLE FROM tvkot
             FIELDS vtext
             WHERE spras = @sy-langu
               AND vkorg = @gs_def-vkorg
             INTO @gv_vtext.

      gv_vtext_read = abap_true.
    ENDIF.

    result = gv_vtext.
  ENDMETHOD.

  METHOD get_instance.
    ASSIGN gt_multiton[ KEY primary_key
      COMPONENTS vkorg = iv_vkorg ]
           TO FIELD-SYMBOL(<ls_multiton>).

    IF sy-subrc <> 0.

      DATA(ls_multiton) = VALUE t_multiton( vkorg = iv_vkorg ).
      ls_multiton-obj = NEW #( ).

      SELECT SINGLE vkorg, bukrs, waers
             INTO CORRESPONDING FIELDS OF @ls_multiton-obj->gs_def
             FROM tvko
             WHERE vkorg = @ls_multiton-vkorg.

      IF sy-subrc <> 0.

        DATA(lo_tc) = NEW zcx_bc_table_content( textid   = zcx_bc_table_content=>entry_missing
                                                objectid = CONV #( iv_vkorg )
                                                tabname  = c_tabname_tvko ).

        RAISE EXCEPTION NEW zcx_sd_sales_org_def( previous = lo_tc
                                                  vkorg    = iv_vkorg ).

      ENDIF.

      ls_multiton-obj->go_company = zcl_fi_company=>get_instance( ls_multiton-obj->gs_def-bukrs ).

      INSERT ls_multiton INTO TABLE gt_multiton ASSIGNING <ls_multiton>.

    ENDIF.

    ro_obj = <ls_multiton>-obj.
  ENDMETHOD.

  METHOD get_sales_org_list.
    SELECT tvko~vkorg FROM tvko
           WHERE vkorg IN @it_vkorg_rng
             AND waers IN @it_waers_rng
           INTO TABLE @rt_vkorg.
  ENDMETHOD.

  METHOD get_sales_org_range.
    rt_vkorg_rng = VALUE #( FOR _vkorg IN get_sales_org_list( it_vkorg_rng = it_vkorg_rng
                                                              it_waers_rng = it_waers_rng )
                            ( sign   = zcl_bc_ddic_toolkit=>c_sign_i
                              option = zcl_bc_ddic_toolkit=>c_option_eq
                              low    = _vkorg ) ).
  ENDMETHOD.
ENDCLASS.