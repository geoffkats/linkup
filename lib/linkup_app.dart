import 'dart:async';

import 'package:flutter/material.dart';
import 'package:linkup/repository/repository.dart';
import 'package:linkup/services/supabase_bootstrap.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum UserRole { seeker, employer, admin }

enum ApplicationStatus { pending, shortlisted, rejected, hired }

enum EmploymentSector { informal, startup, formal }

class Job {
  Job({
    required this.id,
    required this.title,
    required this.employerName,
    required this.location,
    required this.salary,
    required this.sector,
    required this.description,
    this.isHidden = false,
  });

  final String id;
  final String title;
  final String employerName;
  final String location;
  final String salary;
  final EmploymentSector sector;
  final String description;
  bool isHidden;
}

class JobApplication {
  JobApplication({
    required this.id,
    required this.jobId,
    required this.jobTitle,
    required this.applicantName,
    required this.coverNote,
    required this.createdAt,
    this.status = ApplicationStatus.pending,
  });

  final String id;
  final String jobId;
  final String jobTitle;
  final String applicantName;
  final String coverNote;
  final DateTime createdAt;
  ApplicationStatus status;
}

class ChatMessage {
  ChatMessage({required this.from, required this.body, required this.time});

  final String from;
  final String body;
  final DateTime time;
}

class ConversationThread {
  ConversationThread({
    required this.id,
    required this.withName,
    required this.messages,
  });

  final String id;
  final String withName;
  final List<ChatMessage> messages;
}

class AppNotice {
  AppNotice({
    required this.id,
    required this.message,
    required this.createdAt,
    this.read = false,
  });

  final String id;
  final String message;
  final DateTime createdAt;
  bool read;
}

class LinkUpState extends ChangeNotifier {
  LinkUpState()
      : _repository = SupabaseBootstrap.client == null
            ? null
            : LinkUpRepository(client: SupabaseBootstrap.client) {
    _seed();
    unawaited(_refreshFromBackend(preserveSeedData: true));
  }

  final LinkUpRepository? _repository;

  SupabaseClient? get _supabaseClient => SupabaseBootstrap.client;

  UserRole? role;
  String currentUserName = '';
  String district = 'Kampala';
  final Set<String> savedJobIds = <String>{};
  final List<Job> jobs = <Job>[];
  final List<JobApplication> applications = <JobApplication>[];
  final List<ConversationThread> conversations = <ConversationThread>[];
  final List<AppNotice> notices = <AppNotice>[];

  String seekerBio =
      'Reliable and hard-working youth ready for carpentry, delivery, shop support, and customer service opportunities.';
  final List<String> seekerSkills = <String>[
    'Customer Care',
    'Motorbike Delivery',
    'Basic Carpentry',
    'Sales Support',
  ];

  Future<void> _refreshFromBackend({bool preserveSeedData = false}) async {
    if (_repository == null) {
      return;
    }

    try {
      final UserRole? currentRole = role;
      final List<Job> backendJobs = await _repository.fetchJobs(
        includeHidden: currentRole != UserRole.seeker,
      );
      final Set<String> backendSavedJobs = currentRole == UserRole.seeker
          ? await _repository.fetchSavedJobIds()
          : <String>{};
      final List<JobApplication> backendApplications = currentRole == null
          ? <JobApplication>[]
          : await _repository.fetchApplications(role: currentRole);
      final List<AppNotice> backendNotices = currentRole == null
          ? <AppNotice>[]
          : await _repository.fetchNotices();
      final List<ConversationThread> backendConversations = currentRole == null
          ? <ConversationThread>[]
          : await _repository.fetchConversations();
      final dynamic backendProfile = await _repository.fetchProfile();

      if (backendJobs.isNotEmpty || !preserveSeedData) {
        jobs
          ..clear()
          ..addAll(backendJobs);
      }

      savedJobIds
        ..clear()
        ..addAll(backendSavedJobs);

      applications
        ..clear()
        ..addAll(backendApplications);

      if (backendNotices.isNotEmpty || !preserveSeedData) {
        notices
          ..clear()
          ..addAll(backendNotices);
      }

      if (backendConversations.isNotEmpty || !preserveSeedData) {
        conversations
          ..clear()
          ..addAll(backendConversations);
      }

      if (backendProfile != null) {
        if (currentUserName.isEmpty) {
          currentUserName = backendProfile.fullName;
        }
        seekerBio = backendProfile.bio;
        seekerSkills
          ..clear()
          ..addAll(backendProfile.skills);
        if (role == null) {
          district = backendProfile.district;
        }
      }

      notifyListeners();
    } catch (_) {
      // Keep the seeded offline-first state when backend sync is unavailable.
    }
  }

  Future<void> _runBackendSync(
    Future<void> Function() action, {
    bool refreshAfter = true,
  }) async {
    if (_repository == null) {
      return;
    }

    try {
      await action();
      if (refreshAfter) {
        await _refreshFromBackend();
      }
    } catch (_) {
      // Keep local state responsive when backend sync fails.
    }
  }

  void _seed() {
    jobs.addAll(<Job>[
      Job(
        id: 'j1',
        title: 'Market Stall Assistant',
        employerName: 'Nakasero Fresh Produce',
        location: 'Kampala',
        salary: 'UGX 25,000/day',
        sector: EmploymentSector.informal,
        description:
            'Help with stocking, customer support, and end-of-day reconciliation at a busy produce stall.',
      ),
      Job(
        id: 'j2',
        title: 'Junior Flutter Developer',
        employerName: 'Luganda Labs',
        location: 'Kampala (Hybrid)',
        salary: 'UGX 1,200,000/month',
        sector: EmploymentSector.startup,
        description:
            'Build and maintain mobile app features, collaborate with a small agile team, and ship weekly updates.',
      ),
      Job(
        id: 'j3',
        title: 'Field Sales Agent',
        employerName: 'Pearl Telecom',
        location: 'Mbarara',
        salary: 'UGX 900,000 + commission',
        sector: EmploymentSector.formal,
        description:
            'Drive SIM and data package sales, onboard agents, and report daily performance metrics.',
      ),
    ]);

    conversations.add(
      ConversationThread(
        id: 'c1',
        withName: 'Nakasero Fresh Produce',
        messages: <ChatMessage>[
          ChatMessage(
            from: 'Employer',
            body: 'Thanks for applying. Can you interview tomorrow at 9am?',
            time: DateTime.now().subtract(const Duration(hours: 3)),
          ),
          ChatMessage(
            from: 'You',
            body: 'Yes, I am available at 9am. Thank you.',
            time: DateTime.now().subtract(const Duration(hours: 2)),
          ),
        ],
      ),
    );

    notices.addAll(<AppNotice>[
      AppNotice(
        id: 'n1',
        message: '3 new startup roles added in Kampala.',
        createdAt: DateTime.now().subtract(const Duration(minutes: 40)),
      ),
      AppNotice(
        id: 'n2',
        message: 'Your profile is 80% complete. Add work samples to stand out.',
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      ),
    ]);
  }

  void _resetToSeedData() {
    savedJobIds.clear();
    jobs.clear();
    applications.clear();
    conversations.clear();
    notices.clear();
    _seed();
  }

  void signInAs(UserRole selectedRole, String name, String selectedDistrict) {
    role = selectedRole;
    currentUserName = name.trim().isEmpty ? 'Guest User' : name.trim();
    district = selectedDistrict;
    if (_repository != null) {
      unawaited(
        _runBackendSync(
          () => _repository.updateProfile(
            fullName: currentUserName,
            role: selectedRole,
            district: district,
            bio: seekerBio,
            skills: seekerSkills,
            companyName:
                selectedRole == UserRole.employer ? currentUserName : '',
          ),
        ),
      );
    }
    notifyListeners();
  }

  void signOut() {
    final SupabaseClient? client = _supabaseClient;
    if (client != null) {
      unawaited(client.auth.signOut());
    }
    role = null;
    currentUserName = '';
    district = 'Kampala';
    _resetToSeedData();
    notifyListeners();
  }

  Future<String?> deleteAccount() async {
    final SupabaseClient? client = _supabaseClient;

    if (client == null || _repository == null) {
      signOut();
      return null;
    }

    try {
      await _repository.deleteCurrentAccountData();

      // Optional Edge Function path for deleting auth.users when configured.
      try {
        await client.functions.invoke('delete-account');
      } catch (_) {
        // Ignore when the function is not deployed.
      }

      await client.auth.signOut();
      role = null;
      currentUserName = '';
      district = 'Kampala';
      _resetToSeedData();
      notifyListeners();
      return null;
    } catch (_) {
      return 'Unable to delete your account right now. Please try again.';
    }
  }

  Future<String?> registerWithEmail({
    required String email,
    required String password,
    required String name,
    required String selectedDistrict,
    required UserRole selectedRole,
  }) async {
    final SupabaseClient? client = _supabaseClient;
    if (client == null || _repository == null) {
      return 'Backend is not configured. Add Supabase URL and key first.';
    }

    try {
      final String trimmedEmail = email.trim();
      final String safeName = name.trim().isEmpty ? 'Guest User' : name.trim();

      final AuthResponse signUp = await client.auth.signUp(
        email: trimmedEmail,
        password: password,
        data: <String, dynamic>{
          'full_name': safeName,
          'district': selectedDistrict,
          'role': selectedRole.name,
        },
      );

      if (signUp.session == null) {
        try {
          await client.auth.signInWithPassword(
            email: trimmedEmail,
            password: password,
          );
        } on AuthException catch (error) {
          final String normalizedMessage = error.message.toLowerCase();
          if (normalizedMessage.contains('email not confirmed') ||
              normalizedMessage.contains('email not verified')) {
            return 'Email verification is enabled in Supabase Auth settings. '
                'Disable Confirm email to allow signup with no verification.';
          }
          rethrow;
        }
      }

      role = selectedRole;
      currentUserName = safeName;
      district = selectedDistrict;

      await _repository.updateProfile(
        fullName: currentUserName,
        role: selectedRole,
        district: district,
        bio: seekerBio,
        skills: seekerSkills,
        companyName: selectedRole == UserRole.employer ? currentUserName : '',
      );
      await _refreshFromBackend(preserveSeedData: false);
      notifyListeners();
      return null;
    } on AuthException catch (error) {
      final String normalizedMessage = error.message.toLowerCase();
      final bool isRateLimited = normalizedMessage.contains('rate limit') ||
          normalizedMessage.contains('too many requests');

      if (isRateLimited) {
        final String? loginResult = await loginWithEmail(
          email: email,
          password: password,
          fallbackRole: selectedRole,
          fallbackName: name.trim().isEmpty ? 'Guest User' : name.trim(),
          fallbackDistrict: selectedDistrict,
        );

        if (loginResult == null) {
          return null;
        }

        return 'Signup is temporarily rate-limited on Supabase. '
            'Please wait a few minutes and try Create account again, or use a different email.';
      }

      return error.message;
    } catch (_) {
      return 'Unable to create account right now. Please try again.';
    }
  }

  Future<String?> loginWithEmail({
    required String email,
    required String password,
    required UserRole fallbackRole,
    required String fallbackName,
    required String fallbackDistrict,
  }) async {
    final SupabaseClient? client = _supabaseClient;
    if (client == null || _repository == null) {
      return 'Backend is not configured. Add Supabase URL and key first.';
    }

    try {
      await client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      final dynamic profile = await _repository.fetchProfile();
      role = profile?.role ?? fallbackRole;
      currentUserName = (profile?.fullName.isNotEmpty ?? false)
          ? profile!.fullName
          : fallbackName;
      currentUserName = currentUserName.trim().isEmpty
          ? 'Guest User'
          : currentUserName.trim();
      district = (profile?.district.isNotEmpty ?? false)
          ? profile!.district
          : fallbackDistrict;

      await _repository.updateProfile(
        fullName: currentUserName,
        role: role!,
        district: district,
        bio: profile?.bio ?? seekerBio,
        skills: profile?.skills ?? seekerSkills,
        companyName: role == UserRole.employer
            ? (profile?.companyName ?? currentUserName)
            : '',
      );

      await _refreshFromBackend(preserveSeedData: false);
      notifyListeners();
      return null;
    } on AuthException catch (error) {
      final String normalizedMessage = error.message.toLowerCase();
      if (normalizedMessage.contains('invalid login credentials')) {
        return 'Invalid login credentials. If this is a new account, use Create account first.';
      }
      return error.message;
    } catch (_) {
      return 'Unable to log in right now. Please try again.';
    }
  }

  void toggleSaved(String jobId) {
    if (savedJobIds.contains(jobId)) {
      savedJobIds.remove(jobId);
      if (_repository != null) {
        unawaited(_runBackendSync(() => _repository.unsaveJob(jobId)));
      }
    } else {
      savedJobIds.add(jobId);
      if (_repository != null) {
        unawaited(_runBackendSync(() => _repository.saveJob(jobId)));
      }
    }
    notifyListeners();
  }

  void applyToJob(Job job, String coverNote) {
    final bool alreadyApplied = applications.any(
      (JobApplication app) => app.jobId == job.id,
    );
    if (alreadyApplied) {
      return;
    }

    applications.insert(
      0,
      JobApplication(
        id: 'a${applications.length + 1}',
        jobId: job.id,
        jobTitle: job.title,
        applicantName: currentUserName,
        coverNote: coverNote,
        createdAt: DateTime.now(),
      ),
    );

    notices.insert(
      0,
      AppNotice(
        id: 'n${notices.length + 1}',
        message: 'Application sent for "${job.title}".',
        createdAt: DateTime.now(),
      ),
    );
    if (_repository != null) {
      unawaited(
        _runBackendSync(
          () => _repository.applyToJob(
            jobId: job.id,
            jobTitle: job.title,
            coverNote: coverNote,
            applicantName: currentUserName,
          ),
        ),
      );
    }
    notifyListeners();
  }

  void postJob({
    required String title,
    required String location,
    required String salary,
    required EmploymentSector sector,
    required String description,
  }) {
    jobs.insert(
      0,
      Job(
        id: 'j${jobs.length + 1}',
        title: title,
        employerName: currentUserName,
        location: location,
        salary: salary,
        sector: sector,
        description: description,
      ),
    );
    notices.insert(
      0,
      AppNotice(
        id: 'n${notices.length + 1}',
        message: 'Job "$title" posted successfully.',
        createdAt: DateTime.now(),
      ),
    );
    if (_repository != null) {
      unawaited(
        _runBackendSync(
          () => _repository.postJob(
            title: title,
            employerName: currentUserName,
            location: location,
            salary: salary,
            sector: sector,
            description: description,
          ),
        ),
      );
    }
    notifyListeners();
  }

  void updateApplicationStatus(String id, ApplicationStatus status) {
    for (final JobApplication app in applications) {
      if (app.id == id) {
        app.status = status;
        notices.insert(
          0,
          AppNotice(
            id: 'n${notices.length + 1}',
            message:
                'Application "${app.jobTitle}" marked ${statusLabel(status)}.',
            createdAt: DateTime.now(),
          ),
        );
        if (_repository != null && app.id.contains('-')) {
          unawaited(
            _runBackendSync(
              () => _repository.updateApplicationStatus(
                applicationId: app.id,
                status: status,
              ),
            ),
          );
        }
        notifyListeners();
        return;
      }
    }
  }

  void toggleJobVisibility(String jobId) {
    for (final Job job in jobs) {
      if (job.id == jobId) {
        job.isHidden = !job.isHidden;
        if (_repository != null && job.id.contains('-')) {
          unawaited(
            _runBackendSync(
              () => _repository.updateJobVisibility(
                jobId: jobId,
                isHidden: job.isHidden,
              ),
            ),
          );
        }
        notifyListeners();
        return;
      }
    }
  }

  void sendMessage(String threadId, String body) {
    if (body.trim().isEmpty) {
      return;
    }
    for (final ConversationThread thread in conversations) {
      if (thread.id == threadId) {
        final String messageText = body.trim();
        thread.messages.add(
          ChatMessage(from: 'You', body: body.trim(), time: DateTime.now()),
        );
        if (_repository != null && thread.id.contains('-')) {
          unawaited(
            _runBackendSync(
              () => _repository.sendMessage(
                threadId: threadId,
                body: messageText,
              ),
              refreshAfter: false,
            ),
          );
        }
        notifyListeners();
        return;
      }
    }
  }

  void markNoticeRead(String id) {
    for (final AppNotice notice in notices) {
      if (notice.id == id) {
        notice.read = true;
        if (_repository != null) {
          unawaited(
            _runBackendSync(
              () => _repository.markNoticeRead(id),
              refreshAfter: false,
            ),
          );
        }
        notifyListeners();
        return;
      }
    }
  }

  int get unreadNoticeCount => notices.where((AppNotice n) => !n.read).length;

  void updateSeekerProfile({
    required String bio,
    required List<String> skills,
  }) {
    seekerBio = bio;
    seekerSkills
      ..clear()
      ..addAll(skills);
    if (_repository != null && role != null) {
      unawaited(
        _runBackendSync(
          () => _repository.updateProfile(
            fullName: currentUserName,
            role: role!,
            district: district,
            bio: seekerBio,
            skills: seekerSkills,
            companyName: role == UserRole.employer ? currentUserName : '',
          ),
        ),
      );
    }
    notifyListeners();
  }

  List<Job> discoverableJobs() {
    final String districtLower = district.toLowerCase();
    return jobs
        .where((Job job) => !job.isHidden)
        .where(
          (Job job) =>
              job.location.toLowerCase().contains(districtLower) ||
              job.location.toLowerCase().contains('hybrid') ||
              job.location.toLowerCase().contains('remote'),
        )
        .toList();
  }

  static String sectorLabel(EmploymentSector sector) {
    switch (sector) {
      case EmploymentSector.informal:
        return 'Informal';
      case EmploymentSector.startup:
        return 'Startup';
      case EmploymentSector.formal:
        return 'Formal';
    }
  }

  static String statusLabel(ApplicationStatus status) {
    switch (status) {
      case ApplicationStatus.pending:
        return 'Pending';
      case ApplicationStatus.shortlisted:
        return 'Shortlisted';
      case ApplicationStatus.rejected:
        return 'Rejected';
      case ApplicationStatus.hired:
        return 'Hired';
    }
  }
}

class LinkUpApp extends StatefulWidget {
  const LinkUpApp({super.key});

  @override
  State<LinkUpApp> createState() => _LinkUpAppState();
}

class _LinkUpAppState extends State<LinkUpApp> {
  final LinkUpState state = LinkUpState();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (BuildContext context, Widget? child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'LinkUp',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF1A4D8F),
              primary: const Color(0xFF1A4D8F),
              secondary: const Color(0xFFE88C17),
            ),
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFFF4F7FB),
          ),
          home: state.role == null
              ? RoleSelectionScreen(state: state)
              : DashboardShell(state: state),
        );
      },
    );
  }
}

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key, required this.state});

  final LinkUpState state;

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final List<String> ugandaDistricts = <String>[
    'Kampala',
    'Wakiso',
    'Mukono',
    'Jinja',
    'Mbarara',
    'Gulu',
    'Mbale',
    'Arua',
    'Fort Portal',
  ];
  String district = 'Kampala';
  UserRole selectedRole = UserRole.seeker;
  bool isSubmitting = false;
  bool hidePassword = true;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _signIn(UserRole role) {
    widget.state.signInAs(role, nameController.text, district);
  }

  Future<void> _registerWithEmail() async {
    setState(() {
      isSubmitting = true;
    });

    final String? error = await widget.state.registerWithEmail(
      email: emailController.text,
      password: passwordController.text,
      name: nameController.text,
      selectedDistrict: district,
      selectedRole: selectedRole,
    );

    if (!mounted) {
      return;
    }
    setState(() {
      isSubmitting = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error ?? 'Account created and signed in successfully.',
        ),
      ),
    );
  }

  Future<void> _loginWithEmail() async {
    setState(() {
      isSubmitting = true;
    });

    final String? error = await widget.state.loginWithEmail(
      email: emailController.text,
      password: passwordController.text,
      fallbackRole: selectedRole,
      fallbackName: nameController.text.trim().isEmpty
          ? 'Guest User'
          : nameController.text.trim(),
      fallbackDistrict: district,
    );

    if (!mounted) {
      return;
    }
    setState(() {
      isSubmitting = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'Login successful.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool compact = width < 850;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF123A6B), Color(0xFF0F2545)],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Card(
              margin: const EdgeInsets.all(24),
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'LinkUp Uganda',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Connecting job seekers with informal, startup, and formal employers in real time.',
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: district,
                        items: ugandaDistricts
                            .map(
                              (String d) => DropdownMenuItem<String>(
                                value: d,
                                child: Text(d),
                              ),
                            )
                            .toList(),
                        onChanged: (String? value) {
                          if (value != null) {
                            setState(() {
                              district = value;
                            });
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'District',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Account login',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: passwordController,
                        obscureText: hidePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                hidePassword = !hidePassword;
                              });
                            },
                            icon: Icon(
                              hidePassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<UserRole>(
                        initialValue: selectedRole,
                        items: UserRole.values
                            .map(
                              (UserRole nextRole) => DropdownMenuItem<UserRole>(
                                value: nextRole,
                                child: Text(
                                  nextRole.name[0].toUpperCase() +
                                      nextRole.name.substring(1),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (UserRole? value) {
                          if (value != null) {
                            setState(() {
                              selectedRole = value;
                            });
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'Account role',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: <Widget>[
                          FilledButton.icon(
                            onPressed: isSubmitting ? null : _registerWithEmail,
                            icon: const Icon(Icons.person_add_alt_1),
                            label: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(isSubmitting
                                  ? 'Processing...'
                                  : 'Create account'),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: isSubmitting ? null : _loginWithEmail,
                            icon: const Icon(Icons.login),
                            label: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text('Login to existing account'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Divider(),
                      const SizedBox(height: 10),
                      const Text(
                        'Quick demo mode (no email/password)',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: <Widget>[
                          SizedBox(
                            width: compact ? double.infinity : 290,
                            child: FilledButton.icon(
                              onPressed: () => _signIn(UserRole.seeker),
                              icon: const Icon(Icons.person_search),
                              label: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 14),
                                child: Text('Continue as Job Seeker'),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: compact ? double.infinity : 290,
                            child: FilledButton.icon(
                              onPressed: () => _signIn(UserRole.employer),
                              icon: const Icon(Icons.business_center),
                              label: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 14),
                                child: Text('Continue as Employer'),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: compact ? double.infinity : 290,
                            child: OutlinedButton.icon(
                              onPressed: () => _signIn(UserRole.admin),
                              icon: const Icon(Icons.admin_panel_settings),
                              label: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 14),
                                child: Text('Continue as Admin'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DashboardShell extends StatefulWidget {
  const DashboardShell({super.key, required this.state});

  final LinkUpState state;

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  int index = 0;

  List<String> _labelsForRole(UserRole role) {
    switch (role) {
      case UserRole.seeker:
        return <String>[
          'Discover',
          'Saved',
          'Applications',
          'Messages',
          'Profile',
        ];
      case UserRole.employer:
        return <String>[
          'Dashboard',
          'Post Job',
          'Applicants',
          'Messages',
          'Company',
        ];
      case UserRole.admin:
        return <String>['Moderation', 'Reports', 'Users', 'Analytics'];
    }
  }

  List<IconData> _iconsForRole(UserRole role) {
    switch (role) {
      case UserRole.seeker:
        return <IconData>[
          Icons.search,
          Icons.bookmark,
          Icons.assignment,
          Icons.forum,
          Icons.person,
        ];
      case UserRole.employer:
        return <IconData>[
          Icons.dashboard,
          Icons.post_add,
          Icons.people,
          Icons.forum,
          Icons.store,
        ];
      case UserRole.admin:
        return <IconData>[
          Icons.policy,
          Icons.flag,
          Icons.group,
          Icons.bar_chart,
        ];
    }
  }

  Widget _buildBody(UserRole role) {
    switch (role) {
      case UserRole.seeker:
        return _seekerScreens(widget.state)[index];
      case UserRole.employer:
        return _employerScreens(widget.state)[index];
      case UserRole.admin:
        return _adminScreens(widget.state)[index];
    }
  }

  @override
  Widget build(BuildContext context) {
    final UserRole role = widget.state.role!;
    final List<String> labels = _labelsForRole(role);
    final List<IconData> icons = _iconsForRole(role);
    final bool isWide = MediaQuery.of(context).size.width >= 920;

    return Scaffold(
      appBar: AppBar(
        title: const Text('LinkUp'),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Chip(
                label: Text('${widget.state.unreadNoticeCount} alerts'),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () {
              showModalBottomSheet<void>(
                context: context,
                showDragHandle: true,
                builder: (BuildContext context) {
                  return NotificationPanel(state: widget.state);
                },
              );
            },
            icon: const Icon(Icons.notifications),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: widget.state.signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Row(
        children: <Widget>[
          if (isWide)
            NavigationRail(
              selectedIndex: index,
              onDestinationSelected: (int next) {
                setState(() {
                  index = next;
                });
              },
              destinations: List<NavigationRailDestination>.generate(
                labels.length,
                (int i) => NavigationRailDestination(
                  icon: Icon(icons[i]),
                  label: Text(labels[i]),
                ),
              ),
            ),
          Expanded(child: _buildBody(role)),
        ],
      ),
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (int next) {
                setState(() {
                  index = next;
                });
              },
              destinations: List<NavigationDestination>.generate(
                labels.length,
                (int i) => NavigationDestination(
                  icon: Icon(icons[i]),
                  label: labels[i],
                ),
              ),
            ),
    );
  }
}

class NotificationPanel extends StatelessWidget {
  const NotificationPanel({super.key, required this.state});

  final LinkUpState state;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemBuilder: (BuildContext context, int i) {
        final AppNotice notice = state.notices[i];
        return ListTile(
          leading: Icon(
            notice.read ? Icons.mark_email_read : Icons.mark_email_unread,
          ),
          title: Text(notice.message),
          subtitle: Text(notice.createdAt.toLocal().toString()),
          trailing: notice.read
              ? null
              : TextButton(
                  onPressed: () => state.markNoticeRead(notice.id),
                  child: const Text('Mark read'),
                ),
        );
      },
      separatorBuilder: (_, __) => const Divider(),
      itemCount: state.notices.length,
    );
  }
}

List<Widget> _seekerScreens(LinkUpState state) {
  return <Widget>[
    SeekerDiscoverScreen(state: state),
    SeekerSavedScreen(state: state),
    SeekerApplicationsScreen(state: state),
    MessagingScreen(state: state),
    SeekerProfileScreen(state: state),
  ];
}

List<Widget> _employerScreens(LinkUpState state) {
  return <Widget>[
    EmployerOverviewScreen(state: state),
    EmployerPostJobScreen(state: state),
    EmployerApplicantsScreen(state: state),
    MessagingScreen(state: state),
    EmployerCompanyScreen(state: state),
  ];
}

List<Widget> _adminScreens(LinkUpState state) {
  return <Widget>[
    AdminModerationScreen(state: state),
    AdminReportsScreen(state: state),
    AdminUsersScreen(state: state),
    AdminAnalyticsScreen(state: state),
  ];
}

class SeekerDiscoverScreen extends StatefulWidget {
  const SeekerDiscoverScreen({super.key, required this.state});

  final LinkUpState state;

  @override
  State<SeekerDiscoverScreen> createState() => _SeekerDiscoverScreenState();
}

class _SeekerDiscoverScreenState extends State<SeekerDiscoverScreen> {
  EmploymentSector? selectedSector;
  final TextEditingController searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final List<Job> jobs = widget.state.discoverableJobs().where((Job job) {
      final bool sectorOk =
          selectedSector == null || job.sector == selectedSector;
      final String query = searchController.text.toLowerCase().trim();
      final bool queryOk = query.isEmpty ||
          job.title.toLowerCase().contains(query) ||
          job.description.toLowerCase().contains(query) ||
          job.employerName.toLowerCase().contains(query);
      return sectorOk && queryOk;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        const Text(
          'Live Job Feed',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'District: ${widget.state.district}',
          style: const TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: searchController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search role, employer, or keyword',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            DropdownButton<EmploymentSector?>(
              value: selectedSector,
              onChanged: (EmploymentSector? next) {
                setState(() {
                  selectedSector = next;
                });
              },
              items: <DropdownMenuItem<EmploymentSector?>>[
                const DropdownMenuItem<EmploymentSector?>(
                  value: null,
                  child: Text('All sectors'),
                ),
                ...EmploymentSector.values.map(
                  (EmploymentSector value) =>
                      DropdownMenuItem<EmploymentSector?>(
                    value: value,
                    child: Text(LinkUpState.sectorLabel(value)),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...jobs.map(
          (Job job) => Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          job.title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Chip(label: Text(LinkUpState.sectorLabel(job.sector))),
                    ],
                  ),
                  Text(job.employerName),
                  Text('${job.location}  |  ${job.salary}'),
                  const SizedBox(height: 8),
                  Text(job.description),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      FilledButton(
                        onPressed: () => _applyToJob(context, job),
                        child: const Text('Apply now'),
                      ),
                      OutlinedButton(
                        onPressed: () => widget.state.toggleSaved(job.id),
                        child: Text(
                          widget.state.savedJobIds.contains(job.id)
                              ? 'Saved'
                              : 'Save job',
                        ),
                      ),
                      TextButton(
                        onPressed: () => _openJobDetails(context, job),
                        child: const Text('View details'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _openJobDetails(BuildContext context, Job job) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(job.title),
          content: SingleChildScrollView(child: Text(job.description)),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _applyToJob(BuildContext context, Job job) {
    final TextEditingController coverController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Apply: ${job.title}'),
          content: TextField(
            controller: coverController,
            maxLines: 4,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Add a short cover note',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                widget.state.applyToJob(job, coverController.text);
                Navigator.of(context).pop();
              },
              child: const Text('Submit application'),
            ),
          ],
        );
      },
    );
  }
}

class SeekerSavedScreen extends StatelessWidget {
  const SeekerSavedScreen({super.key, required this.state});

  final LinkUpState state;

  @override
  Widget build(BuildContext context) {
    final List<Job> saved = state.jobs
        .where((Job job) => state.savedJobIds.contains(job.id) && !job.isHidden)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        const Text(
          'Saved Jobs',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        if (saved.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No saved jobs yet.'),
            ),
          ),
        ...saved.map(
          (Job job) => ListTile(
            title: Text(job.title),
            subtitle: Text('${job.employerName} | ${job.location}'),
            trailing: IconButton(
              icon: const Icon(Icons.bookmark_remove),
              onPressed: () => state.toggleSaved(job.id),
            ),
          ),
        ),
      ],
    );
  }
}

class SeekerApplicationsScreen extends StatelessWidget {
  const SeekerApplicationsScreen({super.key, required this.state});

  final LinkUpState state;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        const Text(
          'My Applications',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        if (state.applications.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No applications submitted yet.'),
            ),
          ),
        ...state.applications.map(
          (JobApplication app) => Card(
            child: ListTile(
              title: Text(app.jobTitle),
              subtitle: Text(
                '${app.applicantName} | ${app.createdAt.toLocal()}\nStatus: ${LinkUpState.statusLabel(app.status)}',
              ),
              isThreeLine: true,
            ),
          ),
        ),
      ],
    );
  }
}

class MessagingScreen extends StatefulWidget {
  const MessagingScreen({super.key, required this.state});

  final LinkUpState state;

  @override
  State<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen> {
  String? selectedThreadId;
  final TextEditingController messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.state.conversations.isNotEmpty) {
      selectedThreadId = widget.state.conversations.first.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ConversationThread? active = widget.state.conversations
        .where((ConversationThread thread) => thread.id == selectedThreadId)
        .cast<ConversationThread?>()
        .firstWhere(
          (ConversationThread? value) => value != null,
          orElse: () => null,
        );

    return Row(
      children: <Widget>[
        SizedBox(
          width: 280,
          child: ListView(
            children: widget.state.conversations
                .map(
                  (ConversationThread thread) => ListTile(
                    selected: thread.id == selectedThreadId,
                    title: Text(thread.withName),
                    subtitle: Text(
                      thread.messages.isEmpty
                          ? 'No messages'
                          : thread.messages.last.body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      setState(() {
                        selectedThreadId = thread.id;
                      });
                    },
                  ),
                )
                .toList(),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: active == null
              ? const Center(child: Text('Select a conversation'))
              : Column(
                  children: <Widget>[
                    ListTile(
                      title: Text(active.withName),
                      subtitle: const Text('Direct chat'),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(12),
                        children: active.messages
                            .map(
                              (ChatMessage message) => Align(
                                alignment: message.from == 'You'
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 5,
                                  ),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: message.from == 'You'
                                        ? const Color(0xFFDDEBFF)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${message.from}: ${message.body}',
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: TextField(
                              controller: messageController,
                              decoration: const InputDecoration(
                                hintText: 'Write a message',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () {
                              if (selectedThreadId != null) {
                                widget.state.sendMessage(
                                  selectedThreadId!,
                                  messageController.text,
                                );
                                messageController.clear();
                              }
                            },
                            child: const Text('Send'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class SeekerProfileScreen extends StatefulWidget {
  const SeekerProfileScreen({super.key, required this.state});

  final LinkUpState state;

  @override
  State<SeekerProfileScreen> createState() => _SeekerProfileScreenState();
}

class _SeekerProfileScreenState extends State<SeekerProfileScreen> {
  late final TextEditingController bioController;
  late final TextEditingController skillsController;

  @override
  void initState() {
    super.initState();
    bioController = TextEditingController(text: widget.state.seekerBio);
    skillsController = TextEditingController(
      text: widget.state.seekerSkills.join(', '),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        const Text(
          'Profile',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: bioController,
          maxLines: 5,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Bio',
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: skillsController,
          maxLines: 3,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Skills (comma separated)',
          ),
        ),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: () {
            widget.state.updateSeekerProfile(
              bio: bioController.text.trim(),
              skills: skillsController.text
                  .split(',')
                  .map((String s) => s.trim())
                  .where((String s) => s.isNotEmpty)
                  .toList(),
            );
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Profile updated.')));
          },
          child: const Text('Save profile'),
        ),
        const SizedBox(height: 20),
        OutlinedButton(
          onPressed: () async {
            final bool? confirmed = await showDialog<bool>(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('Delete account?'),
                  content: const Text(
                    'This removes your profile and app data from LinkUp. This action cannot be undone.',
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Delete'),
                    ),
                  ],
                );
              },
            );

            if (confirmed != true) {
              return;
            }

            final String? result = await widget.state.deleteAccount();
            if (!context.mounted) {
              return;
            }

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  result ?? 'Account deleted. You have been signed out.',
                ),
              ),
            );
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            side: const BorderSide(color: Colors.red),
          ),
          child: const Text('Delete account'),
        ),
      ],
    );
  }
}

class EmployerOverviewScreen extends StatelessWidget {
  const EmployerOverviewScreen({super.key, required this.state});

  final LinkUpState state;

  @override
  Widget build(BuildContext context) {
    final List<Job> myJobs = state.jobs
        .where((Job job) => job.employerName == state.currentUserName)
        .toList();
    final int totalApplicants = state.applications.length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        const Text(
          'Employer Dashboard',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            _metricCard('Active Jobs', '${myJobs.length}'),
            _metricCard('Applicants', '$totalApplicants'),
            _metricCard('Unread Alerts', '${state.unreadNoticeCount}'),
          ],
        ),
        const SizedBox(height: 12),
        ...myJobs.map(
          (Job job) => ListTile(
            title: Text(job.title),
            subtitle: Text('${job.location} | ${job.salary}'),
            trailing: Chip(label: Text(job.isHidden ? 'Hidden' : 'Visible')),
          ),
        ),
      ],
    );
  }
}

Widget _metricCard(String label, String value) {
  return SizedBox(
    width: 220,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(label, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    ),
  );
}

class EmployerPostJobScreen extends StatefulWidget {
  const EmployerPostJobScreen({super.key, required this.state});

  final LinkUpState state;

  @override
  State<EmployerPostJobScreen> createState() => _EmployerPostJobScreenState();
}

class _EmployerPostJobScreenState extends State<EmployerPostJobScreen> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController salaryController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  EmploymentSector sector = EmploymentSector.informal;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        const Text(
          'Post New Job',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: titleController,
          decoration: const InputDecoration(
            labelText: 'Job title',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: locationController,
          decoration: const InputDecoration(
            labelText: 'Location',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: salaryController,
          decoration: const InputDecoration(
            labelText: 'Compensation',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<EmploymentSector>(
          initialValue: sector,
          items: EmploymentSector.values
              .map(
                (EmploymentSector s) => DropdownMenuItem<EmploymentSector>(
                  value: s,
                  child: Text(LinkUpState.sectorLabel(s)),
                ),
              )
              .toList(),
          onChanged: (EmploymentSector? next) {
            if (next != null) {
              setState(() {
                sector = next;
              });
            }
          },
          decoration: const InputDecoration(
            labelText: 'Sector',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: descriptionController,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Description',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: () {
            if (titleController.text.trim().isEmpty ||
                locationController.text.trim().isEmpty ||
                salaryController.text.trim().isEmpty ||
                descriptionController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Complete all fields first.')),
              );
              return;
            }

            widget.state.postJob(
              title: titleController.text.trim(),
              location: locationController.text.trim(),
              salary: salaryController.text.trim(),
              sector: sector,
              description: descriptionController.text.trim(),
            );

            titleController.clear();
            locationController.clear();
            salaryController.clear();
            descriptionController.clear();

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Job posted successfully.')),
            );
          },
          child: const Text('Publish job'),
        ),
      ],
    );
  }
}

class EmployerApplicantsScreen extends StatelessWidget {
  const EmployerApplicantsScreen({super.key, required this.state});

  final LinkUpState state;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        const Text(
          'Applicants Pipeline',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        if (state.applications.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No applications yet.'),
            ),
          ),
        ...state.applications.map(
          (JobApplication app) => Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    app.jobTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  Text('Applicant: ${app.applicantName}'),
                  const SizedBox(height: 6),
                  Text(
                    app.coverNote.isEmpty ? 'No cover note.' : app.coverNote,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ApplicationStatus.values
                        .map(
                          (ApplicationStatus status) => ChoiceChip(
                            selected: app.status == status,
                            label: Text(LinkUpState.statusLabel(status)),
                            onSelected: (_) =>
                                state.updateApplicationStatus(app.id, status),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class EmployerCompanyScreen extends StatelessWidget {
  const EmployerCompanyScreen({super.key, required this.state});

  final LinkUpState state;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        const Text(
          'Company Profile',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  state.currentUserName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text('Sector focus: startup + informal partnerships'),
                Text('Operational district: ${state.district}'),
                const SizedBox(height: 8),
                const Text(
                  'Verification status: Verified on LinkUp',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class AdminModerationScreen extends StatelessWidget {
  const AdminModerationScreen({super.key, required this.state});

  final LinkUpState state;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        const Text(
          'Content Moderation',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        ...state.jobs.map(
          (Job job) => Card(
            child: SwitchListTile(
              title: Text(job.title),
              subtitle: Text('${job.employerName} | ${job.location}'),
              value: !job.isHidden,
              onChanged: (_) => state.toggleJobVisibility(job.id),
              secondary: Chip(label: Text(LinkUpState.sectorLabel(job.sector))),
            ),
          ),
        ),
      ],
    );
  }
}

class AdminReportsScreen extends StatelessWidget {
  const AdminReportsScreen({super.key, required this.state});

  final LinkUpState state;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        const Text(
          'Reports and Escalations',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        const ListTile(
          leading: Icon(Icons.report_problem),
          title: Text('Potential duplicate job posting detected.'),
          subtitle: Text('Severity: Medium | Source: Automated quality check'),
        ),
        const Divider(),
        const ListTile(
          leading: Icon(Icons.gpp_good),
          title: Text('Employer identity verification completed.'),
          subtitle: Text('Source: Compliance workflow'),
        ),
      ],
    );
  }
}

class AdminUsersScreen extends StatelessWidget {
  const AdminUsersScreen({super.key, required this.state});

  final LinkUpState state;

  @override
  Widget build(BuildContext context) {
    final Set<String> employers =
        state.jobs.map((Job e) => e.employerName).toSet();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        const Text(
          'Users and Organizations',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        ListTile(
          leading: const Icon(Icons.badge),
          title: const Text('Job seekers'),
          trailing: Text(
            '${state.applications.map((JobApplication a) => a.applicantName).toSet().length}',
          ),
        ),
        ListTile(
          leading: const Icon(Icons.corporate_fare),
          title: const Text('Employers'),
          trailing: Text('${employers.length}'),
        ),
        const Divider(),
        ...employers.map(
          (String company) => ListTile(
            leading: const Icon(Icons.business),
            title: Text(company),
            subtitle: const Text('Verified employer'),
          ),
        ),
      ],
    );
  }
}

class AdminAnalyticsScreen extends StatelessWidget {
  const AdminAnalyticsScreen({super.key, required this.state});

  final LinkUpState state;

  @override
  Widget build(BuildContext context) {
    final int informal = state.jobs
        .where((Job j) => j.sector == EmploymentSector.informal)
        .length;
    final int startup = state.jobs
        .where((Job j) => j.sector == EmploymentSector.startup)
        .length;
    final int formal =
        state.jobs.where((Job j) => j.sector == EmploymentSector.formal).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        const Text(
          'Labour Market Analytics',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            _metricCard('Informal Jobs', '$informal'),
            _metricCard('Startup Jobs', '$startup'),
            _metricCard('Formal Jobs', '$formal'),
            _metricCard('Applications', '${state.applications.length}'),
          ],
        ),
        const SizedBox(height: 12),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Text(
              'Real-time insights pipeline ready: connect this screen to Firestore, Supabase, or REST analytics endpoints for production dashboards.',
            ),
          ),
        ),
      ],
    );
  }
}
