import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/appointment.dart';
import '../../../models/appointment_candidate.dart';
import '../../../services/supabase_service.dart';
import '../../auth/providers/auth_provider.dart';

/// 특정 그룹의 약속 목록. groupId 별로 캐시.
final groupAppointmentsProvider =
    FutureProvider.family<List<Appointment>, String>((ref, groupId) async {
      ref.watch(authStateProvider);
      return SupabaseService.listGroupAppointments(groupId);
    });

/// 약속 상세 (후보 + 표 수). appointmentId 별로 캐시.
final appointmentDetailProvider =
    FutureProvider.family<List<AppointmentCandidate>, String>((
      ref,
      appointmentId,
    ) async {
      ref.watch(authStateProvider);
      return SupabaseService.getAppointmentDetail(appointmentId);
    });
