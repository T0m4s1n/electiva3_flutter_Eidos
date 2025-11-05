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
  context JSONB,
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

-- ============ ADDITIONAL TABLES ============

-- Advanced Settings table
-- Stores user-specific advanced settings
CREATE TABLE IF NOT EXISTS public.advanced_settings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  max_tokens INTEGER NOT NULL DEFAULT 1000,
  apply_to_all_chats BOOLEAN NOT NULL DEFAULT TRUE,
  auto_clear_cache BOOLEAN NOT NULL DEFAULT FALSE,
  enable_analytics BOOLEAN NOT NULL DEFAULT TRUE,
  enable_crash_reports BOOLEAN NOT NULL DEFAULT TRUE,
  auto_sync BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id)
);

-- Crash Reports table
-- Stores crash reports submitted by users
CREATE TABLE IF NOT EXISTS public.crash_reports (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  error_message TEXT NOT NULL,
  stack_trace TEXT,
  device_info JSONB,
  app_version TEXT,
  os_version TEXT,
  additional_info JSONB,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed', 'resolved', 'dismissed')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  resolved_at TIMESTAMPTZ
);

-- Reminders table
-- Stores reminders created by users through chat or manually
CREATE TABLE IF NOT EXISTS public.reminders (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  reminder_date TIMESTAMPTZ NOT NULL,
  is_completed BOOLEAN NOT NULL DEFAULT FALSE,
  created_from_chat BOOLEAN NOT NULL DEFAULT FALSE,
  conversation_id UUID REFERENCES public.conversations(id) ON DELETE SET NULL,
  message_id UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Notification Preferences table
-- Stores user-specific notification preferences
CREATE TABLE IF NOT EXISTS public.notification_preferences (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  enable_push BOOLEAN NOT NULL DEFAULT TRUE,
  enable_in_app BOOLEAN NOT NULL DEFAULT TRUE,
  enable_sound BOOLEAN NOT NULL DEFAULT TRUE,
  enable_vibration BOOLEAN NOT NULL DEFAULT TRUE,
  quiet_hours_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  quiet_start_hour INTEGER NOT NULL DEFAULT 22,
  quiet_start_minute INTEGER NOT NULL DEFAULT 0,
  quiet_end_hour INTEGER NOT NULL DEFAULT 7,
  quiet_end_minute INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id)
);

-- Feedback Messages table
-- Stores feedback messages submitted by users
CREATE TABLE IF NOT EXISTS public.feedback_messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  type TEXT NOT NULL CHECK (type IN ('Bug report', 'Feature request', 'Feedback')),
  severity TEXT NOT NULL CHECK (severity IN ('Low', 'Medium', 'High')),
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  contact_email TEXT,
  attachment_urls JSONB,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed', 'resolved', 'dismissed')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============ ADDITIONAL INDEXES ============

-- Index for advanced settings by user
CREATE INDEX IF NOT EXISTS idx_advanced_settings_user
  ON public.advanced_settings(user_id);

-- Index for crash reports by user
CREATE INDEX IF NOT EXISTS idx_crash_reports_user
  ON public.crash_reports(user_id);

-- Index for crash reports by status
CREATE INDEX IF NOT EXISTS idx_crash_reports_status
  ON public.crash_reports(status);

-- Index for crash reports by created date
CREATE INDEX IF NOT EXISTS idx_crash_reports_created
  ON public.crash_reports(created_at DESC);

-- Index for reminders by user
CREATE INDEX IF NOT EXISTS idx_reminders_user
  ON public.reminders(user_id);

-- Index for reminders by date
CREATE INDEX IF NOT EXISTS idx_reminders_date
  ON public.reminders(reminder_date);

-- Index for active reminders (not completed)
CREATE INDEX IF NOT EXISTS idx_reminders_active
  ON public.reminders(user_id, reminder_date)
  WHERE is_completed = FALSE;

-- Index for notification preferences by user
CREATE INDEX IF NOT EXISTS idx_notification_preferences_user
  ON public.notification_preferences(user_id);

-- Index for feedback messages by user
CREATE INDEX IF NOT EXISTS idx_feedback_messages_user
  ON public.feedback_messages(user_id);

-- Index for feedback messages by status
CREATE INDEX IF NOT EXISTS idx_feedback_messages_status
  ON public.feedback_messages(status);

-- Index for feedback messages by type
CREATE INDEX IF NOT EXISTS idx_feedback_messages_type
  ON public.feedback_messages(type);

-- Index for feedback messages by created date
CREATE INDEX IF NOT EXISTS idx_feedback_messages_created
  ON public.feedback_messages(created_at DESC);

-- Passkeys table
-- Stores passkey credentials for biometric authentication
CREATE TABLE IF NOT EXISTS public.passkeys (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  passkey_id TEXT NOT NULL UNIQUE,
  credential_id TEXT NOT NULL UNIQUE,
  public_key TEXT NOT NULL,
  device_name TEXT,
  device_type TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_used_at TIMESTAMPTZ,
  is_active BOOLEAN NOT NULL DEFAULT TRUE
);

-- Index for passkeys by user
CREATE INDEX IF NOT EXISTS idx_passkeys_user
  ON public.passkeys(user_id);

-- Index for passkeys by credential_id for fast lookup
CREATE INDEX IF NOT EXISTS idx_passkeys_credential_id
  ON public.passkeys(credential_id);

-- Index for active passkeys by user
CREATE INDEX IF NOT EXISTS idx_passkeys_user_active
  ON public.passkeys(user_id, is_active)
  WHERE is_active = TRUE;

-- ============ ADDITIONAL TRIGGERS ============

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.tg_update_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END $$;

-- Trigger for advanced_settings
DROP TRIGGER IF EXISTS tg_advanced_settings_updated_at ON public.advanced_settings;
CREATE TRIGGER tg_advanced_settings_updated_at
  BEFORE UPDATE ON public.advanced_settings
  FOR EACH ROW
  EXECUTE FUNCTION public.tg_update_updated_at();

-- Function to update reminder updated_at timestamp
CREATE OR REPLACE FUNCTION public.tg_update_reminder_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END $$;

-- Trigger for reminders
DROP TRIGGER IF EXISTS tg_reminders_updated_at ON public.reminders;
CREATE TRIGGER tg_reminders_updated_at
  BEFORE UPDATE ON public.reminders
  FOR EACH ROW
  EXECUTE FUNCTION public.tg_update_reminder_updated_at();

-- Function to update notification preferences updated_at timestamp
CREATE OR REPLACE FUNCTION public.tg_update_notification_preferences_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END $$;

-- Trigger for notification_preferences
DROP TRIGGER IF EXISTS tg_notification_preferences_updated_at ON public.notification_preferences;
CREATE TRIGGER tg_notification_preferences_updated_at
  BEFORE UPDATE ON public.notification_preferences
  FOR EACH ROW
  EXECUTE FUNCTION public.tg_update_notification_preferences_updated_at();

-- Function to update feedback messages updated_at timestamp
CREATE OR REPLACE FUNCTION public.tg_update_feedback_messages_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END $$;

-- Trigger for feedback_messages
DROP TRIGGER IF EXISTS tg_feedback_messages_updated_at ON public.feedback_messages;
CREATE TRIGGER tg_feedback_messages_updated_at
  BEFORE UPDATE ON public.feedback_messages
  FOR EACH ROW
  EXECUTE FUNCTION public.tg_update_feedback_messages_updated_at();

-- ============ ADDITIONAL ROW LEVEL SECURITY (RLS) ============

-- Enable RLS on additional tables
ALTER TABLE public.advanced_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crash_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reminders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.feedback_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.passkeys ENABLE ROW LEVEL SECURITY;

-- ============ POLICIES FOR ADVANCED SETTINGS ============

-- Allow users to select their own advanced settings
DROP POLICY IF EXISTS "advanced_settings_select_own" ON public.advanced_settings;
CREATE POLICY "advanced_settings_select_own"
  ON public.advanced_settings FOR SELECT
  USING (auth.uid() = user_id);

-- Allow users to insert their own advanced settings
DROP POLICY IF EXISTS "advanced_settings_insert_own" ON public.advanced_settings;
CREATE POLICY "advanced_settings_insert_own"
  ON public.advanced_settings FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Allow users to update their own advanced settings
DROP POLICY IF EXISTS "advanced_settings_update_own" ON public.advanced_settings;
CREATE POLICY "advanced_settings_update_own"
  ON public.advanced_settings FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Allow users to delete their own advanced settings
DROP POLICY IF EXISTS "advanced_settings_delete_own" ON public.advanced_settings;
CREATE POLICY "advanced_settings_delete_own"
  ON public.advanced_settings FOR DELETE
  USING (auth.uid() = user_id);

-- ============ POLICIES FOR CRASH REPORTS ============

-- Allow users to select their own crash reports
DROP POLICY IF EXISTS "crash_reports_select_own" ON public.crash_reports;
CREATE POLICY "crash_reports_select_own"
  ON public.crash_reports FOR SELECT
  USING (auth.uid() = user_id OR user_id IS NULL);

-- Allow users to insert crash reports (including anonymous)
DROP POLICY IF EXISTS "crash_reports_insert_own" ON public.crash_reports;
CREATE POLICY "crash_reports_insert_own"
  ON public.crash_reports FOR INSERT
  WITH CHECK (auth.uid() = user_id OR user_id IS NULL);

-- Allow users to update their own crash reports
DROP POLICY IF EXISTS "crash_reports_update_own" ON public.crash_reports;
CREATE POLICY "crash_reports_update_own"
  ON public.crash_reports FOR UPDATE
  USING (auth.uid() = user_id OR user_id IS NULL)
  WITH CHECK (auth.uid() = user_id OR user_id IS NULL);

-- Allow users to delete their own crash reports
DROP POLICY IF EXISTS "crash_reports_delete_own" ON public.crash_reports;
CREATE POLICY "crash_reports_delete_own"
  ON public.crash_reports FOR DELETE
  USING (auth.uid() = user_id OR user_id IS NULL);

-- ============ POLICIES FOR REMINDERS ============

-- Allow users to select their own reminders
DROP POLICY IF EXISTS "reminders_select_own" ON public.reminders;
CREATE POLICY "reminders_select_own"
  ON public.reminders FOR SELECT
  USING (auth.uid() = user_id);

-- Allow users to insert their own reminders
DROP POLICY IF EXISTS "reminders_insert_own" ON public.reminders;
CREATE POLICY "reminders_insert_own"
  ON public.reminders FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Allow users to update their own reminders
DROP POLICY IF EXISTS "reminders_update_own" ON public.reminders;
CREATE POLICY "reminders_update_own"
  ON public.reminders FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Allow users to delete their own reminders
DROP POLICY IF EXISTS "reminders_delete_own" ON public.reminders;
CREATE POLICY "reminders_delete_own"
  ON public.reminders FOR DELETE
  USING (auth.uid() = user_id);

-- ============ POLICIES FOR NOTIFICATION PREFERENCES ============

-- Allow users to select their own notification preferences
DROP POLICY IF EXISTS "notification_preferences_select_own" ON public.notification_preferences;
CREATE POLICY "notification_preferences_select_own"
  ON public.notification_preferences FOR SELECT
  USING (auth.uid() = user_id);

-- Allow users to insert their own notification preferences
DROP POLICY IF EXISTS "notification_preferences_insert_own" ON public.notification_preferences;
CREATE POLICY "notification_preferences_insert_own"
  ON public.notification_preferences FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Allow users to update their own notification preferences
DROP POLICY IF EXISTS "notification_preferences_update_own" ON public.notification_preferences;
CREATE POLICY "notification_preferences_update_own"
  ON public.notification_preferences FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Allow users to delete their own notification preferences
DROP POLICY IF EXISTS "notification_preferences_delete_own" ON public.notification_preferences;
CREATE POLICY "notification_preferences_delete_own"
  ON public.notification_preferences FOR DELETE
  USING (auth.uid() = user_id);

-- ============ POLICIES FOR FEEDBACK MESSAGES ============

-- Allow users to select their own feedback messages
DROP POLICY IF EXISTS "feedback_messages_select_own" ON public.feedback_messages;
CREATE POLICY "feedback_messages_select_own"
  ON public.feedback_messages FOR SELECT
  USING (auth.uid() = user_id OR user_id IS NULL);

-- Allow users to insert feedback messages (including anonymous)
DROP POLICY IF EXISTS "feedback_messages_insert_own" ON public.feedback_messages;
CREATE POLICY "feedback_messages_insert_own"
  ON public.feedback_messages FOR INSERT
  WITH CHECK (auth.uid() = user_id OR user_id IS NULL);

-- Allow users to update their own feedback messages
DROP POLICY IF EXISTS "feedback_messages_update_own" ON public.feedback_messages;
CREATE POLICY "feedback_messages_update_own"
  ON public.feedback_messages FOR UPDATE
  USING (auth.uid() = user_id OR user_id IS NULL)
  WITH CHECK (auth.uid() = user_id OR user_id IS NULL);

-- Allow users to delete their own feedback messages
DROP POLICY IF EXISTS "feedback_messages_delete_own" ON public.feedback_messages;
CREATE POLICY "feedback_messages_delete_own"
  ON public.feedback_messages FOR DELETE
  USING (auth.uid() = user_id OR user_id IS NULL);

-- ============ POLICIES FOR PASSKEYS ============

-- Allow users to select their own passkeys
DROP POLICY IF EXISTS "passkeys_select_own" ON public.passkeys;
CREATE POLICY "passkeys_select_own"
  ON public.passkeys FOR SELECT
  USING (auth.uid() = user_id);

-- Allow users to insert their own passkeys
DROP POLICY IF EXISTS "passkeys_insert_own" ON public.passkeys;
CREATE POLICY "passkeys_insert_own"
  ON public.passkeys FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Allow users to update their own passkeys
DROP POLICY IF EXISTS "passkeys_update_own" ON public.passkeys;
CREATE POLICY "passkeys_update_own"
  ON public.passkeys FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Allow users to delete their own passkeys
DROP POLICY IF EXISTS "passkeys_delete_own" ON public.passkeys;
CREATE POLICY "passkeys_delete_own"
  ON public.passkeys FOR DELETE
  USING (auth.uid() = user_id);

-- ============ MIGRATION: ADD AUTO_SYNC COLUMN (if needed) ============
-- Only run this if the advanced_settings table exists without the auto_sync column
-- This migration is safe to run multiple times due to IF NOT EXISTS

ALTER TABLE public.advanced_settings 
ADD COLUMN IF NOT EXISTS auto_sync BOOLEAN NOT NULL DEFAULT TRUE;

-- Update existing rows to have auto_sync = true (if any exist)
UPDATE public.advanced_settings 
SET auto_sync = TRUE 
WHERE auto_sync IS NULL;
