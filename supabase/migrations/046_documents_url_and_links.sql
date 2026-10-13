-- Build 417: one home for saved URLs.
-- Documents can carry a URL, and links are stored as documents with a
-- link_category (the discriminator). Additive only: no existing rows change,
-- trip_links stays readable (the app reads both), older app versions simply
-- ignore the new columns.
alter table public.documents
  add column if not exists url text,
  add column if not exists link_category text;

create index if not exists documents_trip_link_category_idx
  on public.documents (trip_id)
  where link_category is not null;

comment on column public.documents.url is
  'Source/booking URL for the document, or the link itself when link_category is set.';
comment on column public.documents.link_category is
  'Non-null = this row is a saved link (general/food/accommodation/activity/shopping/article/social).';
