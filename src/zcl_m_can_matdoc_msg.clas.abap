"! Message của lần chạy Cancel Item cho field ảo Message / MessageCriticality của ZC_M_CAN_MATDOC.
"! Action cancelItem ghi message vào đây; framework đọc lại dòng từ DB để trả kết quả action
"! rồi gọi class này để điền 2 field ảo. Chỉ sống trong 1 request (không lưu DB).
"! Dòng thành công: action để trống Message, class này tự tìm chứng từ hủy vừa được tạo.
CLASS zcl_m_can_matdoc_msg DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_sadl_exit_calc_element_read.

    TYPES:
      BEGIN OF ty_message,
        MaterialDocument     TYPE zi_m_can_matdoc-MaterialDocument,
        MaterialDocumentItem TYPE zi_m_can_matdoc-MaterialDocumentItem,
        MaterialDocumentYear TYPE zi_m_can_matdoc-MaterialDocumentYear,
        Message              TYPE c LENGTH 255,
        MessageCriticality   TYPE int1,
      END OF ty_message.

    CONSTANTS:
      " Màu chữ của field Message: 3 = xanh lá (success), 1 = đỏ (error)
      c_criticality_success TYPE int1 VALUE 3,
      c_criticality_error   TYPE int1 VALUE 1.

    CLASS-METHODS set
      IMPORTING is_message TYPE ty_message.

    CLASS-METHODS get
      IMPORTING iv_material_document      TYPE zi_m_can_matdoc-MaterialDocument
                iv_material_document_item TYPE zi_m_can_matdoc-MaterialDocumentItem
                iv_material_document_year TYPE zi_m_can_matdoc-MaterialDocumentYear
      RETURNING VALUE(rs_message)         TYPE ty_message.

  PRIVATE SECTION.
    CLASS-METHODS get_success_text
      IMPORTING is_message     TYPE ty_message
      RETURNING VALUE(rv_text) TYPE string.

    CLASS-DATA gt_messages TYPE SORTED TABLE OF ty_message
                           WITH UNIQUE KEY MaterialDocument MaterialDocumentItem MaterialDocumentYear.
ENDCLASS.



CLASS zcl_m_can_matdoc_msg IMPLEMENTATION.

  METHOD set.
    DELETE TABLE gt_messages WITH TABLE KEY MaterialDocument     = is_message-MaterialDocument
                                            MaterialDocumentItem = is_message-MaterialDocumentItem
                                            MaterialDocumentYear = is_message-MaterialDocumentYear.
    INSERT is_message INTO TABLE gt_messages.
  ENDMETHOD.


  METHOD get.
    rs_message = VALUE #( gt_messages[ MaterialDocument     = iv_material_document
                                       MaterialDocumentItem = iv_material_document_item
                                       MaterialDocumentYear = iv_material_document_year ] OPTIONAL ).
  ENDMETHOD.


  METHOD if_sadl_exit_calc_element_read~get_calculation_info.
    " Cần key của dòng để tra message
    et_requested_orig_elements = VALUE #( ( `MATERIALDOCUMENT` )
                                          ( `MATERIALDOCUMENTITEM` )
                                          ( `MATERIALDOCUMENTYEAR` ) ).
  ENDMETHOD.


  METHOD if_sadl_exit_calc_element_read~calculate.
    DATA lt_data TYPE STANDARD TABLE OF zc_m_can_matdoc WITH DEFAULT KEY.

    lt_data = CORRESPONDING #( it_original_data ).

    LOOP AT lt_data ASSIGNING FIELD-SYMBOL(<ls_data>).
      DATA(ls_message) = get( iv_material_document      = <ls_data>-MaterialDocument
                              iv_material_document_item = <ls_data>-MaterialDocumentItem
                              iv_material_document_year = <ls_data>-MaterialDocumentYear ).
      <ls_data>-Message            = COND #( WHEN ls_message-MessageCriticality = c_criticality_success
                                                 AND ls_message-Message IS INITIAL
                                                THEN get_success_text( ls_message )
                                                ELSE ls_message-Message ).
      <ls_data>-MessageCriticality = ls_message-MessageCriticality.
    ENDLOOP.

    ct_calculated_data = CORRESPONDING #( lt_data ).
  ENDMETHOD.


  METHOD get_success_text.
    " Chứng từ hủy trỏ ngược về item gốc qua ReversedMaterialDocument
    SELECT MaterialDocumentYear, MaterialDocument, MaterialDocumentItem
      FROM I_MaterialDocumentItem_2
      WHERE ReversedMaterialDocumentYear = @is_message-MaterialDocumentYear
        AND ReversedMaterialDocument     = @is_message-MaterialDocument
        AND ReversedMaterialDocumentItem = @is_message-MaterialDocumentItem
      ORDER BY MaterialDocumentYear DESCENDING, MaterialDocument DESCENDING
      INTO TABLE @DATA(lt_reversal)
      UP TO 1 ROWS.

    rv_text = COND #( WHEN lt_reversal IS NOT INITIAL
                      THEN |Hủy thành công: chứng từ hủy là { lt_reversal[ 1 ]-MaterialDocument } item { lt_reversal[ 1 ]-MaterialDocumentItem } năm { lt_reversal[ 1 ]-MaterialDocumentYear }|
                      ELSE `Hủy thành công` ).
  ENDMETHOD.

ENDCLASS.

