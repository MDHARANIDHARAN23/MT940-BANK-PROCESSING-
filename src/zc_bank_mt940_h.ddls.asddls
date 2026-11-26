@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'PROJECTION VIEW FOR HEADER'
@Metadata.ignorePropagatedAnnotations: true

@Metadata.allowExtensions: true
define root view entity ZC_BANK_MT940_H
  provider contract transactional_query
  as projection on ZR_BANK_MT940_H
{
    key StatementId,
        BankAccount,
        StatementNo,
        Currency,
        OpeningBalance,
        StatementDate,
        ClosingBalance,
        AvailableBalance,
        FileName,
        TotalRecords,
        ProcessStatus,
        Message,
        CreatedBy,
        CreatedAt,

        _Transaction : redirected to composition child ZC_BANK_MT940_I
}
