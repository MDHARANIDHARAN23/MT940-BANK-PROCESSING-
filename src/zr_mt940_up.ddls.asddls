@AccessControl.authorizationCheck: #NOT_REQUIRED

@EndUserText.label: 'VIEW ENTITY FOR UPLOAD'

@Metadata.ignorePropagatedAnnotations: true

define root view entity ZR_MT940_UP
  as select from zbank_mt940_up
{
    key upload_id as UploadId,

    file_name as FileName,

    @Semantics.largeObject: {
        mimeType: 'MimeType',
        fileName: 'FileName'
    }
    file_content as FileContent,

    @Semantics.mimeType: true
    mime_type as MimeType,

    status as Status,
    message as Message,
    created_by as CreatedBy,
    created_at as CreatedAt
}
