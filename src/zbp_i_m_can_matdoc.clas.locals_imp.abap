CLASS lhc_matdoc DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR MatDoc RESULT result.

    METHODS read FOR READ
      IMPORTING keys FOR READ MatDoc RESULT result.

    METHODS lock FOR LOCK
      IMPORTING keys FOR LOCK MatDoc.

    METHODS cancelItem FOR MODIFY
      IMPORTING keys FOR ACTION MatDoc~cancelItem RESULT result.

    METHODS cancelHeader FOR MODIFY
      IMPORTING keys FOR ACTION MatDoc~cancelHeader RESULT result.

    " Kết quả API hủy header theo từng chứng từ trong request hiện tại: app gửi tất cả dòng của chứng từ
    " để dòng nào cũng có Message, nhưng API chỉ được gọi 1 lần cho mỗi chứng từ
    TYPES: BEGIN OF ty_header_result,
             MaterialDocumentYear TYPE zi_m_can_matdoc-MaterialDocumentYear,
             MaterialDocument     TYPE zi_m_can_matdoc-MaterialDocument,
             result               TYPE zcl_m_can_matdoc_api=>ty_result,
           END OF ty_header_result.
    CLASS-DATA header_results TYPE STANDARD TABLE OF ty_header_result WITH EMPTY KEY.

ENDCLASS.

CLASS lhc_matdoc IMPLEMENTATION.

  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD read.
    SELECT * FROM zi_m_can_matdoc
      FOR ALL ENTRIES IN @keys
      WHERE MaterialDocument     = @keys-MaterialDocument
        AND MaterialDocumentItem = @keys-MaterialDocumentItem
        AND MaterialDocumentYear = @keys-MaterialDocumentYear
        AND PostingDate          = @keys-PostingDate
      INTO CORRESPONDING FIELDS OF TABLE @result.
  ENDMETHOD.

  METHOD lock.
  ENDMETHOD.

  METHOD cancelItem.
    " Kết quả từng dòng ghi vào ZCL_M_CAN_MATDOC_MSG -> hiện ở field ảo Message của ZC_M_CAN_MATDOC
    " (không lưu DB -> user Go lại sẽ mất)
    READ ENTITIES OF zi_m_can_matdoc IN LOCAL MODE
      ENTITY MatDoc
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(matdocs).

    " Chứng từ thường: hủy tất cả item trong 1 lần gọi BO chuẩn, các item cùng chứng từ gốc được gom vào
    " 1 chứng từ hủy. Chứng từ hủy chỉ được tạo khi lưu (sau khi action chạy xong).
    MODIFY ENTITIES OF I_MaterialDocumentTP FORWARDING PRIVILEGED
      ENTITY MaterialDocumentItem
      EXECUTE Cancel FROM VALUE #( FOR matdoc IN matdocs
                                   WHERE ( ItemHasBeenCanceled = abap_false AND HasReversalMovementType = abap_false
                                       AND IsTransferPosting   = abap_false )
                                   ( MaterialDocumentYear = matdoc-MaterialDocumentYear
                                     MaterialDocument     = matdoc-MaterialDocument
                                     MaterialDocumentItem = matdoc-MaterialDocumentItem
                                     %param               = VALUE #( PostingDate = matdoc-PostingDate ) ) )
      FAILED   DATA(cancel_failed)
      REPORTED DATA(cancel_reported).

    " Chứng từ chuyển kho / chuyển plant: BO chuẩn không cho hủy ở mức item
    " ("Canceling of subcontracting item ... on item level not possible") -> hủy bằng API CancelItem (hủy cả cặp)
    DATA api TYPE REF TO zcl_m_can_matdoc_api.

    LOOP AT matdocs ASSIGNING FIELD-SYMBOL(<matdoc>).

      DATA(message) = VALUE zcl_m_can_matdoc_msg=>ty_message( MaterialDocument     = <matdoc>-MaterialDocument
                                                              MaterialDocumentItem = <matdoc>-MaterialDocumentItem
                                                              MaterialDocumentYear = <matdoc>-MaterialDocumentYear
                                                              MessageCriticality   = zcl_m_can_matdoc_msg=>c_criticality_error ).

      IF <matdoc>-ItemHasBeenCanceled = abap_true OR <matdoc>-HasReversalMovementType = abap_true.
        message-Message = `Lỗi: dòng đã bị hủy hoặc là dòng đảo`.

      ELSEIF <matdoc>-IsTransferPosting = abap_true.
        IF api IS NOT BOUND.
          api = NEW #( ).
        ENDIF.
        DATA(api_result) = api->cancel_item( iv_material_document_year = <matdoc>-MaterialDocumentYear
                                             iv_material_document      = <matdoc>-MaterialDocument
                                             iv_material_document_item = <matdoc>-MaterialDocumentItem
                                             iv_posting_date           = <matdoc>-PostingDate ).
        IF api_result-success = abap_true.
          message-MessageCriticality = zcl_m_can_matdoc_msg=>c_criticality_success.
        ELSE.
          message-Message = |Lỗi: { api_result-message }|.
        ENDIF.

      ELSEIF line_exists( cancel_failed-materialdocumentitem[ MaterialDocumentYear = <matdoc>-MaterialDocumentYear
                                                              MaterialDocument     = <matdoc>-MaterialDocument
                                                              MaterialDocumentItem = <matdoc>-MaterialDocumentItem ] ).
        DATA(error_text) = ``.
        LOOP AT cancel_reported-materialdocumentitem ASSIGNING FIELD-SYMBOL(<cancel_reported>)
             WHERE MaterialDocumentYear = <matdoc>-MaterialDocumentYear
               AND MaterialDocument     = <matdoc>-MaterialDocument
               AND MaterialDocumentItem = <matdoc>-MaterialDocumentItem.
          error_text = |{ error_text }{ COND #( WHEN error_text IS NOT INITIAL THEN `; ` ) }{ <cancel_reported>-%msg->if_message~get_text( ) }|.
        ENDLOOP.
        message-Message = |Lỗi: { COND #( WHEN error_text IS NOT INITIAL THEN error_text ELSE `không hủy được item` ) }|.

      ELSE.
        " Message thành công (kèm số chứng từ hủy) do ZCL_M_CAN_MATDOC_MSG điền sau khi lưu
        message-MessageCriticality = zcl_m_can_matdoc_msg=>c_criticality_success.
      ENDIF.

      zcl_m_can_matdoc_msg=>set( message ).

    ENDLOOP.

    IF api IS BOUND.
      api->close( ).
    ENDIF.

    result = VALUE #( FOR matdoc IN matdocs
                      ( %tky   = matdoc-%tky
                        %param = CORRESPONDING #( matdoc ) ) ).
  ENDMETHOD.

  METHOD cancelHeader.
    " Hủy cả chứng từ của dòng được chọn bằng API Cancel (mức header): tất cả item chưa hủy của chứng từ
    " vào cùng 1 chứng từ hủy. Kết quả ghi vào field ảo Message của mọi dòng được gửi lên.
    READ ENTITIES OF zi_m_can_matdoc IN LOCAL MODE
      ENTITY MatDoc
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(matdocs).

    DATA(api) = NEW zcl_m_can_matdoc_api( ).

    LOOP AT matdocs ASSIGNING FIELD-SYMBOL(<matdoc>).

      " Nhiều dòng cùng chứng từ (kể cả ở các lần gọi action khác trong cùng request) -> chỉ gọi API 1 lần
      READ TABLE header_results ASSIGNING FIELD-SYMBOL(<header_result>)
           WITH KEY MaterialDocumentYear = <matdoc>-MaterialDocumentYear
                    MaterialDocument     = <matdoc>-MaterialDocument.
      IF sy-subrc <> 0.
        APPEND VALUE #( MaterialDocumentYear = <matdoc>-MaterialDocumentYear
                        MaterialDocument     = <matdoc>-MaterialDocument
                        result               = api->cancel_header( iv_material_document_year = <matdoc>-MaterialDocumentYear
                                                                   iv_material_document      = <matdoc>-MaterialDocument
                                                                   iv_posting_date           = <matdoc>-PostingDate ) )
               TO header_results ASSIGNING <header_result>.
      ENDIF.

      " Thành công: để trống Message, ZCL_M_CAN_MATDOC_MSG tự điền chứng từ hủy của dòng
      zcl_m_can_matdoc_msg=>set( VALUE #(
        MaterialDocument     = <matdoc>-MaterialDocument
        MaterialDocumentItem = <matdoc>-MaterialDocumentItem
        MaterialDocumentYear = <matdoc>-MaterialDocumentYear
        Message              = COND #( WHEN <header_result>-result-success = abap_false
                                       THEN |Lỗi: { <header_result>-result-message }| )
        MessageCriticality   = COND #( WHEN <header_result>-result-success = abap_true
                                       THEN zcl_m_can_matdoc_msg=>c_criticality_success
                                       ELSE zcl_m_can_matdoc_msg=>c_criticality_error ) ) ).

    ENDLOOP.

    api->close( ).

    result = VALUE #( FOR matdoc IN matdocs
                      ( %tky   = matdoc-%tky
                        %param = CORRESPONDING #( matdoc ) ) ).
  ENDMETHOD.

ENDCLASS.

