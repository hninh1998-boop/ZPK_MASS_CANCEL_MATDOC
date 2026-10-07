@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'ZC_M_CAN_MATDOC'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define root view entity ZC_M_CAN_MATDOC
  provider contract transactional_query
  as projection on ZI_M_CAN_MATDOC
{
  key MaterialDocument,
  key MaterialDocumentItem,
  key MaterialDocumentYear,
  key PostingDate,
      ReversedMaterialDocument,
      ReversedMatdocItem,
      ItemHasBeenCanceled,
      HasReversalMovementType,
      GoodsMovementType,
      Material,
      ProductDescription,
      Plant,
      @Semantics.quantity.unitOfMeasure: 'EntryUnit'
      QuantityInEntryUnit,
      EntryUnit,
      @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_M_CAN_MATDOC_MSG'
      virtual Message            : abap.char( 255 ),
      @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_M_CAN_MATDOC_MSG'
      virtual MessageCriticality : abap.int1
}
