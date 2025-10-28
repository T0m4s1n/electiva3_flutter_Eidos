# Supabase Storage Setup for Documents

## 1. Create Storage Bucket

Go to your Supabase project dashboard:
- Navigate to **Storage** → **Buckets**
- Click **New bucket**
- Configure as follows:

### Bucket Details:
- **Name**: `documents`
- **Public**: ✅ (checked) - This allows authenticated users to access
- **File size limit**: 5 MB (adjust as needed)
- **Allowed MIME types**: 
  - `text/markdown`
  - `text/plain`
  - `application/pdf`

## 2. Storage Policies

Run this SQL in your Supabase SQL editor to create storage policies:

```sql
-- Allow authenticated users to upload documents
CREATE POLICY "Users can upload documents"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'documents' AND auth.uid()::text = (storage.foldername(name))[1]);

-- Allow users to read their own documents
CREATE POLICY "Users can read own documents"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'documents' AND auth.uid()::text = (storage.foldername(name))[1]);

-- Allow users to update their own documents
CREATE POLICY "Users can update own documents"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'documents' AND auth.uid()::text = (storage.foldername(name))[1]);

-- Allow users to delete their own documents
CREATE POLICY "Users can delete own documents"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'documents' AND auth.uid()::text = (storage.foldername(name))[1]);
```

## 3. Alternative: Simpler Policies (Allow all authenticated users)

If you prefer simpler policies:

```sql
-- Allow all authenticated users to read
CREATE POLICY "Authenticated users can read documents"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'documents');

-- Allow all authenticated users to upload
CREATE POLICY "Authenticated users can upload documents"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'documents');

-- Allow all authenticated users to update
CREATE POLICY "Authenticated users can update documents"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'documents');

-- Allow all authenticated users to delete
CREATE POLICY "Authenticated users can delete documents"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'documents');
```

## 4. Verify Setup

After running the schema and storage setup:

1. Run the complete `database_schema.sql` in your Supabase SQL editor
2. Verify the `documents` bucket exists in Storage
3. Test uploading a file from your app

## 5. Storage Path Structure

Documents will be stored with this structure:
```
documents/
  └── {user_id}/
      └── {document_id}/
          ├── v1.{timestamp}.md
          ├── v2.{timestamp}.md
          └── current.md
```

## Notes

- Documents are stored in `.md` (Markdown) format
- Each version is timestamped
- The current version is always stored as `current.md`
- Old versions are kept for history

