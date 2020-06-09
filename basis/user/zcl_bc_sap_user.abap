CLASS zcl_bc_sap_user DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

    TYPES: BEGIN OF t_bname,
             bname TYPE xubname,
           END OF t_bname,

           tt_bname TYPE STANDARD TABLE OF t_bname WITH DEFAULT KEY,

           BEGIN OF t_bname_text,
             bname TYPE xubname,
             text  TYPE string,
           END OF t_bname_text,

           tt_bname_text TYPE STANDARD TABLE OF t_bname_text WITH DEFAULT KEY,

           BEGIN OF t_bulk_pwdchgdate,
             bname      TYPE xubname,
             pwdchgdate TYPE usr02-pwdchgdate,
           END OF t_bulk_pwdchgdate,

           tt_bulk_pwdchgdate TYPE STANDARD TABLE OF t_bulk_pwdchgdate WITH DEFAULT KEY.

    CONSTANTS: c_actvt_change  TYPE activ_auth VALUE '02',
               c_actvt_display TYPE activ_auth VALUE '03'.

    DATA gv_bname TYPE xubname READ-ONLY.

    CLASS-METHODS:
      check_pwdchgdate_auth
        IMPORTING !iv_actvt TYPE activ_auth
        RAISING   zcx_bc_authorization,

      get_full_name_wo_error
        IMPORTING !iv_bname      TYPE xubname
        RETURNING VALUE(rv_name) TYPE full_name,

      get_instance
        IMPORTING
          !iv_bname             TYPE xubname
          !iv_tolerate_inactive TYPE abap_bool DEFAULT abap_false
        RETURNING
          VALUE(ro_obj)         TYPE REF TO zcl_bc_sap_user
        RAISING
          zcx_bc_user_master_data,

      get_instance_via_email
        IMPORTING
          !iv_email             TYPE ad_smtpadr
          !iv_tolerate_inactive TYPE abap_bool DEFAULT abap_false
        RETURNING
          VALUE(ro_obj)         TYPE REF TO zcl_bc_sap_user
        RAISING
          zcx_bc_table_content
          zcx_bc_user_master_data,

      set_pwd_chg_date_bulk
        IMPORTING
          !it_date    TYPE tt_bulk_pwdchgdate
          !io_log     TYPE REF TO zcl_bc_applog_facade OPTIONAL
        EXPORTING
          !et_success TYPE tt_bname
          !et_failure TYPE tt_bname_text.

    METHODS:
      can_debug_change RETURNING VALUE(rv_can) TYPE abap_bool,

      disable
        IMPORTING
          !iv_lock             TYPE abap_bool DEFAULT abap_true
          !iv_restrict         TYPE abap_bool DEFAULT abap_true
          !iv_restriction_date TYPE dats      DEFAULT sy-datum
          !iv_commit           TYPE abap_bool DEFAULT abap_true
        EXPORTING
          !ev_success          TYPE abap_bool
          !et_return           TYPE bapiret2_tab,

      get_email RETURNING VALUE(rv_email) TYPE ad_smtpadr,

      get_full_name    RETURNING VALUE(rv_name) TYPE full_name,

      get_mobile_number
        IMPORTING !iv_tolerate_missing_number TYPE abap_bool DEFAULT abap_true
        RETURNING VALUE(rv_mobile)            TYPE ad_tlnmbr
        RAISING   zcx_bc_user_master_data,

      get_pwd_chg_date
        IMPORTING !iv_force_fresh TYPE abap_bool
        RETURNING VALUE(rv_date)  TYPE xubcdat,

      get_uname_text   RETURNING VALUE(rv_utext) TYPE ad_namtext,

      is_dialog_user RETURNING VALUE(rv_dialog) TYPE abap_bool,

      set_pwd_chg_date
        IMPORTING !iv_pwdchgdate TYPE usr02-pwdchgdate
        RAISING
                  zcx_bc_authorization
                  zcx_bc_lock.

  PROTECTED SECTION.
  PRIVATE SECTION.

    TYPES: BEGIN OF t_lazy_flag,
             email      TYPE abap_bool,
             full_name  TYPE abap_bool,
             mobile     TYPE abap_bool,
             pwdchgdate TYPE abap_bool,
             uname_text TYPE abap_bool,
           END OF t_lazy_flag,

           BEGIN OF t_lazy_var,
             email      TYPE ad_smtpadr,
             full_name  TYPE full_name,
             mobile     TYPE ad_tlnmbr,
             pwdchgdate TYPE xubcdat,
             uname_text TYPE name_text,
           END OF t_lazy_var,

           BEGIN OF t_multiton,
             bname TYPE xubname,
             obj   TYPE REF TO zcl_bc_sap_user,
           END OF t_multiton,

           tt_multiton TYPE HASHED TABLE OF t_multiton
                       WITH UNIQUE KEY primary_key COMPONENTS bname,

           BEGIN OF t_user_email,
             bname TYPE usr21-bname,
             email TYPE adr6-smtp_addr,
           END OF t_user_email,

           tt_user_email TYPE STANDARD TABLE OF t_user_email WITH EMPTY KEY,

           BEGIN OF t_clazy_flag,
             user_email TYPE abap_bool,
           END OF t_clazy_flag,

           BEGIN OF t_clazy_var,
             user_email TYPE tt_user_email,
           END OF t_clazy_var.

    CONSTANTS: BEGIN OF c_table,
                 adr6 TYPE tabname VALUE 'ADR6',
               END OF c_table,

               c_ustyp_dialog TYPE usr02-ustyp VALUE 'A'.

    CLASS-DATA: gs_clazy_flag TYPE t_clazy_flag,
                gs_clazy_var  TYPE t_clazy_var,
                gt_multiton   TYPE tt_multiton.

    DATA: gs_lazy_flag TYPE t_lazy_flag,
          gs_lazy_var  TYPE t_lazy_var,
          gs_usr02     TYPE usr02.

    CLASS-METHODS:
      dequeue_user
        IMPORTING !iv_bname TYPE xubname,

      enqueue_user
        IMPORTING !iv_bname TYPE xubname
        RAISING   zcx_bc_lock,

      read_all_user_emails_lazy.

    METHODS:
      evaluate_disable_return
        IMPORTING
          !it_return_from_bapi TYPE bapiret2_tab
          !iv_commit           TYPE abap_bool
        CHANGING
          !ct_return_export    TYPE bapiret2_tab
          !cv_success          TYPE abap_bool.

ENDCLASS.



CLASS zcl_bc_sap_user IMPLEMENTATION.

  METHOD can_debug_change.
    AUTHORITY-CHECK OBJECT 'S_DEVELOP'
                    FOR USER gv_bname
                    ID 'ACTVT'    FIELD '02'
                    ID 'OBJTYPE'  FIELD 'DEBUG'
                    ID 'DEVCLASS' DUMMY
                    ID 'OBJNAME'  DUMMY
                    ID 'P_GROUP'  DUMMY.

    rv_can = xsdbool( sy-subrc EQ 0 ).
  ENDMETHOD.


  METHOD check_pwdchgdate_auth.
    AUTHORITY-CHECK OBJECT 'ZBCAOPDC' ID 'ACTVT' FIELD iv_actvt.

    IF sy-subrc NE 0.
      RAISE EXCEPTION TYPE zcx_bc_authorization
        EXPORTING
          textid = zcx_bc_authorization=>no_auth.
    ENDIF.
  ENDMETHOD.


  METHOD dequeue_user.
    CALL FUNCTION 'DEQUEUE_E_USR04'
      EXPORTING
        bname = iv_bname.
  ENDMETHOD.


  METHOD disable.

    CLEAR: ev_success, et_return.

    AUTHORITY-CHECK OBJECT 'S_USER_GRP' ID 'ACTVT' FIELD '05' ##AUTH_FLD_MISSING.
    IF sy-subrc NE 0.
      APPEND VALUE #( type    = zcl_bc_applog_facade=>c_msgty_e
                      message = TEXT-634
                    ) TO et_return.
      RETURN.
    ENDIF.

    ev_success = abap_true.

    IF iv_restrict EQ abap_true.
      DATA(lt_change_return) = VALUE bapiret2_tab(  ).
      DATA(ls_logon)         = VALUE bapilogond( gltgb = iv_restriction_date ).
      DATA(ls_logon_x)       = VALUE bapilogonx( gltgb = abap_true ).

      CALL FUNCTION 'BAPI_USER_CHANGE'
        EXPORTING
          username   = gv_bname
          logondata  = ls_logon
          logondatax = ls_logon_x
        TABLES
          return     = lt_change_return.

      evaluate_disable_return( EXPORTING it_return_from_bapi = lt_change_return
                                         iv_commit           = iv_commit
                               CHANGING  ct_return_export    = et_return
                                         cv_success          = ev_success ).
      IF ev_success EQ abap_false.
        RETURN.
      ENDIF.
    ENDIF.

    IF iv_lock EQ abap_true.
      DATA(lt_lock_return) = VALUE bapiret2_tab(  ).

      CALL FUNCTION 'BAPI_USER_LOCK'
        EXPORTING
          username = gv_bname
        TABLES
          return   = lt_lock_return.

      evaluate_disable_return( EXPORTING it_return_from_bapi = lt_lock_return
                                         iv_commit           = iv_commit
                               CHANGING  ct_return_export    = et_return
                                         cv_success          = ev_success ).
      IF ev_success EQ abap_false.
        RETURN.
      ENDIF.

    ENDIF.

    IF iv_commit EQ abap_true.
      CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
        EXPORTING
          wait = abap_true.
    ENDIF.

  ENDMETHOD.


  METHOD enqueue_user.
    TRY.
        CALL FUNCTION 'ENQUEUE_E_USR04'
          EXPORTING
            bname          = iv_bname
          EXCEPTIONS
            foreign_lock   = 1
            system_failure = 2
            OTHERS         = 3
            ##FM_SUBRC_OK.

        zcx_bc_function_subrc=>raise_if_sysubrc_not_initial( 'ENQUEUE_E_USR04' ).

      CATCH zcx_bc_function_subrc INTO DATA(lo_cx_fsr).
        RAISE EXCEPTION TYPE zcx_bc_lock
          EXPORTING
            textid   = zcx_bc_lock=>locked_by_user
            previous = lo_cx_fsr
            bname    = CONV #( sy-msgv1 ).
    ENDTRY.
  ENDMETHOD.


  METHOD evaluate_disable_return.
    LOOP AT it_return_from_bapi TRANSPORTING NO FIELDS WHERE type IN zcl_bc_applog_facade=>get_crit_msgty_range(  ).
      IF iv_commit EQ abap_true.
        CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
      ENDIF.

      cv_success       = abap_false.
      ct_return_export = it_return_from_bapi.
      RETURN.
    ENDLOOP.
  ENDMETHOD.


  METHOD get_email.

    DATA: lt_return TYPE STANDARD TABLE OF bapiret2,
          lt_smtp   TYPE STANDARD TABLE OF bapiadsmtp.

    IF gs_lazy_flag-email IS INITIAL.

      CALL FUNCTION 'BAPI_USER_GET_DETAIL'
        EXPORTING
          username      = gv_bname
          cache_results = abap_false
        TABLES
          return        = lt_return
          addsmtp       = lt_smtp.

      SORT lt_smtp BY std_no DESCENDING.

      LOOP AT lt_smtp ASSIGNING FIELD-SYMBOL(<ls_smtp>)
           WHERE ( valid_from IS INITIAL ) OR
                 ( valid_from LE sy-datum AND
                   valid_to   GE sy-datum ).

        gs_lazy_var-email = zcl_bc_mail_facade=>cleanse_email_address( <ls_smtp>-e_mail ).
        EXIT.
      ENDLOOP.

      gs_lazy_flag-email = abap_true.
    ENDIF.

    rv_email = gs_lazy_var-email.
  ENDMETHOD.


  METHOD get_full_name.
    IF gs_lazy_flag-full_name EQ abap_false.

      SELECT SINGLE name_first && @space && name_last
        INTO @gs_lazy_var-full_name
        FROM adrp
        WHERE persnumber EQ ( SELECT persnumber FROM usr21 WHERE bname = @gv_bname )
        ##WARN_OK.                                      "#EC CI_NOORDER

      gs_lazy_flag-full_name = abap_true.
    ENDIF.

    rv_name = gs_lazy_var-full_name.
  ENDMETHOD.


  METHOD get_full_name_wo_error.
    TRY.
        rv_name = get_instance( iv_bname )->get_full_name( ).
      CATCH cx_root ##no_handler.
    ENDTRY.
  ENDMETHOD.


  METHOD get_instance.

    ASSIGN gt_multiton[ KEY primary_key
                        COMPONENTS bname = iv_bname
                      ] TO FIELD-SYMBOL(<ls_multiton>).

    IF sy-subrc NE 0.
      DATA(ls_multiton) = VALUE t_multiton( bname = iv_bname ).

      SELECT SINGLE * FROM usr02
             WHERE bname EQ @ls_multiton-bname
             INTO @DATA(ls_usr02).

      IF sy-subrc NE 0.
        RAISE EXCEPTION TYPE zcx_bc_user_master_data
          EXPORTING
            textid = zcx_bc_user_master_data=>user_unknown
            uname  = ls_multiton-bname.
      ENDIF.

      IF ( ( ls_usr02-gltgv IS NOT INITIAL AND ls_usr02-gltgv GT sy-datum ) OR
           ( ls_usr02-gltgb IS NOT INITIAL AND ls_usr02-gltgb LT sy-datum ) ) AND
         iv_tolerate_inactive EQ abap_false.

        RAISE EXCEPTION TYPE zcx_bc_user_master_data
          EXPORTING
            textid = zcx_bc_user_master_data=>user_inactive
            uname  = ls_multiton-bname.
      ENDIF.

      ls_multiton-obj = NEW #( ).
      ls_multiton-obj->gv_bname = ls_multiton-bname.
      ls_multiton-obj->gs_usr02 = ls_usr02.

      INSERT ls_multiton INTO TABLE gt_multiton ASSIGNING <ls_multiton>.
    ENDIF.

    ro_obj = <ls_multiton>-obj.
  ENDMETHOD.


  METHOD get_instance_via_email.
    read_all_user_emails_lazy( ).
    DATA(lv_cleansed_email) = zcl_bc_mail_facade=>cleanse_email_address( iv_email ).
    DATA(lt_users)          = VALUE rke_userid( ).

    LOOP AT gs_clazy_var-user_email ASSIGNING FIELD-SYMBOL(<ls_user_email>).
      CHECK zcl_bc_text_toolkit=>are_texts_same_ignoring_case(
                iv_text1 = lv_cleansed_email
                iv_text2 = <ls_user_email>-email ).

      APPEND <ls_user_email>-bname TO lt_users.
    ENDLOOP.

    CASE lines( lt_users ).
      WHEN 0.
        RAISE EXCEPTION TYPE zcx_bc_table_content
          EXPORTING
            textid   = zcx_bc_table_content=>no_suitable_entry_found
            objectid = CONV #( iv_email )
            tabname  = c_table-adr6.

      WHEN 1.
        ro_obj = get_instance( iv_bname             = lt_users[ 1 ]
                               iv_tolerate_inactive = iv_tolerate_inactive ).

      WHEN OTHERS.
        RAISE EXCEPTION TYPE zcx_bc_table_content
          EXPORTING
            textid   = zcx_bc_table_content=>multiple_entries_for_key
            objectid = CONV #( iv_email )
            tabname  = c_table-adr6.
    ENDCASE.

  ENDMETHOD.


  METHOD get_mobile_number.

    IF gs_lazy_flag-mobile EQ abap_false.

      SELECT SINGLE adr2~tel_number
             FROM usr21
                 INNER JOIN adr2 ON adr2~addrnumber EQ usr21~addrnumber AND
                                    adr2~persnumber EQ usr21~persnumber
             WHERE usr21~bname      EQ @gv_bname AND
                   adr2~date_from  LE @sy-datum AND
                   adr2~tel_number NE @space
             INTO @gs_lazy_var-mobile.
                                                        "#EC CI_NOORDER

      gs_lazy_flag-mobile = abap_true.
    ENDIF.

    IF gs_lazy_var-mobile IS INITIAL AND
       iv_tolerate_missing_number EQ abap_false.

      RAISE EXCEPTION TYPE zcx_bc_user_master_data
        EXPORTING
          textid = zcx_bc_user_master_data=>mobile_missing
          uname  = gv_bname.
    ENDIF.

    rv_mobile = gs_lazy_var-mobile.
  ENDMETHOD.


  METHOD get_pwd_chg_date.
    gs_lazy_flag-pwdchgdate = SWITCH #( iv_force_fresh WHEN abap_true THEN abap_false ).

    IF gs_lazy_flag-pwdchgdate EQ abap_false.

      SELECT SINGLE pwdchgdate FROM usr02
             WHERE bname EQ @gv_bname
             INTO @gs_lazy_var-pwdchgdate.

      gs_lazy_flag-pwdchgdate = abap_true.
    ENDIF.

    rv_date = gs_lazy_var-pwdchgdate.
  ENDMETHOD.


  METHOD get_uname_text.
    IF gs_lazy_flag-uname_text EQ abap_false.
      SELECT SINGLE name_textc
        INTO @gs_lazy_var-uname_text
        FROM user_addr
        WHERE bname EQ @gv_bname
        ##WARN_OK.                                      "#EC CI_NOORDER

      gs_lazy_flag-uname_text = abap_true.
    ENDIF.

    rv_utext = gs_lazy_var-uname_text.
  ENDMETHOD.


  METHOD is_dialog_user.
    rv_dialog = xsdbool( gs_usr02-ustyp = c_ustyp_dialog ).
  ENDMETHOD.


  METHOD read_all_user_emails_lazy.
    CHECK gs_clazy_flag-user_email EQ abap_false.

    SELECT DISTINCT usr21~bname, adr6~smtp_addr
           FROM adr6
           INNER JOIN usr21 ON usr21~persnumber EQ adr6~persnumber AND
                               usr21~addrnumber EQ adr6~addrnumber
           INTO CORRESPONDING FIELDS OF TABLE @gs_clazy_var-user_email.

    LOOP AT gs_clazy_var-user_email ASSIGNING FIELD-SYMBOL(<ls_user_email>).
      <ls_user_email>-email = zcl_bc_mail_facade=>cleanse_email_address( <ls_user_email>-email ).
    ENDLOOP.

    gs_clazy_flag-user_email = abap_true.
  ENDMETHOD.


  METHOD set_pwd_chg_date.

    DATA: lo_obj TYPE REF TO object,
          lo_obs TYPE REF TO zif_bc_pwdchgdate_observer.

    " Yetki
    check_pwdchgdate_auth( c_actvt_change ).

    " Güncelleme öncesi not alınması gereken bilgiler
    DATA(lv_old) = get_pwd_chg_date( abap_true ).

    " Güncelleme

    enqueue_user( gv_bname ).
    UPDATE usr02 SET pwdchgdate = @iv_pwdchgdate WHERE bname EQ @gv_bname.
    gs_usr02-pwdchgdate = iv_pwdchgdate.
    dequeue_user( gv_bname ).

    " Observer Design Pattern

    TRY.
        DATA(lt_observer) = zcl_bc_abap_class=>get_instance( zif_bc_pwdchgdate_observer=>c_clsname_me )->get_instanceable_subclasses( ).
      CATCH cx_root ##no_handler .
    ENDTRY.

    LOOP AT lt_observer ASSIGNING FIELD-SYMBOL(<ls_observer>).

      TRY.
          CREATE OBJECT lo_obj TYPE (<ls_observer>-clsname).
          lo_obs ?= lo_obj.

          lo_obs->pwdchgdate_changed_manually(
              iv_bname = gv_bname
              iv_old   = lv_old
              iv_new   = iv_pwdchgdate ).

        CATCH cx_root ##no_handler.
      ENDTRY.

    ENDLOOP.
  ENDMETHOD.


  METHOD set_pwd_chg_date_bulk.

    CLEAR: et_success,
           et_failure.

    LOOP AT it_date ASSIGNING FIELD-SYMBOL(<ls_date>).

      TRY.
          get_instance( <ls_date>-bname )->set_pwd_chg_date( <ls_date>-pwdchgdate ).
          APPEND VALUE #( bname = <ls_date>-bname ) TO et_success.
        CATCH cx_root INTO DATA(lo_cx_root).

          IF io_log IS NOT INITIAL.
            io_log->add_exception( lo_cx_root ).
          ENDIF.

          APPEND VALUE #( bname = <ls_date>-bname
                          text  = lo_cx_root->get_text( )
                        ) TO et_failure.
      ENDTRY.

    ENDLOOP.

  ENDMETHOD.
ENDCLASS.