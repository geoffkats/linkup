# LinkUp Job Connect App

### Show some  <img src="https://github.githubassets.com/images/icons/emoji/unicode/2764.png" width="30" height="30" />   and star the repo to support the project

### Screenshots


### Web

<p float="left">
  <img src="https://user-images.githubusercontent.com/10207753/90916139-ff6e4500-e3f9-11ea-99d6-c163f0cc2d45.png" height="500" /> 
  
  <br />
  <br />
<img src="https://user-images.githubusercontent.com/10207753/90915595-3e4fcb00-e3f9-11ea-886b-806ae60f277f.png" height="500" /> 
  
  <br />

</p>


### mobile
<p float="left">
<img src="https://user-images.githubusercontent.com/10207753/90918408-09924280-e3fe-11ea-8f14-12f5bde106f4.png" width="260" height="450" /> 

<img src="https://user-images.githubusercontent.com/10207753/90918501-347c9680-e3fe-11ea-8a53-299980caf68b.png" width="260" height="450" />

<img src="https://user-images.githubusercontent.com/10207753/90918498-33e40000-e3fe-11ea-9929-33443ff9dfee.png" width="260" height="450" />

</p>

<br />
<br />
<img src="https://user-images.githubusercontent.com/10207753/84770526-2589fa00-aff1-11ea-83bf-f1255b9371ac.jpg" width="50" height="30" />
<a href="https://youtu.be/GaJ4N9flt6c">Watch LinkUp Job Connect App - Responsive complete video </a>
</p>
<br />

### How to Create a Flutter Web project

# linkup


 <br />
 switch to the master channel run the following command

 ``1. flutter channel master``  <br />
 Then upgrade your flutter to the latest version from master.  <br />
`` 2. flutter upgrade``  <br />
Then enable web support.  <br />
`` 3. flutter config --enable-web``  <br />

Now when you create a project it'll be web enabled and you can run it in the browser. to verify that run this cmd. <br />

``flutter devices``
 <br />
 
Then
``flutter create xyz_project_name``
 <br />

### Created & Maintained By

Connect LinkUpState to a real backend (Firebase or Supabase) with repository abstractions.
Add phone-number OTP auth and employer verification workflow.
Add offline sync and low-bandwidth optimizations for field use across districts.

## Supabase Setup

LinkUp is now wired to Supabase through a lightweight bootstrap layer. The app still runs offline if you do not pass backend keys yet.

To connect your free Supabase project, run the app with:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://waewrivhfwxqemdjmlpz.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-supabase-publishable-or-anon-key
```

Use the Supabase free tier for this graduation project. It gives you Postgres, auth, storage, and realtime without paying for hosting.

The repo now includes a backend schema migration at [supabase/migrations/20260523120000_linkup_backend.sql](supabase/migrations/20260523120000_linkup_backend.sql) with tables, row-level security, grants, and an `avatars` storage bucket policy.

Apply that migration in your Supabase project to create the backend tables for profiles, jobs, saved jobs, applications, conversations, messages, and notices.

When Supabase is configured, the app creates an anonymous session automatically so the demo can read and write backend data without a full sign-in screen yet.

If your Supabase project uses the newer manual Data API exposure settings, make sure these tables are exposed in the Supabase dashboard after running the migration.
