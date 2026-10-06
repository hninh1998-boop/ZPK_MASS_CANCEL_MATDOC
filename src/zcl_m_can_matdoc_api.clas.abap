"! Gọi API Material Document (OData V2 API_MATERIAL_DOCUMENT_SRV) - function import CancelItem / Cancel
"! để hủy từng material document item / cả chứng từ: GET lấy x-csrf-token rồi POST.
"! Curl mẫu: api/material_document_cancel_item.
CLASS zcl_m_can_matdoc_api DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_result,
        success                TYPE abap_bool,
        reversal_document_year TYPE zi_m_can_matdoc-MaterialDocumentYear,
        reversal_document      TYPE zi_m_can_matdoc-MaterialDocument,
        reversal_document_item TYPE zi_m_can_matdoc-MaterialDocumentItem,
        message                TYPE string,
      END OF ty_result.

    CONSTANTS:
      " User / password / host gọi API lấy từ ZTB_API_AUTH (mỗi môi trường 1 dòng riêng)
      c_system_id    TYPE ztb_api_auth-systemid VALUE 'CASLA',
      c_service_path TYPE string VALUE `/sap/opu/odata/sap/API_MATERIAL_DOCUMENT_SRV`.

    METHODS cancel_item
      IMPORTING iv_material_document_year TYPE zi_m_can_matdoc-MaterialDocumentYear
                iv_material_document      TYPE zi_m_can_matdoc-MaterialDocument
                iv_material_document_item TYPE zi_m_can_matdoc-MaterialDocumentItem
                iv_posting_date           TYPE zi_m_can_matdoc-PostingDate OPTIONAL
      RETURNING VALUE(rs_result)          TYPE ty_result.

    "! Hủy cả chứng từ (tất cả item chưa hủy); kết quả không có reversal_document_item
    METHODS cancel_header
      IMPORTING iv_material_document_year TYPE zi_m_can_matdoc-MaterialDocumentYear
                iv_material_document      TYPE zi_m_can_matdoc-MaterialDocument
                iv_posting_date           TYPE zi_m_can_matdoc-PostingDate OPTIONAL
      RETURNING VALUE(rs_result)          TYPE ty_result.

    "! Đóng kết nối sau khi hủy xong tất cả item
    METHODS close.

  PRIVATE SECTION.
    DATA:
      mo_client  TYPE REF TO if_web_http_client,
      mo_request TYPE REF TO if_web_http_request,
      mv_token   TYPE string.

    "! Mở kết nối + lấy x-csrf-token (1 lần, dùng chung cho các item)
    METHODS open
      RETURNING VALUE(rv_error) TYPE string.

    METHODS post
      IMPORTING iv_uri_path      TYPE string
                iv_posting_date  TYPE zi_m_can_matdoc-PostingDate
      RETURNING VALUE(rs_result) TYPE ty_result.

    METHODS get_host_url
      IMPORTING iv_host       TYPE csequence
      RETURNING VALUE(rv_url) TYPE string.

    METHODS parse_response
      IMPORTING iv_status        TYPE if_web_http_response=>http_status
                iv_body          TYPE string
      RETURNING VALUE(rs_result) TYPE ty_result.
ENDCLASS.



CLASS zcl_m_can_matdoc_api IMPLEMENTATION.

  METHOD cancel_item.
    rs_result = post( iv_uri_path     = |{ c_service_path }/CancelItem|
                                     && |?MaterialDocumentYear=%27{ iv_material_document_year }%27|
                                     && |&MaterialDocument=%27{ iv_material_document }%27|
                                     && |&MaterialDocumentItem=%27{ iv_material_document_item }%27|
                      iv_posting_date = iv_posting_date ).
  ENDMETHOD.


  METHOD cancel_header.
    rs_result = post( iv_uri_path     = |{ c_service_path }/Cancel|
                                     && |?MaterialDocumentYear=%27{ iv_material_document_year }%27|
                                     && |&MaterialDocument=%27{ iv_material_document }%27|
                      iv_posting_date = iv_posting_date ).
  ENDMETHOD.


  METHOD post.
    rs_result-message = open( ).
    IF rs_result-message IS NOT INITIAL.
      RETURN.
    ENDIF.

    DATA(lv_uri_path) = iv_uri_path.
    " Không truyền PostingDate -> API lấy ngày hiện tại của hệ thống
    IF iv_posting_date IS NOT INITIAL.
      lv_uri_path &&= |&PostingDate=datetime%27{ iv_posting_date DATE = ISO }T00:00:00%27|.
    ENDIF.

    TRY.
        mo_request->set_uri_path( i_uri_path = lv_uri_path ).
        mo_request->set_header_field( i_name = `x-csrf-token` i_value = mv_token ).

        DATA(lo_response) = mo_client->execute( if_web_http_client=>post ).
        rs_result = parse_response( iv_status = lo_response->get_status( )
                                    iv_body   = lo_response->get_text( ) ).

      CATCH cx_web_http_client_error cx_web_message_error INTO DATA(lx_http).
        rs_result-message = |Lỗi kết nối API: { lx_http->get_text( ) }|.
    ENDTRY.
  ENDMETHOD.


  METHOD close.
    IF mo_client IS BOUND.
      TRY.
          mo_client->close( ).
        CATCH cx_web_http_client_error ##NO_HANDLER.
      ENDTRY.
    ENDIF.
    CLEAR: mo_client, mo_request, mv_token.
  ENDMETHOD.


  METHOD open.
    IF mv_token IS NOT INITIAL.
      RETURN.
    ENDIF.

    SELECT SINGLE api_user, api_password, api_url
      FROM ztb_api_auth
      WHERE systemid = @c_system_id
      INTO @DATA(ls_auth).
    IF sy-subrc <> 0 OR ls_auth-api_url IS INITIAL OR ls_auth-api_user IS INITIAL.
      rv_error = |Chưa khai báo user API trong ZTB_API_AUTH (SYSTEMID = { c_system_id })|.
      RETURN.
    ENDIF.

    TRY.
        DATA(lo_destination) = cl_http_destination_provider=>create_by_url( i_url = get_host_url( ls_auth-api_url ) ).
        mo_client  = cl_web_http_client_manager=>create_by_http_destination( lo_destination ).
        " Token gắn với session cookie -> GET và POST phải dùng chung client + cookie
        mo_client->accept_cookies( i_allow = abap_true ).
        mo_request = mo_client->get_http_request( ).

        mo_request->set_authorization_basic( i_username = CONV #( ls_auth-api_user )
                                             i_password = CONV #( ls_auth-api_password ) ).
        mo_request->set_header_field( i_name = `Accept` i_value = `application/json` ).
        mo_request->set_uri_path( i_uri_path = |{ c_service_path }/| ).
        mo_request->set_header_field( i_name = `x-csrf-token` i_value = `fetch` ).

        DATA(lo_response) = mo_client->execute( if_web_http_client=>get ).
        DATA(lv_status)   = lo_response->get_status( ).
        mv_token = lo_response->get_header_field( `x-csrf-token` ).

      CATCH cx_http_dest_provider_error cx_web_http_client_error cx_web_message_error INTO DATA(lx_http).
        rv_error = |Lỗi kết nối API: { lx_http->get_text( ) }|.
        close( ).
        RETURN.
    ENDTRY.

    IF mv_token IS INITIAL.
      rv_error = |Không lấy được x-csrf-token: HTTP { lv_status-code } { lv_status-reason }|.
      close( ).
    ENDIF.
  ENDMETHOD.


  METHOD get_host_url.
    " API_URL lưu host (vd. my426501-api.s4hana.cloud.sap) hoặc URL đầy đủ có https:// -> chỉ lấy https://host
    rv_url = condense( val = CONV string( iv_host ) ).
    IF NOT matches( val = rv_url regex = `^https?://.*` case = abap_false ).
      rv_url = |https://{ rv_url }|.
    ENDIF.
    DATA(lv_path_off) = find( val = rv_url sub = `/` off = find( val = rv_url sub = `://` ) + 3 ).
    IF lv_path_off > 0.
      rv_url = substring( val = rv_url len = lv_path_off ).
    ENDIF.
  ENDMETHOD.


  METHOD parse_response.
    " OK   : { "d": { "MaterialDocumentYear": "2026", "MaterialDocument": "4900005980", "MaterialDocumentItem": "1", ... } }
    "        -> chứng từ đảo vừa được tạo
    " Lỗi  : { "error": { "code": "...", "message": { "lang": "en", "value": "..." } } }
    TYPES:
      BEGIN OF ty_response,
        BEGIN OF d,
          materialdocumentyear TYPE string,
          materialdocument     TYPE string,
          materialdocumentitem TYPE string,
        END OF d,
        BEGIN OF error,
          BEGIN OF message,
            value TYPE string,
          END OF message,
        END OF error,
      END OF ty_response.

    DATA ls_response TYPE ty_response.

    /ui2/cl_json=>deserialize( EXPORTING json = iv_body
                               CHANGING  data = ls_response ).

    IF iv_status-code BETWEEN 200 AND 299 AND ls_response-d-materialdocument IS NOT INITIAL.
      rs_result-success                = abap_true.
      rs_result-reversal_document_year = ls_response-d-materialdocumentyear.
      rs_result-reversal_document      = ls_response-d-materialdocument.
      rs_result-reversal_document_item = ls_response-d-materialdocumentitem.
    ELSE.
      rs_result-message = COND #( WHEN ls_response-error-message-value IS NOT INITIAL
                                  THEN ls_response-error-message-value
                                  ELSE |API lỗi HTTP { iv_status-code } { iv_status-reason }| ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.

