"! Class test (chạy bằng F9 trong ADT): hủy 2 item của CÙNG 1 chứng từ bằng EML I_MaterialDocumentTP
"! trong 1 lần commit, rồi in ra chứng từ hủy được sinh ra -> xem BO chuẩn có gom vào 1 chứng từ không.
"! Lưu ý: chạy là hủy thật 2 item đã khai báo.
CLASS zcl_m_can_matdoc_eml_test DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.



CLASS zcl_m_can_matdoc_eml_test IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.
    " Điền chứng từ + 2 item chưa hủy trước khi chạy (để trống thì không làm gì)
    CONSTANTS:
      c_year     TYPE zi_m_can_matdoc-MaterialDocumentYear VALUE '2026',
      c_document TYPE zi_m_can_matdoc-MaterialDocument     VALUE '5000002905',
      c_item_1   TYPE zi_m_can_matdoc-MaterialDocumentItem VALUE '0002',
      c_item_2   TYPE zi_m_can_matdoc-MaterialDocumentItem VALUE '0003'.

    IF c_year IS INITIAL OR c_document IS INITIAL OR c_item_1 IS INITIAL OR c_item_2 IS INITIAL.
      out->write( `Chưa điền chứng từ test` ).
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF I_MaterialDocumentTP FORWARDING PRIVILEGED
      ENTITY MaterialDocumentItem
      EXECUTE Cancel FROM VALUE #( ( MaterialDocumentYear = c_year
                                     MaterialDocument     = c_document
                                     MaterialDocumentItem = c_item_1 )
                                   ( MaterialDocumentYear = c_year
                                     MaterialDocument     = c_document
                                     MaterialDocumentItem = c_item_2 ) )
      FAILED   DATA(ls_failed)
      REPORTED DATA(ls_reported).

    LOOP AT ls_reported-materialdocumentitem ASSIGNING FIELD-SYMBOL(<ls_reported>).
      out->write( |MODIFY: { <ls_reported>-%msg->if_message~get_text( ) }| ).
    ENDLOOP.
    IF ls_failed IS NOT INITIAL.
      out->write( `MODIFY lỗi -> không commit` ).
      ROLLBACK ENTITIES.
      RETURN.
    ENDIF.

    COMMIT ENTITIES RESPONSE OF I_MaterialDocumentTP
      FAILED   DATA(ls_commit_failed)
      REPORTED DATA(ls_commit_reported).

    LOOP AT ls_commit_reported-materialdocumentitem ASSIGNING FIELD-SYMBOL(<ls_commit_reported>).
      out->write( |COMMIT: { <ls_commit_reported>-%msg->if_message~get_text( ) }| ).
    ENDLOOP.
    IF ls_commit_failed IS NOT INITIAL.
      out->write( `COMMIT lỗi` ).
      RETURN.
    ENDIF.

    " Chứng từ hủy trỏ ngược về chứng từ gốc qua ReversedMaterialDocument
    SELECT MaterialDocumentYear, MaterialDocument, MaterialDocumentItem,
           ReversedMaterialDocument, ReversedMaterialDocumentItem
      FROM I_MaterialDocumentItem_2
      WHERE ReversedMaterialDocumentYear = @c_year
        AND ReversedMaterialDocument     = @c_document
      ORDER BY MaterialDocumentYear, MaterialDocument, MaterialDocumentItem
      INTO TABLE @DATA(lt_reversal).

    out->write( `Chứng từ hủy của chứng từ test (cùng số MaterialDocument = đã gom):` ).
    out->write( lt_reversal ).
  ENDMETHOD.

ENDCLASS.

