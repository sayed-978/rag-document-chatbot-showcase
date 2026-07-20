-- Run this entire script once in the Supabase SQL Editor, BEFORE importing the n8n workflow.
-- This script CREATES the table -- it does not exist until this runs.
-- If you ever delete the table, just re-run this exact script to recreate it
-- (note: deleting the table also deletes all previously uploaded document data).

-- 1. Enable pgvector
create extension if not exists vector;

-- 2. Creates the table that holds document chunks + embeddings
--    Pre-sized for Google's gemini-embedding-001 model (3072-dimension vectors).
--    Do not change 3072 unless you also change the embedding model used in the
--    workflow's two "Embeddings Google Gemini" nodes -- both numbers must always match.
create table if not exists company_documents (
  id bigserial primary key,
  content text,
  metadata jsonb,
  embedding vector(3072)
);

-- 3. Enable Row Level Security (locks the table to backend-only access;
--    the n8n Supabase credential uses the Secret/service_role key, which
--    bypasses RLS automatically, so this does not break the workflow)
alter table company_documents enable row level security;

-- 4. Similarity search function.
--    IMPORTANT: must be named exactly "match_documents" -- this name is
--    hardcoded inside the n8n Supabase Vector Store node and is NOT
--    configurable via the node's UI, regardless of what table name you pick.
create or replace function match_documents (
  query_embedding vector(3072),
  match_count int default null,
  filter jsonb default '{}'
) returns table (
  id bigint,
  content text,
  metadata jsonb,
  similarity float
)
language plpgsql
as $$
begin
  return query
  select
    company_documents.id,
    company_documents.content,
    company_documents.metadata,
    1 - (company_documents.embedding <=> query_embedding) as similarity
  from company_documents
  where company_documents.metadata @> filter
  order by company_documents.embedding <=> query_embedding
  limit match_count;
end;
$$;

-- 5. Force Supabase's API layer to recognize the new table/function immediately
--    (skips the "table not found in schema cache" wait)
notify pgrst, 'reload schema';

-- 6. Optional: once you have meaningful document volume (100+ chunks), speed up
--    search with an index. Skip this for small demo/client knowledge bases.
-- create index on company_documents using ivfflat (embedding vector_cosine_ops) with (lists = 100);
