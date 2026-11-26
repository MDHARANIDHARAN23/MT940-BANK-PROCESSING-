@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'PROJECTION VIEW FOR TRANSACTION'
@Metadata.ignorePropagatedAnnotations: true

@Metadata.allowExtensions: true
define view entity ZC_BANK_MT940_I
  as projection on ZR_BANK_MT940_I
{
    key TransactionId,
        TransactionDate,
        StatementId,
        ValueDate,
        TransactionType,
        Amount,
        Currency,
        BankReference,
        Eref,
        Name,
        RemittanceInfo,
        InvoiceNumber,

        _Header : redirected to parent ZC_BANK_MT940_H,

        _Reconciliation : redirected to composition child ZC_BANK_MT940_R
}
