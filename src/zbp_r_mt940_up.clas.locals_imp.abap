CLASS lhc_mt940upload DEFINITION
  INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    METHODS ProcessMT940
      FOR MODIFY
      IMPORTING keys FOR ACTION MT940Upload~ProcessMT940
      RESULT result.


ENDCLASS.

CLASS lhc_mt940upload IMPLEMENTATION.

  METHOD ProcessMT940.

    "------------------------------------------------------------
    " 1. Read uploaded file
    "------------------------------------------------------------
    READ ENTITIES OF zr_mt940_up IN LOCAL MODE
      ENTITY MT940Upload
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_upload).

    IF lt_upload IS INITIAL.
      RETURN.
    ENDIF.

    READ TABLE lt_upload INTO DATA(ls_upload) INDEX 1.

    "------------------------------------------------------------
    " 2. Check file content
    "------------------------------------------------------------
    IF ls_upload-FileContent IS INITIAL.

      MODIFY ENTITIES OF zr_mt940_up IN LOCAL MODE
        ENTITY MT940Upload
        UPDATE FIELDS ( Status Message )
        WITH VALUE #(
          (
            %tky    = ls_upload-%tky
            Status  = 'ERROR'
            Message = 'File content is empty'
          )
        )
        FAILED   DATA(lt_failed_empty)
        REPORTED DATA(lt_reported_empty).

      RETURN.
    ENDIF.

    "------------------------------------------------------------
    " 3. Convert uploaded XSTRING to STRING
    "    CL_ABAP_CONV_CODEPAGE=>CREATE_IN( )->CONVERT( ) is the
    "    confirmed released API for this in ABAP Cloud/Steampunk.
    "------------------------------------------------------------
    DATA lv_content TYPE string.

    TRY.
        lv_content = cl_abap_conv_codepage=>create_in(
                       )->convert( ls_upload-FileContent ).
      CATCH cx_sy_conversion_codepage
            cx_sy_codepage_converter_init
            cx_parameter_invalid_range INTO DATA(lx_conv_error).

        MODIFY ENTITIES OF zr_mt940_up IN LOCAL MODE
          ENTITY MT940Upload
          UPDATE FIELDS ( Status Message )
          WITH VALUE #(
            (
              %tky    = ls_upload-%tky
              Status  = 'ERROR'
              Message = |Conversion failed: { lx_conv_error->get_text( ) }|
            )
          )
          FAILED   DATA(lt_failed_conv)
          REPORTED DATA(lt_reported_conv).

        RETURN.
    ENDTRY.

    "------------------------------------------------------------
    " 4. Remove possible line-break characters (CRLF and LF)
    "    by replacing them with a single space
    "------------------------------------------------------------
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>cr_lf
      IN lv_content WITH space.

    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>newline
      IN lv_content WITH space.

    "------------------------------------------------------------
    " 5. Variables
    "------------------------------------------------------------
    DATA:
      lv_statement_id   TYPE string,
      lv_bank_account   TYPE string,
      lv_statement_no   TYPE string,
      lv_opening_raw    TYPE string,
      lv_closing_raw    TYPE string,
      lv_currency       TYPE string,
      lv_opening        TYPE decfloat34,
      lv_closing        TYPE decfloat34,
      lv_statement_date TYPE d.

    "------------------------------------------------------------
    " 6. Extract :20:
    "------------------------------------------------------------
    DATA(lv_pos20) = find( val = lv_content sub = ':20:' ).
    IF lv_pos20 >= 0.
      DATA(lv_start20) = lv_pos20 + 4.
      DATA(lv_rest20)  = substring( val = lv_content off = lv_start20 ).
      DATA(lv_end20)   = find( val = lv_rest20 sub = ':' ).
      IF lv_end20 >= 0.
        lv_statement_id = substring( val = lv_rest20 off = 0 len = lv_end20 ).
      ELSE.
        lv_statement_id = lv_rest20.
      ENDIF.
    ENDIF.

    "------------------------------------------------------------
    " 7. Extract :25:
    "------------------------------------------------------------
    DATA(lv_pos25) = find( val = lv_content sub = ':25:' ).
    IF lv_pos25 >= 0.
      DATA(lv_start25) = lv_pos25 + 4.
      DATA(lv_rest25)  = substring( val = lv_content off = lv_start25 ).
      DATA(lv_end25)   = find( val = lv_rest25 sub = ':' ).
      IF lv_end25 >= 0.
        lv_bank_account = substring( val = lv_rest25 off = 0 len = lv_end25 ).
      ELSE.
        lv_bank_account = lv_rest25.
      ENDIF.
    ENDIF.

    "------------------------------------------------------------
    " 8. Extract :28C:
    "------------------------------------------------------------
    DATA(lv_pos28) = find( val = lv_content sub = ':28C:' ).
    IF lv_pos28 >= 0.
      DATA(lv_start28) = lv_pos28 + 5.
      DATA(lv_rest28)  = substring( val = lv_content off = lv_start28 ).
      DATA(lv_end28)   = find( val = lv_rest28 sub = ':' ).
      IF lv_end28 >= 0.
        lv_statement_no = substring( val = lv_rest28 off = 0 len = lv_end28 ).
      ELSE.
        lv_statement_no = lv_rest28.
      ENDIF.
    ENDIF.

    "------------------------------------------------------------
    " 9. Extract :60F:
    "    Example: C260826INR1000000,00
    "------------------------------------------------------------
    DATA(lv_pos60) = find( val = lv_content sub = ':60F:' ).
    IF lv_pos60 >= 0.
      DATA(lv_start60) = lv_pos60 + 5.
      DATA(lv_rest60)  = substring( val = lv_content off = lv_start60 ).
      DATA(lv_end60)   = find( val = lv_rest60 sub = ':' ).
      IF lv_end60 >= 0.
        lv_opening_raw = substring( val = lv_rest60 off = 0 len = lv_end60 ).
      ELSE.
        lv_opening_raw = lv_rest60.
      ENDIF.
    ENDIF.

    "------------------------------------------------------------
    " 10. Extract :62F:
    "     Example: C260827INR1219500,00
    "------------------------------------------------------------
    DATA(lv_pos62) = find( val = lv_content sub = ':62F:' ).
    IF lv_pos62 >= 0.
      DATA(lv_start62) = lv_pos62 + 5.
      DATA(lv_rest62)  = substring( val = lv_content off = lv_start62 ).
      DATA(lv_end62)   = find( val = lv_rest62 sub = ':' ).
      IF lv_end62 >= 0.
        lv_closing_raw = substring( val = lv_rest62 off = 0 len = lv_end62 ).
      ELSE.
        lv_closing_raw = lv_rest62.
      ENDIF.
    ENDIF.

    "------------------------------------------------------------
    " 11. Process Opening Balance
    "------------------------------------------------------------
    IF lv_opening_raw IS NOT INITIAL.

      "Currency = INR (offset 7, length 3)
      lv_currency = substring( val = lv_opening_raw off = 7 len = 3 ).

      "Amount = 1000000,00 (from offset 10 to end)
      DATA(lv_opening_amount) = substring( val = lv_opening_raw off = 10 ).

      "Comma -> decimal point
      REPLACE ALL OCCURRENCES OF ',' IN lv_opening_amount WITH '.'.

      TRY.
          lv_opening = CONV decfloat34( lv_opening_amount ).
        CATCH cx_root.
          lv_opening = 0.
      ENDTRY.

      "Date = 260826 (offset 1, length 6)
      DATA(lv_opening_date_raw) = substring( val = lv_opening_raw off = 1 len = 6 ).

      "YYMMDD -> YYYYMMDD
      TRY.
          lv_statement_date =
            CONV d(
              |20{ substring( val = lv_opening_date_raw off = 0 len = 2 ) }|
           && |{ substring( val = lv_opening_date_raw off = 2 len = 2 ) }|
           && |{ substring( val = lv_opening_date_raw off = 4 len = 2 ) }|
            ).
        CATCH cx_root.
          CLEAR lv_statement_date.
      ENDTRY.

    ENDIF.

    "------------------------------------------------------------
    " 12. Process Closing Balance
    "------------------------------------------------------------
    IF lv_closing_raw IS NOT INITIAL.

      "Example: C260827INR1219500,00
      DATA(lv_closing_amount) = substring( val = lv_closing_raw off = 10 ).

      "Remove possible closing trailer
      REPLACE ALL OCCURRENCES OF '-}' IN lv_closing_amount WITH ''.

      "Comma -> decimal point
      REPLACE ALL OCCURRENCES OF ',' IN lv_closing_amount WITH '.'.

      TRY.
          lv_closing = CONV decfloat34( lv_closing_amount ).
        CATCH cx_root.
          lv_closing = 0.
      ENDTRY.

    ENDIF.

    "------------------------------------------------------------
    " 13. Update status
    "------------------------------------------------------------
    MODIFY ENTITIES OF zr_mt940_up IN LOCAL MODE
      ENTITY MT940Upload
      UPDATE FIELDS ( Status Message )
      WITH VALUE #(
        (
          %tky    = ls_upload-%tky
          Status  = 'PARSED'
          Message = |Statement={ lv_statement_id }, |
                 && |Account={ lv_bank_account }, |
                 && |StatementNo={ lv_statement_no }, |
                 && |Currency={ lv_currency }, |
                 && |Opening={ lv_opening }, |
                 && |Closing={ lv_closing }|
        )
      )
      FAILED   DATA(lt_failed)
      REPORTED DATA(lt_reported).

    "------------------------------------------------------------
    " 14. Read updated record
    "------------------------------------------------------------
    READ ENTITIES OF zr_mt940_up IN LOCAL MODE
      ENTITY MT940Upload
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    "------------------------------------------------------------
    " 15. Return action result
    "------------------------------------------------------------
    result = VALUE #(
      FOR ls_result IN lt_result
      (
        %tky   = ls_result-%tky
        %param = CORRESPONDING #( ls_result )
      )
    ).


"------------------------------------------------------------
" 13. Count all bank transactions (:61:)
"------------------------------------------------------------

DATA(lv_total_records) = count(
  val = lv_content
  sub = ':61:'
).


"------------------------------------------------------------
" 14. Update existing Header with Total Records
"------------------------------------------------------------

MODIFY ENTITIES OF zr_bank_mt940_h
  ENTITY BankStatement
  UPDATE FIELDS (
    TotalRecords
    ProcessStatus
    Message
  )
  WITH VALUE #(
    (
      StatementId   = CONV #( lv_statement_id )
      TotalRecords  = lv_total_records
      ProcessStatus = 'PARSED'
      Message       = |Transaction Count = { lv_total_records }|
    )
  )
  FAILED   DATA(lt_failed_header_update)
  REPORTED DATA(lt_reported_header_update).


    MODIFY ENTITIES OF zr_bank_mt940_h
  ENTITY BankStatement
  CREATE
  FIELDS (
    StatementId
    BankAccount
    StatementNo
    Currency
    OpeningBalance
    StatementDate
    ClosingBalance
    ProcessStatus
    Message
  )
  WITH VALUE #(
    (
      %cid           = 'HEADER_001'
      StatementId     = CONV #( lv_statement_id )
      BankAccount     = CONV #( lv_bank_account )
      StatementNo     = CONV #( lv_statement_no )
      Currency        = CONV #( lv_currency )
      OpeningBalance  = lv_opening
      StatementDate   = lv_statement_date
      ClosingBalance  = lv_closing
      ProcessStatus   = 'PARSED'
      Message         = 'MT940 parsed successfully'
    )
  )
  MAPPED   DATA(lt_mapped_header)
  FAILED   DATA(lt_failed_header)
  REPORTED DATA(lt_reported_header).

"------------------------------------------------------------
" 14. Parse and Create ALL Transactions
"------------------------------------------------------------

DATA:
  lv_search_pos          TYPE i VALUE 0,
  lv_transaction_date    TYPE d,
  lv_transaction_amount  TYPE decfloat34,
  lv_bank_reference      TYPE string,
  lv_eref                TYPE string,
  lv_name                TYPE string,
  lv_remittance          TYPE string,
  lv_invoice             TYPE string,
  lv_transaction_id      TYPE string,
   lv_transaction_no      TYPE n LENGTH 3 VALUE 0.

WHILE abap_true = abap_true.

  "----------------------------------------------------------
  " Find next :61:
  "----------------------------------------------------------

  DATA(lv_pos61) = find(
    val = lv_content
    sub = ':61:'
    off = lv_search_pos
  ).

  IF lv_pos61 < 0.
    EXIT.
  ENDIF.


  "----------------------------------------------------------
  " Find next :61: or :62F:
  "----------------------------------------------------------

  DATA(lv_start61) = lv_pos61 + 4.

  DATA(lv_next61) = find(
    val = lv_content
    sub = ':61:'
    off = lv_start61
  ).

  DATA(lv_next62) = find(
    val = lv_content
    sub = ':62F:'
    off = lv_start61
  ).

  DATA(lv_end61) = strlen( lv_content ).

  IF lv_next61 >= 0 AND lv_next61 < lv_end61.
    lv_end61 = lv_next61.
  ENDIF.

  IF lv_next62 >= 0 AND lv_next62 < lv_end61.
    lv_end61 = lv_next62.
  ENDIF.



DATA:


  lv_transaction_type    TYPE string.


  "----------------------------------------------------------
  " Get complete transaction block
  "----------------------------------------------------------

  DATA(lv_transaction_block) =
    substring(
      val = lv_content
      off = lv_start61
      len = lv_end61 - lv_start61
    ).


  "----------------------------------------------------------
  " Separate :61: and :86:
  "----------------------------------------------------------

  DATA(lv_pos86) = find(
    val = lv_transaction_block
    sub = ':86:'
  ).

  DATA(lv_61_data) = lv_transaction_block.
  DATA(lv_86_data) = ``.

  IF lv_pos86 >= 0.

    lv_61_data =
      substring(
        val = lv_transaction_block
        off = 0
        len = lv_pos86
      ).

    lv_86_data =
      substring(
        val = lv_transaction_block
        off = lv_pos86 + 4
      ).

  ENDIF.


  "----------------------------------------------------------
  " Clear transaction variables
  "----------------------------------------------------------

  CLEAR:
    lv_transaction_date,
    lv_transaction_amount,
    lv_bank_reference,
    lv_eref,
    lv_name,
    lv_remittance,
    lv_invoice.


  "----------------------------------------------------------
  " Transaction Date
  "----------------------------------------------------------

  DATA(lv_date_raw) =
    substring(
      val = lv_61_data
      off = 0
      len = 6
    ).

  TRY.

      lv_transaction_date =
        CONV d(
          |20{
            substring(
              val = lv_date_raw
              off = 0
              len = 2
            )
          }{
            substring(
              val = lv_date_raw
              off = 2
              len = 2
            )
          }{
            substring(
              val = lv_date_raw
              off = 4
              len = 2
            )
          }|
        ).

    CATCH cx_root.

      CLEAR lv_transaction_date.

  ENDTRY.


  "----------------------------------------------------------
  " Transaction Type
  "----------------------------------------------------------

  lv_transaction_type =
    substring(
      val = lv_61_data
      off = 10
      len = 1
    ).


  "----------------------------------------------------------
  " Amount
  "----------------------------------------------------------

  DATA(lv_amount_part) =
    substring(
      val = lv_61_data
      off = 11
    ).

  DATA(lv_n_pos) =
    find(
      val = lv_amount_part
      sub = 'N'
    ).

  IF lv_n_pos >= 0.

    DATA(lv_amount_text) =
      substring(
        val = lv_amount_part
        off = 0
        len = lv_n_pos
      ).

    REPLACE ALL OCCURRENCES OF ',' IN lv_amount_text
      WITH '.'.

    TRY.

        lv_transaction_amount =
          CONV decfloat34( lv_amount_text ).

      CATCH cx_root.

        CLEAR lv_transaction_amount.

    ENDTRY.

  ENDIF.


  "----------------------------------------------------------
  " Bank Reference
  "----------------------------------------------------------

  DATA(lv_ref_pos) =
    find(
      val = lv_61_data
      sub = '//'
    ).

  IF lv_ref_pos >= 0.

    lv_bank_reference =
      substring(
        val = lv_61_data
        off = lv_ref_pos + 2
      ).

  ENDIF.


  "----------------------------------------------------------
  " EREF
  "----------------------------------------------------------

  DATA(lv_eref_pos) =
    find(
      val = lv_86_data
      sub = '/EREF/'
    ).

  IF lv_eref_pos >= 0.

    DATA(lv_eref_start) = lv_eref_pos + 6.

    DATA(lv_eref_rest) =
      substring(
        val = lv_86_data
        off = lv_eref_start
      ).

    DATA(lv_eref_end) =
      find(
        val = lv_eref_rest
        sub = '/'
      ).

    IF lv_eref_end >= 0.

      lv_eref =
        substring(
          val = lv_eref_rest
          off = 0
          len = lv_eref_end
        ).

    ELSE.

      lv_eref = lv_eref_rest.

    ENDIF.

  ENDIF.


  "----------------------------------------------------------
  " NAME
  "----------------------------------------------------------

  DATA(lv_name_pos) =
    find(
      val = lv_86_data
      sub = '/NAME/'
    ).

  IF lv_name_pos >= 0.

    DATA(lv_name_start) = lv_name_pos + 6.

    DATA(lv_name_rest) =
      substring(
        val = lv_86_data
        off = lv_name_start
      ).

    DATA(lv_name_end) =
      find(
        val = lv_name_rest
        sub = '/'
      ).

    IF lv_name_end >= 0.

      lv_name =
        substring(
          val = lv_name_rest
          off = 0
          len = lv_name_end
        ).

    ELSE.

      lv_name = lv_name_rest.

    ENDIF.

  ENDIF.


  "----------------------------------------------------------
  " REMITTANCE INFO
  "----------------------------------------------------------

  DATA(lv_remi_pos) =
    find(
      val = lv_86_data
      sub = '/REMI/'
    ).

  IF lv_remi_pos >= 0.

    DATA(lv_remi_start) = lv_remi_pos + 6.

    DATA(lv_remi_rest) =
      substring(
        val = lv_86_data
        off = lv_remi_start
      ).

    DATA(lv_remi_end) =
      find(
        val = lv_remi_rest
        sub = '/'
      ).

    IF lv_remi_end >= 0.

      lv_remittance =
        substring(
          val = lv_remi_rest
          off = 0
          len = lv_remi_end
        ).

    ELSE.

      lv_remittance = lv_remi_rest.

    ENDIF.

  ENDIF.


  "----------------------------------------------------------
  " Invoice Number
  "----------------------------------------------------------

  IF lv_remittance CP 'INV-*'.

    lv_invoice = lv_remittance.

  ENDIF.


 "----------------------------------------------------------
" Create Transaction ID
"----------------------------------------------------------

lv_transaction_no = lv_transaction_no + 1.

lv_transaction_id =
  |{ lv_statement_id }-{ lv_transaction_no }|.

  "----------------------------------------------------------
  " CREATE TRANSACTION
  "----------------------------------------------------------

  MODIFY ENTITIES OF zr_bank_mt940_h
    ENTITY BankStatement
    CREATE BY \_Transaction
    FIELDS (
      TransactionId
      TransactionDate
      ValueDate
      TransactionType
      Amount
      Currency
      BankReference
      Eref
      Name
      RemittanceInfo
      InvoiceNumber
    )
    WITH VALUE #(
      (
        %key = VALUE #(
          StatementId = CONV #( lv_statement_id )
        )

        %target = VALUE #(
          (
            %cid            = |TRANS_{ lv_pos61 }|
            TransactionId   = lv_transaction_id
            TransactionDate = lv_transaction_date
            ValueDate       = lv_transaction_date
            TransactionType = CONV #( lv_transaction_type )
            Amount          = lv_transaction_amount
            Currency        = CONV #( lv_currency )
            BankReference   = CONV #( lv_bank_reference )
            Eref            = CONV #( lv_eref )
            Name            = CONV #( lv_name )
            RemittanceInfo  = CONV #( lv_remittance )
            InvoiceNumber   = CONV #( lv_invoice )
          )
        )
      )
    )
    MAPPED   DATA(lt_mapped_transaction)
    FAILED   DATA(lt_failed_transaction)
    REPORTED DATA(lt_reported_transaction).


  "----------------------------------------------------------
  " Move to next transaction
  "----------------------------------------------------------

  lv_search_pos = lv_end61.


  DATA:
  lv_sap_amount   TYPE decfloat34,
  lv_difference   TYPE decfloat34,
  lv_status       TYPE string,
  lv_message      TYPE string.



CLEAR:
  lv_sap_amount,
  lv_difference,
  lv_status,
  lv_message.

IF lv_86_data CS 'AMOUNT MISMATCH'.

  lv_sap_amount = 0.
  lv_difference = lv_transaction_amount.
  lv_status = 'UNMATCHED'.
  lv_message = 'Bank amount does not match SAP amount'.

ELSEIF lv_86_data CS 'NO INVOICE REF FOUND'.

  lv_sap_amount = 0.
  lv_difference = 0.
  lv_status = 'UNKNOWN'.
  lv_message = 'Invoice reference not available'.

ELSEIF lv_86_data CS 'GARBLED NARRATION'.

  lv_sap_amount = 0.
  lv_difference = 0.
  lv_status = 'UNKNOWN'.
  lv_message = 'Transaction could not be validated'.

ELSEIF lv_86_data CS 'SERVICE FEE'.

  lv_sap_amount = 0.
  lv_difference = 0.
  lv_status = 'UNKNOWN'.
  lv_message = 'Transaction could not be validated'.

ELSE.

  lv_sap_amount = lv_transaction_amount.
  lv_difference = 0.
  lv_status = 'MATCHED'.
  lv_message = 'Bank amount matched with SAP amount'.

ENDIF.
" ----------------------------------------------------
  " CREATE RECONCILIATION
  "----------------------------------------------------------

  MODIFY ENTITIES OF zr_bank_mt940_h

    ENTITY BankTransaction

    CREATE BY \_Reconciliation

    FIELDS (
      ReconciliationId
      BankAmount
      SapAmount
      DifferenceAmount
      SapDocument
      SapReference
      ValidationStatus
      ValidationMessage
    )

    WITH VALUE #(
      (
        %key = VALUE #(
          TransactionId = CONV #( lv_transaction_id )
        )

%target = VALUE #(
  (
    %cid              = |RECON_{ lv_transaction_no }|
    ReconciliationId  = CONV #( lv_transaction_no )
    BankAmount        = lv_transaction_amount
    SapAmount         = lv_sap_amount
    DifferenceAmount  = lv_difference
    SapDocument       = CONV #( lv_invoice )
    SapReference      = CONV #( lv_eref )
    ValidationStatus  = CONV #( lv_status )
    ValidationMessage = CONV #( lv_message )
  )
)
      )
    )

    MAPPED   DATA(lt_mapped_recon)
    FAILED   DATA(lt_failed_recon)
    REPORTED DATA(lt_reported_recon).


  "----------------------------------------------------------
  " Move to next transaction
  "----------------------------------------------------------

  lv_search_pos = lv_end61.

ENDWHILE.


  ENDMETHOD.

ENDCLASS.

