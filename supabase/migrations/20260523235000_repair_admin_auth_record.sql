do $$
declare
  admin_email text := 'admin@linkup.ug';
  admin_password text := 'admin12345';
  admin_user_id uuid;
begin
  select id
    into admin_user_id
  from auth.users
  where email = admin_email
  limit 1;

  if admin_user_id is null then
    raise exception 'Admin user % not found. Run create_super_admin migration first.', admin_email;
  end if;

  update auth.users
  set aud = 'authenticated',
      role = 'authenticated',
      encrypted_password = extensions.crypt(admin_password, extensions.gen_salt('bf')),
      email_confirmed_at = coalesce(email_confirmed_at, now()),
      raw_app_meta_data = jsonb_build_object('provider', 'email', 'providers', jsonb_build_array('email')),
      raw_user_meta_data = jsonb_build_object(
        'email', admin_email,
        'email_verified', true,
        'phone_verified', false,
        'sub', admin_user_id::text,
        'full_name', 'LinkUp Super Admin',
        'role', 'admin'
      ),
      phone = coalesce(phone, ''),
      is_sso_user = false,
      is_anonymous = false,
      updated_at = now()
  where id = admin_user_id;

  delete from auth.identities
  where user_id = admin_user_id
    and provider = 'email';

  insert into auth.identities (
    id,
    user_id,
    identity_data,
    provider,
    provider_id,
    created_at,
    updated_at,
    last_sign_in_at
  )
  values (
    admin_user_id,
    admin_user_id,
    jsonb_build_object(
      'email', admin_email,
      'email_verified', true,
      'phone_verified', false,
      'sub', admin_user_id::text
    ),
    'email',
    admin_user_id::text,
    now(),
    now(),
    now()
  )
  on conflict (provider, provider_id) do update
    set user_id = excluded.user_id,
        identity_data = excluded.identity_data,
        updated_at = now(),
        last_sign_in_at = excluded.last_sign_in_at;

  insert into public.profiles (
    id,
    full_name,
    role,
    district,
    bio,
    skills,
    company_name,
    updated_at
  )
  values (
    admin_user_id,
    'LinkUp Super Admin',
    'admin',
    'Kampala',
    'System administrator',
    array['Platform Admin'],
    'LinkUp',
    now()
  )
  on conflict (id) do update
    set full_name = excluded.full_name,
        role = 'admin',
        district = excluded.district,
        bio = excluded.bio,
        skills = excluded.skills,
        company_name = excluded.company_name,
        updated_at = now();
end
$$;
