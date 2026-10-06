@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Cancel document of a material doc item'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_M_CAN_MATDOC_REV
  as select from I_MaterialDocumentItem_2
{
  key ReversedMaterialDocumentYear,
  key ReversedMaterialDocument,
  key ReversedMaterialDocumentItem,
      max( MaterialDocument ) as CancelMaterialDocument
}
where
  ReversedMaterialDocument <> ''
group by
  ReversedMaterialDocumentYear,
  ReversedMaterialDocument,
  ReversedMaterialDocumentItem
