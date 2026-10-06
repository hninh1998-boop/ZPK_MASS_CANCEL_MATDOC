@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'ZI_M_CAN_MATDOC'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZI_M_CAN_MATDOC
  as select from    I_MaterialDocumentItem_2 as Item
    left outer join I_GoodsMovementCube      as Cube       on  Cube.MaterialDocumentYear       = Item.MaterialDocumentYear
                                                           and Cube.MaterialDocument           = Item.MaterialDocument
                                                           and Cube.MaterialDocumentItem       = Item.MaterialDocumentItem
                                                           and Cube.MaterialDocumentRecordType = 'MDOC'
    left outer join ZI_M_CAN_MATDOC_REV      as Rev        on  Rev.ReversedMaterialDocumentYear = Item.MaterialDocumentYear
                                                           and Rev.ReversedMaterialDocument     = Item.MaterialDocument
                                                           and Rev.ReversedMaterialDocumentItem = Item.MaterialDocumentItem
    left outer join I_MaterialDocumentItem_2 as CancelItem on  CancelItem.MaterialDocument             = Rev.CancelMaterialDocument
                                                           and CancelItem.ReversedMaterialDocumentYear = Item.MaterialDocumentYear
                                                           and CancelItem.ReversedMaterialDocument     = Item.MaterialDocument
                                                           and CancelItem.ReversedMaterialDocumentItem = Item.MaterialDocumentItem
{
  key Item.MaterialDocument,
  key Item.MaterialDocumentItem,
  key Item.MaterialDocumentYear,
  key Item.PostingDate,
      // Dòng đảo: chứng từ gốc bị hủy (field chuẩn). Dòng gốc đã bị hủy: chứng từ hủy của nó.
      case when Item.ReversedMaterialDocument <> ''
           then Item.ReversedMaterialDocument
           else CancelItem.MaterialDocument
      end                               as ReversedMaterialDocument,
      case when Item.ReversedMaterialDocument <> ''
           then Item.ReversedMaterialDocumentItem
           else CancelItem.MaterialDocumentItem
      end                               as ReversedMatdocItem,
      Cube.GoodsMovementIsCancelled     as ItemHasBeenCanceled,
      Cube.IsReversalMovementType       as HasReversalMovementType,
      // Chứng từ chuyển kho / chuyển plant (311, 301, ...): có plant đối ứng
      cast( case when Item.IssuingOrReceivingPlant <> ''
                 then 'X'
                 else ''
            end as abap_boolean )       as IsTransferPosting
}
// Chuyển kho / chuyển plant (311, 301, ...): ẩn dòng nhận do hệ thống tự sinh, giống MIGO chỉ hiện dòng xuất
where
     Item.IsAutomaticallyCreated  = ''
  or Item.IssuingOrReceivingPlant = ''
