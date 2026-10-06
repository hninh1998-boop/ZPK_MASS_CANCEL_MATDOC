@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Material Document Value Help'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.dataCategory: #VALUE_HELP
@Search.searchable: true
define view entity ZI_M_CAN_MATDOC_VH
  as select from I_MaterialDocumentHeader_2
{
  key MaterialDocumentYear,
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 1.0
      @Search.ranking: #HIGH
  key MaterialDocument,
      DocumentDate,
      PostingDate,
      AccountingDocumentType,
      InventoryTransactionType,
      CreatedByUser,
      CreationDate,
      CreationTime
}
