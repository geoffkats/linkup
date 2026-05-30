import 'dart:typed_data';

import 'package:linkup/linkup_app.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BackendProfileSnapshot {
  const BackendProfileSnapshot({
    required this.fullName,
    required this.role,
    required this.district,
    required this.bio,
    required this.skills,
    required this.companyName,
  });

  final String fullName;
  final UserRole role;
  final String district;
  final String bio;
  final List<String> skills;
  final String companyName;
}

class LinkUpBackend {
  LinkUpBackend({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<Job>> fetchJobs({bool includeHidden = false}) async {
    dynamic query = _client.from('jobs').select();
    if (!includeHidden) {
      query = query.eq('is_hidden', false);
    }

    final List<dynamic> rows =
        await query.order('created_at', ascending: false);
    return rows.map(_jobFromRow).toList();
  }

  Future<List<AppNotice>> fetchNotices() async {
    final String userId = _requireUserId();
    final List<dynamic> rows = await _client
        .from('notices')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return rows.map(_noticeFromRow).toList();
  }

  Future<List<JobApplication>> fetchApplications(
      {required UserRole role}) async {
    final String userId = _requireUserId();
    if (role == UserRole.admin) {
      return <JobApplication>[];
    }

    final List<dynamic> rows;
    if (role == UserRole.employer) {
      rows = await _client
          .from('job_applications')
          .select(
            'id, job_id, job_title, applicant_name, cover_note, created_at, status, jobs!inner(owner_id)',
          )
          .eq('jobs.owner_id', userId)
          .order('created_at', ascending: false);
    } else {
      rows = await _client
          .from('job_applications')
          .select()
          .eq('applicant_id', userId)
          .order('created_at', ascending: false);
    }

    return rows.map(_applicationFromRow).toList();
  }

  Future<BackendProfileSnapshot?> fetchProfile() async {
    final String userId = _requireUserId();
    final Map<String, dynamic>? row =
        await _client.from('profiles').select().eq('id', userId).maybeSingle();

    if (row == null) {
      return null;
    }

    final List<dynamic> rawSkills =
        (row['skills'] as List<dynamic>?) ?? <dynamic>[];
    return BackendProfileSnapshot(
      fullName: row['full_name'] as String? ?? '',
      role: _roleFromValue(row['role'] as String?),
      district: row['district'] as String? ?? 'Kampala',
      bio: row['bio'] as String? ?? '',
      skills: rawSkills.map((dynamic item) => item.toString()).toList(),
      companyName: row['company_name'] as String? ?? '',
    );
  }

  Future<List<ConversationThread>> fetchConversations() async {
    final String userId = _requireUserId();
    final List<dynamic> threadRows = await _client
        .from('conversation_threads')
        .select('id, participant_one_id, participant_two_id, created_at')
        .or('participant_one_id.eq.$userId,participant_two_id.eq.$userId')
        .order('created_at', ascending: false);

    final List<ConversationThread> threads = <ConversationThread>[];
    for (final dynamic row in threadRows) {
      final Map<String, dynamic> threadData = row as Map<String, dynamic>;
      final List<dynamic> messageRows = await _client
          .from('conversation_messages')
          .select('sender_id, body, created_at')
          .eq('thread_id', threadData['id'] as String)
          .order('created_at', ascending: true);

      threads.add(
        ConversationThread(
          id: threadData['id'] as String,
          withName: _conversationLabel(threadData, userId),
          messages: messageRows.map((dynamic messageRow) {
            final Map<String, dynamic> messageData =
                messageRow as Map<String, dynamic>;
            final bool isCurrentUser =
                (messageData['sender_id'] as String?) == userId;
            return ChatMessage(
              from: isCurrentUser
                  ? 'You'
                  : _conversationLabel(threadData, userId),
              body: messageData['body'] as String? ?? '',
              time: DateTime.parse(messageData['created_at'] as String),
            );
          }).toList(),
        ),
      );
    }

    return threads;
  }

  Future<Set<String>> fetchSavedJobIds() async {
    final String userId = _requireUserId();
    final List<dynamic> rows =
        await _client.from('saved_jobs').select('job_id').eq('user_id', userId);
    return rows
        .map((dynamic row) => (row as Map<String, dynamic>)['job_id'] as String)
        .toSet();
  }

  Future<void> saveJob(String jobId) async {
    final String userId = _requireUserId();
    await _client.from('saved_jobs').upsert(<String, dynamic>{
      'user_id': userId,
      'job_id': jobId,
    });
  }

  Future<void> unsaveJob(String jobId) async {
    final String userId = _requireUserId();
    await _client
        .from('saved_jobs')
        .delete()
        .eq('user_id', userId)
        .eq('job_id', jobId);
  }

  Future<void> applyToJob({
    required String jobId,
    required String jobTitle,
    required String coverNote,
    required String applicantName,
  }) async {
    final String userId = _requireUserId();
    await _client.from('job_applications').insert(<String, dynamic>{
      'job_id': jobId,
      'job_title': jobTitle,
      'applicant_id': userId,
      'applicant_name': applicantName,
      'cover_note': coverNote,
      'status': ApplicationStatus.pending.name,
    });

    await _client.from('notices').insert(<String, dynamic>{
      'user_id': userId,
      'message': 'Application sent for "$jobTitle".',
      'is_read': false,
    });
  }

  Future<void> postJob({
    required String title,
    required String employerName,
    required String location,
    required String salary,
    required EmploymentSector sector,
    required String description,
    bool isHidden = false,
  }) async {
    final String userId = _requireUserId();
    await _client.from('jobs').insert(<String, dynamic>{
      'owner_id': userId,
      'title': title,
      'employer_name': employerName,
      'location': location,
      'salary': salary,
      'sector': sector.name,
      'description': description,
      'is_hidden': isHidden,
    });
  }

  Future<void> updateProfile({
    required String fullName,
    required UserRole role,
    required String district,
    required String bio,
    required List<String> skills,
    String companyName = '',
    String phone = '',
    String avatarUrl = '',
    String website = '',
  }) async {
    final String userId = _requireUserId();
    await _client.from('profiles').upsert(<String, dynamic>{
      'id': userId,
      'full_name': fullName,
      'role': role.name,
      'district': district,
      'bio': bio,
      'skills': skills,
      'company_name': companyName,
      'phone': phone,
      'avatar_url': avatarUrl,
      'website': website,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> deleteCurrentAccountData() async {
    final String userId = _requireUserId();

    final List<dynamic> ownedJobs =
        await _client.from('jobs').select('id').eq('owner_id', userId);
    final List<String> ownedJobIds = ownedJobs
        .map((dynamic row) => (row as Map<String, dynamic>)['id'] as String)
        .toList();

    if (ownedJobIds.isNotEmpty) {
      await _client
          .from('job_applications')
          .delete()
          .inFilter('job_id', ownedJobIds);
      await _client.from('saved_jobs').delete().inFilter('job_id', ownedJobIds);
      await _client.from('jobs').delete().eq('owner_id', userId);
    }

    await _client.from('job_applications').delete().eq('applicant_id', userId);
    await _client.from('saved_jobs').delete().eq('user_id', userId);
    await _client.from('notices').delete().eq('user_id', userId);
    await _client
        .from('conversation_messages')
        .delete()
        .eq('sender_id', userId);
    await _client
        .from('conversation_threads')
        .delete()
        .or('participant_one_id.eq.$userId,participant_two_id.eq.$userId');
    await _client.from('profiles').delete().eq('id', userId);
  }

  Future<String> uploadAvatar({
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final String userId = _requireUserId();
    final String objectPath =
        '$userId/avatar.${fileExtension.replaceFirst('.', '')}';
    final String normalizedExtension =
        fileExtension.replaceFirst('.', '').toLowerCase();
    await _client.storage.from('avatars').uploadBinary(
          objectPath,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: 'image/$normalizedExtension',
          ),
        );
    return _client.storage.from('avatars').getPublicUrl(objectPath);
  }

  Future<void> markNoticeRead(String noticeId) async {
    final String userId = _requireUserId();
    await _client
        .from('notices')
        .update(<String, dynamic>{'is_read': true})
        .eq('id', noticeId)
        .eq('user_id', userId);
  }

  Future<void> updateApplicationStatus({
    required String applicationId,
    required ApplicationStatus status,
  }) async {
    await _client.from('job_applications').update(
        <String, dynamic>{'status': status.name}).eq('id', applicationId);
  }

  Future<void> updateJobVisibility({
    required String jobId,
    required bool isHidden,
  }) async {
    await _client
        .from('jobs')
        .update(<String, dynamic>{'is_hidden': isHidden}).eq('id', jobId);
  }

  Future<void> sendMessage({
    required String threadId,
    required String body,
  }) async {
    final String userId = _requireUserId();
    await _client.from('conversation_messages').insert(<String, dynamic>{
      'thread_id': threadId,
      'sender_id': userId,
      'body': body,
    });
  }

  String _requireUserId() {
    final User? user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No Supabase user session is available.');
    }
    return user.id;
  }

  Job _jobFromRow(dynamic row) {
    final Map<String, dynamic> data = row as Map<String, dynamic>;
    return Job(
      id: data['id'] as String,
      title: data['title'] as String? ?? '',
      employerName: data['employer_name'] as String? ?? '',
      location: data['location'] as String? ?? '',
      salary: data['salary'] as String? ?? '',
      sector: _sectorFromValue(data['sector'] as String?),
      description: data['description'] as String? ?? '',
      isHidden: data['is_hidden'] as bool? ?? false,
    );
  }

  JobApplication _applicationFromRow(dynamic row) {
    final Map<String, dynamic> data = row as Map<String, dynamic>;
    return JobApplication(
      id: data['id'] as String,
      jobId: data['job_id'] as String? ?? '',
      jobTitle: data['job_title'] as String? ?? '',
      applicantName: data['applicant_name'] as String? ?? '',
      coverNote: data['cover_note'] as String? ?? '',
      createdAt: DateTime.parse(data['created_at'] as String),
      status: _applicationStatusFromValue(data['status'] as String?),
    );
  }

  AppNotice _noticeFromRow(dynamic row) {
    final Map<String, dynamic> data = row as Map<String, dynamic>;
    return AppNotice(
      id: data['id'] as String,
      message: data['message'] as String? ?? '',
      createdAt: DateTime.parse(data['created_at'] as String),
      read: data['is_read'] as bool? ?? false,
    );
  }

  EmploymentSector _sectorFromValue(String? value) {
    return EmploymentSector.values.firstWhere(
      (EmploymentSector sector) => sector.name == value,
      orElse: () => EmploymentSector.informal,
    );
  }

  UserRole _roleFromValue(String? value) {
    return UserRole.values.firstWhere(
      (UserRole role) => role.name == value,
      orElse: () => UserRole.seeker,
    );
  }

  ApplicationStatus _applicationStatusFromValue(String? value) {
    return ApplicationStatus.values.firstWhere(
      (ApplicationStatus status) => status.name == value,
      orElse: () => ApplicationStatus.pending,
    );
  }

  String _conversationLabel(
    Map<String, dynamic> threadData,
    String currentUserId,
  ) {
    final bool isSelfThread =
        threadData['participant_one_id'] == currentUserId &&
            threadData['participant_two_id'] == currentUserId;
    return isSelfThread ? 'Saved conversation' : 'LinkUp contact';
  }
}
