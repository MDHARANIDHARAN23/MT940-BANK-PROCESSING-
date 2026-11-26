@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'PROJECTION VIEW FOR RECONCILIATION'
@Metadata.ignorePropagatedAnnotations: true

@Metadata.allowExtensions: true
define view entity ZC_BANK_MT940_R
  as projection on ZR_BANK_MT940_R
{
    key ReconciliationId,
        BankAmount,
        StatementId,
        TransactionId,
        SapAmount,
        DifferenceAmount,
        SapDocument,
        SapReference,
        ValidationStatus,
        ValidationMessage,
        ProcessedBy,
        ProcessedAt,

        _Transaction : redirected to parent ZC_BANK_MT940_I ,
        
        _Header : redirected to ZC_BANK_MT940_H
}
