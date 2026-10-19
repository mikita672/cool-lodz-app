import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/user_profile_repository.dart';

/// The signed-in user's S03 choices (null before S03 or signed out).
final consentsProvider = FutureProvider<Consents?>((ref) async {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return null;
  return ref.watch(userProfileRepositoryProvider).loadConsents(uid);
}, retry: noRetry);
