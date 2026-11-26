@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'VIEW ENTITY FOR TRANSACTION'
@Metadata.ignorePropagatedAnnotations: true

define view entity ZR_BANK_MT940_I
  as select from zbank_mt940_i

  association to parent ZR_BANK_MT940_H as _Header
    on $projection.StatementId = _Header.StatementId

  composition [0..*] of ZR_BANK_MT940_R as _Reconciliation

{
    key transaction_id   as TransactionId,
        statement_id     as StatementId,
        transaction_date as TransactionDate,
        value_date       as ValueDate,
        transaction_type as TransactionType,
        amount           as Amount,
        currency         as Currency,
        bank_reference   as BankReference,
        eref             as Eref,
        name             as Name,
        remittance_info  as RemittanceInfo,
        invoice_number  as InvoiceNumber,

        _Header,
        _Reconciliation
}
