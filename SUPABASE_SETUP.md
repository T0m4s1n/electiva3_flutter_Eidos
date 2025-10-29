# Configuración de Supabase para Eidos

## Schema de Base de Datos

El archivo `database_schema.sql` contiene todo el schema necesario para Supabase.

## Pasos de Configuración

### 1. Ejecutar el Schema Principal

En el SQL Editor de Supabase, ejecuta todo el contenido de `database_schema.sql`:

```sql
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
```

### 2. Agregar Migraciones si es Necesario

Si ya tienes tablas existentes, ejecuta la migración:

```sql
-- Add context column if it doesn't exist
ALTER TABLE public.conversations 
ADD COLUMN IF NOT EXISTS context JSONB;
```

### 3. Verificar que se Guarden los Mensajes

El sistema ya está configurado para:
1. Guardar mensajes en SQLite local primero
2. Sincronizar automáticamente con Supabase

## Debug en Flutter

Para ver los logs de debug en Flutter, busca estos mensajes en la consola:

- `ChatDatabase: === UPSERT MESSAGE START ===`
- `ChatDatabase: Message inserted directly into database`
- `ChatDatabase: IMMEDIATE check after insert - found X messages`
- `ChatService.addMessage - Message saved successfully`
- `ChatService.addMessage - Total messages in conversation: X`

## Troubleshooting

Si los mensajes no se guardan en Supabase:

1. Verifica que el usuario esté autenticado
2. Ejecuta el botón de sincronización manual en la app
3. Revisa los logs de debug en la consola

