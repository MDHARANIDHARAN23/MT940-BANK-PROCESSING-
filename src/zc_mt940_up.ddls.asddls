@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'MT940 File Upload'

@Metadata.allowExtensions: true
define root view entity ZC_MT940_UP
  provider contract transactional_query
  as projection on ZR_MT940_UP
{
    key UploadId,
        FileName,
        FileContent,
        MimeType,
        Status,
        Message,
        CreatedBy,
        CreatedAt
}
