@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'VIEW ENTITY FOR RECONCILIATION'
@Metadata.ignorePropagatedAnnotations: true

define view entity ZR_BANK_MT940_R
  as select from zbank_mt940_r

  association to parent ZR_BANK_MT940_I as _Transaction
    on $projection.TransactionId = _Transaction.TransactionId
    
   association to ZR_BANK_MT940_H as _Header
    on $projection.StatementId = _Header.StatementId
    
    

{
    key reconciliation_id  as ReconciliationId,
        statement_id      as StatementId,
        transaction_id    as TransactionId,
        bank_amount       as BankAmount,
        sap_amount        as SapAmount,
        difference_amount as DifferenceAmount,
        sap_document      as SapDocument,
        sap_reference     as SapReference,
        validation_status as ValidationStatus,
        validation_message as ValidationMessage,
        processed_by      as ProcessedBy,
        processed_at      as ProcessedAt,

        _Transaction,
        _Header
}
