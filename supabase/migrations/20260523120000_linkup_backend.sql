create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  role text not null default 'seeker' check (role in ('seeker', 'employer', 'admin')),
  district text not null default 'Kampala',
  bio text not null default '',
  skills text[] not null default '{}',
  company_name text not null default '',
  phone text not null default '',
  avatar_url text not null default '',
  website text not null default '',
  updated_at timestamptz not null default now()
);

create table if not exists public.jobs (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  employer_name text not null,
  location text not null,
  salary text not null,
  sector text not null check (sector in ('informal', 'startup', 'formal')),
  description text not null,
  is_hidden boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.saved_jobs (
  user_id uuid not null references auth.users(id) on delete cascade,
  job_id uuid not null references public.jobs(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, job_id)
);

create table if not exists public.job_applications (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs(id) on delete cascade,
  job_title text not null,
  applicant_id uuid not null references auth.users(id) on delete cascade,
  applicant_name text not null,
  cover_note text not null,
  status text not null default 'pending' check (status in ('pending', 'shortlisted', 'rejected', 'hired')),
  created_at timestamptz not null default now(),
  unique (job_id, applicant_id)
);

create table if not exists public.conversation_threads (
  id uuid primary key default gen_random_uuid(),
  participant_one_id uuid not null references auth.users(id) on delete cascade,
  participant_two_id uuid not null references auth.users(id) on delete cascade,
  job_id uuid references public.jobs(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.conversation_messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.conversation_threads(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.notices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  message text not null,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists jobs_owner_id_idx on public.jobs(owner_id);
create index if not exists job_applications_job_id_idx on public.job_applications(job_id);
create index if not exists job_applications_applicant_id_idx on public.job_applications(applicant_id);
create index if not exists conversation_threads_participants_idx on public.conversation_threads(participant_one_id, participant_two_id);
create index if not exists conversation_messages_thread_id_idx on public.conversation_messages(thread_id);
create index if not exists notices_user_id_idx on public.notices(user_id);

alter table public.profiles enable row level security;
alter table public.jobs enable row level security;
alter table public.saved_jobs enable row level security;
alter table public.job_applications enable row level security;
alter table public.conversation_threads enable row level security;
alter table public.conversation_messages enable row level security;
alter table public.notices enable row level security;

drop policy if exists "Profiles are readable by the owner" on public.profiles;
create policy "Profiles are readable by the owner"
on public.profiles
for select
to authenticated
using ((select auth.uid()) = id);

drop policy if exists "Profiles are insertable by the owner" on public.profiles;
create policy "Profiles are insertable by the owner"
on public.profiles
for insert
to authenticated
with check ((select auth.uid()) = id);

drop policy if exists "Profiles are updatable by the owner" on public.profiles;
create policy "Profiles are updatable by the owner"
on public.profiles
for update
to authenticated
using ((select auth.uid()) = id)
with check ((select auth.uid()) = id);

drop policy if exists "Jobs are visible to everyone" on public.jobs;
create policy "Jobs are visible to everyone"
on public.jobs
for select
to anon, authenticated
using (not is_hidden);

drop policy if exists "Job owners can view hidden jobs" on public.jobs;
create policy "Job owners can view hidden jobs"
on public.jobs
for select
to authenticated
using ((select auth.uid()) = owner_id);

drop policy if exists "Authenticated users can create jobs" on public.jobs;
create policy "Authenticated users can create jobs"
on public.jobs
for insert
to authenticated
with check ((select auth.uid()) = owner_id);

drop policy if exists "Job owners can update jobs" on public.jobs;
create policy "Job owners can update jobs"
on public.jobs
for update
to authenticated
using ((select auth.uid()) = owner_id)
with check ((select auth.uid()) = owner_id);

drop policy if exists "Job owners can delete jobs" on public.jobs;
create policy "Job owners can delete jobs"
on public.jobs
for delete
to authenticated
using ((select auth.uid()) = owner_id);

drop policy if exists "Saved jobs are owned by the user" on public.saved_jobs;
create policy "Saved jobs are owned by the user"
on public.saved_jobs
for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "Users can save jobs for themselves" on public.saved_jobs;
create policy "Users can save jobs for themselves"
on public.saved_jobs
for insert
to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "Users can delete their saved jobs" on public.saved_jobs;
create policy "Users can delete their saved jobs"
on public.saved_jobs
for delete
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "Applications are visible to applicants and job owners" on public.job_applications;
create policy "Applications are visible to applicants and job owners"
on public.job_applications
for select
to authenticated
using (
  (select auth.uid()) = applicant_id
  or exists (
    select 1
    from public.jobs
    where jobs.id = job_applications.job_id
      and jobs.owner_id = (select auth.uid())
  )
);

drop policy if exists "Applicants can create their own applications" on public.job_applications;
create policy "Applicants can create their own applications"
on public.job_applications
for insert
to authenticated
with check ((select auth.uid()) = applicant_id);

drop policy if exists "Job owners can update application status" on public.job_applications;
create policy "Job owners can update application status"
on public.job_applications
for update
to authenticated
using (
  exists (
    select 1
    from public.jobs
    where jobs.id = job_applications.job_id
      and jobs.owner_id = (select auth.uid())
  )
)
with check (
  exists (
    select 1
    from public.jobs
    where jobs.id = job_applications.job_id
      and jobs.owner_id = (select auth.uid())
  )
);

drop policy if exists "Threads are visible to participants" on public.conversation_threads;
create policy "Threads are visible to participants"
on public.conversation_threads
for select
to authenticated
using (
  (select auth.uid()) = participant_one_id
  or (select auth.uid()) = participant_two_id
);

drop policy if exists "Participants can create threads" on public.conversation_threads;
create policy "Participants can create threads"
on public.conversation_threads
for insert
to authenticated
with check (
  (select auth.uid()) = participant_one_id
  or (select auth.uid()) = participant_two_id
);

drop policy if exists "Thread participants can update threads" on public.conversation_threads;
create policy "Thread participants can update threads"
on public.conversation_threads
for update
to authenticated
using (
  (select auth.uid()) = participant_one_id
  or (select auth.uid()) = participant_two_id
)
with check (
  (select auth.uid()) = participant_one_id
  or (select auth.uid()) = participant_two_id
);

drop policy if exists "Messages are visible to thread participants" on public.conversation_messages;
create policy "Messages are visible to thread participants"
on public.conversation_messages
for select
to authenticated
using (
  exists (
    select 1
    from public.conversation_threads threads
    where threads.id = conversation_messages.thread_id
      and (
        threads.participant_one_id = (select auth.uid())
        or threads.participant_two_id = (select auth.uid())
      )
  )
);

drop policy if exists "Thread participants can send messages" on public.conversation_messages;
create policy "Thread participants can send messages"
on public.conversation_messages
for insert
to authenticated
with check (
  sender_id = (select auth.uid())
  and exists (
    select 1
    from public.conversation_threads threads
    where threads.id = conversation_messages.thread_id
      and (
        threads.participant_one_id = (select auth.uid())
        or threads.participant_two_id = (select auth.uid())
      )
  )
);

drop policy if exists "Notices are visible to the owner" on public.notices;
create policy "Notices are visible to the owner"
on public.notices
for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "Notices are writable by the owner" on public.notices;
create policy "Notices are writable by the owner"
on public.notices
for insert
to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "Notices can be updated by the owner" on public.notices;
create policy "Notices can be updated by the owner"
on public.notices
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create or replace trigger set_profiles_updated_at
before update on public.profiles
for each row
execute function public.set_updated_at();

create or replace trigger set_jobs_updated_at
before update on public.jobs
for each row
execute function public.set_updated_at();

grant usage on schema public to anon, authenticated;

grant select on public.jobs to anon, authenticated;
grant insert, update, delete on public.jobs to authenticated;

grant select, insert, update, delete on public.profiles to authenticated;

grant select, insert, update, delete on public.saved_jobs to authenticated;

grant select, insert, update on public.job_applications to authenticated;

grant select, insert, update on public.conversation_threads to authenticated;
grant select, insert on public.conversation_messages to authenticated;

grant select, insert, update on public.notices to authenticated;

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id)
do update set public = excluded.public;

drop policy if exists "Avatar images are public" on storage.objects;
create policy "Avatar images are public"
on storage.objects
for select
to anon, authenticated
using (bucket_id = 'avatars');

drop policy if exists "Authenticated users can upload avatar images" on storage.objects;
create policy "Authenticated users can upload avatar images"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'avatars'
  and split_part(name, '/', 1) = (select auth.uid())::text
);

drop policy if exists "Authenticated users can update their avatar images" on storage.objects;
create policy "Authenticated users can update their avatar images"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'avatars'
  and split_part(name, '/', 1) = (select auth.uid())::text
)
with check (
  bucket_id = 'avatars'
  and split_part(name, '/', 1) = (select auth.uid())::text
);

drop policy if exists "Authenticated users can delete their avatar images" on storage.objects;
create policy "Authenticated users can delete their avatar images"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'avatars'
  and split_part(name, '/', 1) = (select auth.uid())::text
);
