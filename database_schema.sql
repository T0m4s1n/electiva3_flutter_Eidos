-- Supabase/PostgreSQL Database Schema for Eidos Chat App
-- This schema is used for cloud storage on Supabase

-- Extension for UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============ TABLES ============

-- Conversations table
CREATE TABLE IF NOT EXISTS public.conversations (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT,
  model TEXT,
  summary TEXT,
  is_archived BOOLEAN DEFAULT FALSE,
  last_message_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Messages table
CREATE TABLE IF NOT EXISTS public.messages (
  id UUID PRIMARY KEY,
  conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('user','assistant','system','tool')),
  content JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL,
  seq INTEGER NOT NULL,
  parent_id UUID,
  status TEXT NOT NULL DEFAULT 'ok' CHECK (status IN ('ok','pending','error')),
  is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

-- Profiles table
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT UNIQUE NOT NULL,
  full_name TEXT,
  avatar_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Documents table
CREATE TABLE IF NOT EXISTS public.documents (
  id UUID PRIMARY KEY,
  conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  file_path TEXT,
  file_url TEXT,
  is_current_version BOOLEAN DEFAULT TRUE,
  version_number INTEGER NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Document versions table
CREATE TABLE IF NOT EXISTS public.document_versions (
  id UUID PRIMARY KEY,
  document_id UUID NOT NULL REFERENCES public.documents(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  file_path TEXT,
  file_url TEXT,
  version_number INTEGER NOT NULL,
  change_summary TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by UUID NOT NULL REFERENCES auth.users(id)
);

-- ============ INDEXES ============

-- Index for fast conversation retrieval by user
CREATE INDEX IF NOT EXISTS idx_conversations_user_updated
  ON public.conversations(user_id, updated_at DESC);

-- Index for fast message retrieval by conversation
CREATE INDEX IF NOT EXISTS idx_messages_conv_created
  ON public.messages(conversation_id, created_at, seq);

-- Index for pending messages
CREATE INDEX IF NOT EXISTS idx_messages_status
  ON public.messages(status)
  WHERE status = 'pending';

-- Index for profiles
CREATE INDEX IF NOT EXISTS idx_profiles_email
  ON public.profiles(email);

-- Index for documents by conversation
CREATE INDEX IF NOT EXISTS idx_documents_conversation
  ON public.documents(conversation_id, updated_at DESC);

-- Index for documents by user
CREATE INDEX IF NOT EXISTS idx_documents_user
  ON public.documents(user_id, updated_at DESC);

-- Index for document versions
CREATE INDEX IF NOT EXISTS idx_document_versions_document
  ON public.document_versions(document_id, version_number DESC);

-- ============ TRIGGERS ============

-- Function to update conversation timestamp
CREATE OR REPLACE FUNCTION public.tg_touch_conversation()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  UPDATE public.conversations
    SET updated_at = NOW(),
        last_message_at = GREATEST(
          COALESCE(NEW.created_at, NOW()),
          COALESCE(last_message_at, '-infinity'::timestamptz)
        )
  WHERE id = NEW.conversation_id;
  RETURN NEW;
END $$;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS tg_touch_conversation ON public.messages;

-- Create trigger for message insert
CREATE TRIGGER tg_touch_conversation
  AFTER INSERT ON public.messages
  FOR EACH ROW
  EXECUTE FUNCTION public.tg_touch_conversation();

-- ============ ROW LEVEL SECURITY (RLS) ============

-- Enable RLS on all tables
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_versions ENABLE ROW LEVEL SECURITY;

-- ============ POLICIES FOR CONVERSATIONS ============

-- Allow users to select their own conversations
DROP POLICY IF EXISTS "convs_select_own" ON public.conversations;
CREATE POLICY "convs_select_own"
  ON public.conversations FOR SELECT
  USING (auth.uid() = user_id);

-- Allow users to insert their own conversations
DROP POLICY IF EXISTS "convs_insert_own" ON public.conversations;
CREATE POLICY "convs_insert_own"
  ON public.conversations FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Allow users to update their own conversations
DROP POLICY IF EXISTS "convs_update_own" ON public.conversations;
CREATE POLICY "convs_update_own"
  ON public.conversations FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Allow users to delete their own conversations
DROP POLICY IF EXISTS "convs_delete_own" ON public.conversations;
CREATE POLICY "convs_delete_own"
  ON public.conversations FOR DELETE
  USING (auth.uid() = user_id);

-- ============ POLICIES FOR MESSAGES ============

-- Allow users to select messages from their own conversations
DROP POLICY IF EXISTS "msgs_select_own_convs" ON public.messages;
CREATE POLICY "msgs_select_own_convs"
  ON public.messages FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM public.conversations c
    WHERE c.id = messages.conversation_id AND c.user_id = auth.uid()
  ));

-- Allow users to insert messages into their own conversations
DROP POLICY IF EXISTS "msgs_insert_own_convs" ON public.messages;
CREATE POLICY "msgs_insert_own_convs"
  ON public.messages FOR INSERT
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.conversations c
    WHERE c.id = messages.conversation_id AND c.user_id = auth.uid()
  ));

-- Allow users to update messages from their own conversations
DROP POLICY IF EXISTS "msgs_update_own_convs" ON public.messages;
CREATE POLICY "msgs_update_own_convs"
  ON public.messages FOR UPDATE
  USING (EXISTS (
    SELECT 1 FROM public.conversations c
    WHERE c.id = messages.conversation_id AND c.user_id = auth.uid()
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.conversations c
    WHERE c.id = messages.conversation_id AND c.user_id = auth.uid()
  ));

-- Allow users to delete messages from their own conversations
DROP POLICY IF EXISTS "msgs_delete_own_convs" ON public.messages;
CREATE POLICY "msgs_delete_own_convs"
  ON public.messages FOR DELETE
  USING (EXISTS (
    SELECT 1 FROM public.conversations c
    WHERE c.id = messages.conversation_id AND c.user_id = auth.uid()
  ));

-- ============ POLICIES FOR PROFILES ============

-- Allow users to select their own profile
DROP POLICY IF EXISTS "profiles_select_own" ON public.profiles;
CREATE POLICY "profiles_select_own"
  ON public.profiles FOR SELECT
  USING (auth.uid() = id);

-- Allow users to insert their own profile
DROP POLICY IF EXISTS "profiles_insert_own" ON public.profiles;
CREATE POLICY "profiles_insert_own"
  ON public.profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

-- Allow users to update their own profile
DROP POLICY IF EXISTS "profiles_update_own" ON public.profiles;
CREATE POLICY "profiles_update_own"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- Allow users to delete their own profile
DROP POLICY IF EXISTS "profiles_delete_own" ON public.profiles;
CREATE POLICY "profiles_delete_own"
  ON public.profiles FOR DELETE
  USING (auth.uid() = id);

-- ============ POLICIES FOR DOCUMENTS ============

-- Allow users to select their own documents
DROP POLICY IF EXISTS "docs_select_own" ON public.documents;
CREATE POLICY "docs_select_own"
  ON public.documents FOR SELECT
  USING (auth.uid() = user_id);

-- Allow users to insert their own documents
DROP POLICY IF EXISTS "docs_insert_own" ON public.documents;
CREATE POLICY "docs_insert_own"
  ON public.documents FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Allow users to update their own documents
DROP POLICY IF EXISTS "docs_update_own" ON public.documents;
CREATE POLICY "docs_update_own"
  ON public.documents FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Allow users to delete their own documents
DROP POLICY IF EXISTS "docs_delete_own" ON public.documents;
CREATE POLICY "docs_delete_own"
  ON public.documents FOR DELETE
  USING (auth.uid() = user_id);

-- ============ POLICIES FOR DOCUMENT VERSIONS ============

-- Allow users to select versions of their own documents
DROP POLICY IF EXISTS "doc_versions_select_own" ON public.document_versions;
CREATE POLICY "doc_versions_select_own"
  ON public.document_versions FOR SELECT
  USING (auth.uid() = user_id);

-- Allow users to insert versions for their own documents
DROP POLICY IF EXISTS "doc_versions_insert_own" ON public.document_versions;
CREATE POLICY "doc_versions_insert_own"
  ON public.document_versions FOR INSERT
  WITH CHECK (auth.uid() = user_id AND auth.uid() = created_by);

-- Allow users to update versions of their own documents
DROP POLICY IF EXISTS "doc_versions_update_own" ON public.document_versions;
CREATE POLICY "doc_versions_update_own"
  ON public.document_versions FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Allow users to delete versions of their own documents
DROP POLICY IF EXISTS "doc_versions_delete_own" ON public.document_versions;
CREATE POLICY "doc_versions_delete_own"
  ON public.document_versions FOR DELETE
  USING (auth.uid() = user_id);

-- ============ STORAGE BUCKETS ============

-- Create storage bucket for profile pictures
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'profile-pictures',
  'profile-pictures',
  true,
  5242880, -- 5MB limit
  ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO NOTHING;

-- Create storage bucket for documents
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'documents',
  'documents',
  false, -- Private bucket, requires authentication
  52428800, -- 50MB limit
  ARRAY['application/pdf', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', 'text/plain', 'text/markdown', 'application/vnd.oasis.opendocument.text']
)
ON CONFLICT (id) DO NOTHING;

-- ============ STORAGE POLICIES FOR PROFILE PICTURES ============

-- Allow users to upload their own profile pictures
DROP POLICY IF EXISTS "profile_pics_insert_own" ON storage.objects;
CREATE POLICY "profile_pics_insert_own"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'profile-pictures' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );

-- Allow users to update their own profile pictures
DROP POLICY IF EXISTS "profile_pics_update_own" ON storage.objects;
CREATE POLICY "profile_pics_update_own"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'profile-pictures' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );

-- Allow users to delete their own profile pictures
DROP POLICY IF EXISTS "profile_pics_delete_own" ON storage.objects;
CREATE POLICY "profile_pics_delete_own"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'profile-pictures' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );

-- Allow public read access to profile pictures (since bucket is public)
DROP POLICY IF EXISTS "profile_pics_select_all" ON storage.objects;
CREATE POLICY "profile_pics_select_all"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'profile-pictures');

-- ============ STORAGE POLICIES FOR DOCUMENTS ============

-- Allow users to upload their own documents
DROP POLICY IF EXISTS "docs_insert_own" ON storage.objects;
CREATE POLICY "docs_insert_own"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'documents' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );

-- Allow users to read their own documents
DROP POLICY IF EXISTS "docs_select_own" ON storage.objects;
CREATE POLICY "docs_select_own"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'documents' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );

-- Allow users to update their own documents
DROP POLICY IF EXISTS "docs_update_own" ON storage.objects;
CREATE POLICY "docs_update_own"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'documents' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );

-- Allow users to delete their own documents
DROP POLICY IF EXISTS "docs_delete_own" ON storage.objects;
CREATE POLICY "docs_delete_own"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'documents' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );
