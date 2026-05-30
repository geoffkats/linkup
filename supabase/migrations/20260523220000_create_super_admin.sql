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
    admin_user_id := gen_random_uuid();

    insert into auth.users (
      instance_id,
      id,
      aud,
      role,
      email,
      encrypted_password,
      email_confirmed_at,
      raw_app_meta_data,
      raw_user_meta_data,
      created_at,
      updated_at
    )
    values (
      '00000000-0000-0000-0000-000000000000',
      admin_user_id,
      'authenticated',
      'authenticated',
      admin_email,
      extensions.crypt(admin_password, extensions.gen_salt('bf')),
      now(),
      jsonb_build_object('provider', 'email', 'providers', array['email']),
      jsonb_build_object('full_name', 'LinkUp Super Admin', 'role', 'admin'),
      now(),
      now()
    );

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
      gen_random_uuid(),
      admin_user_id,
      jsonb_build_object('sub', admin_user_id::text, 'email', admin_email),
      'email',
      admin_user_id::text,
      now(),
      now(),
      now()
    )
    on conflict (provider, provider_id) do nothing;
  end if;

  insert into public.profiles (
    id,
    full_name,
    role,
    district,
    bio,
    skills,
    company_name,
    phone,
    avatar_url,
    website,
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
    '',
    '',
    '',
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