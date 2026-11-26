@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'VIEW ENTITY FOR ROOT'
@Metadata.ignorePropagatedAnnotations: true

define root view entity ZR_BANK_MT940_H
  as select from zbank_mt940_h

  composition [0..*] of ZR_BANK_MT940_I as _Transaction
 //  composition [0..*] of ZR_BANK_MT940_R as _Reconciliation

{
    key statement_id      as StatementId,
        bank_account      as BankAccount,
        statement_no      as StatementNo,
        currency          as Currency,
        opening_balance   as OpeningBalance,
        statement_date    as StatementDate,
        closing_balance   as ClosingBalance,
        available_balance as AvailableBalance,
        file_name         as FileName,
        total_records     as TotalRecords,
        process_status    as ProcessStatus,
        message           as Message,
        created_by        as CreatedBy,
        created_at        as CreatedAt,

        _Transaction
      //  _Reconciliation
}
