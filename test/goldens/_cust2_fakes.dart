import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyco_mobile/core/models.dart';
import 'package:kyco_mobile/features/home/home_providers.dart';

/// Fixed booking-detail composites for goldens (no network). Times at noon UTC
/// so the rendered date is TZ-stable under `TZ=UTC`.
BookingDetail fakeBookingDetail(int id) => switch (id) {
      1040 => BookingDetail.fromPage({
          'booking': {
            'id': 1040, 'status': 'COMPLETED', 'totalVnd': 2400000, 'paymentMethod': 'cash',
            'createdAt': '2026-01-08T12:00:00Z', 'scheduledAt': '2026-01-10T12:00:00Z',
            'addressLine': '12 Nguyễn Huệ', 'ward': 'Bến Nghé', 'district': 'Quận 1',
            'notes': 'Có nuôi mèo', 'confirmationCode': 'KY-1040', 'completedAt': '2026-01-10T15:00:00Z',
          },
          'service': {'id': 3, 'name': 'Tổng vệ sinh'},
          'job': {'providerId': 4, 'claimedAt': '2026-01-08T13:00:00Z', 'startedAt': '2026-01-10T12:05:00Z', 'finishedAt': '2026-01-10T14:50:00Z'},
          'provider': {'id': 4, 'name': 'Nguyễn Thị Lan'},
          'hasReview': false,
        }),
      _ => BookingDetail.fromPage({
          'booking': {
            'id': id, 'status': 'PENDING', 'totalVnd': 480000, 'paymentMethod': 'cash',
            'createdAt': '2026-01-15T12:00:00Z', 'scheduledAt': '2026-01-17T12:00:00Z',
            'addressLine': '45 Lê Lợi', 'ward': 'Bến Thành', 'district': 'Quận 1',
            'notes': 'Gọi trước 15 phút', 'confirmationCode': 'KY-$id',
          },
          'service': {'id': 1, 'name': 'Vệ sinh nhà theo giờ'},
          'hasReview': false,
        }),
    };

/// Wrap [child] so `bookingDetailProvider` is served from [fakeBookingDetail].
Widget withFakeBookingDetail(Widget child) => ProviderScope(
      overrides: [
        bookingDetailProvider.overrideWith((ref, id) => Future.value(fakeBookingDetail(id))),
      ],
      child: child,
    );
