import 'package:flutter/material.dart';
import 'package:kyco_mobile/core/models.dart';
import 'package:kyco_mobile/features/home/home_screen.dart';
import '_fakes.dart';
import '_harness.dart';

/// A fully-populated /v1/home composite (categories + services + why/how content)
/// so the richer home renders every section: hero, bento, service rail, how-it-
/// works, why-Kyco and the bottom CTAs. imageUrl left null → deterministic
/// placeholders (no network in goldens).
HomeComposite _rich() => const HomeComposite(
      categories: [
        ServiceCategory(id: 1, name: 'Vệ sinh nhà theo giờ', slug: 'home-cleaning'),
        ServiceCategory(id: 2, name: 'Tổng vệ sinh', slug: 'deep-cleaning'),
        ServiceCategory(id: 3, name: 'Vệ sinh máy lạnh', slug: 'ac-cleaning'),
        ServiceCategory(
            id: 4,
            name: 'Vệ sinh sofa – nệm – rèm cửa cao cấp định kỳ', // ellipsis canary
            slug: 'upholstery'),
        ServiceCategory(id: 5, name: 'Giặt thảm', slug: 'laundry'),
      ],
      services: [
        ServiceSummary(
            id: 101,
            name: 'Vệ sinh nhà theo giờ',
            category: 'Vệ sinh nhà',
            basePriceVnd: 480000,
            durationMinutes: 120),
        ServiceSummary(
            id: 102,
            name: 'Vệ sinh máy lạnh treo tường 2 chiều công suất lớn',
            category: 'Máy lạnh',
            basePriceVnd: 250000,
            durationMinutes: 60),
        ServiceSummary(
            id: 103, name: 'Giặt thảm', category: 'Giặt', basePriceVnd: 350000),
      ],
      how: [
        ContentSection(id: 1, slug: 'home_how_1', title: 'Chọn dịch vụ', body: 'Chọn dịch vụ bạn cần trong vài giây.', orderIndex: 0),
        ContentSection(id: 2, slug: 'home_how_2', title: 'Đặt lịch', body: 'Chọn thời gian và địa chỉ phù hợp.', orderIndex: 1),
        ContentSection(id: 3, slug: 'home_how_3', title: 'Thư giãn', body: 'Đối tác đến đúng giờ và hoàn thành.', orderIndex: 2),
      ],
      why: [
        ContentSection(id: 11, slug: 'home_why_1', title: 'Đối tác đã xác minh', body: 'Được đào tạo và kiểm tra kỹ.', orderIndex: 0),
        ContentSection(id: 12, slug: 'home_why_2', title: 'Bảo đảm chất lượng', body: 'Không hài lòng, làm lại miễn phí.', orderIndex: 1),
        ContentSection(id: 13, slug: 'home_why_3', title: 'Thanh toán linh hoạt', body: 'Tiền mặt sau khi hoàn thành.', orderIndex: 2),
        ContentSection(id: 14, slug: 'home_why_4', title: 'Đánh giá thực tế', body: 'Từ khách hàng đã sử dụng.', orderIndex: 3),
      ],
    );

void main() {
  // Guest cold-start (no greeting) — light, 2 sizes: compact + medium/expanded.
  for (final d in [GoldenDevice.iphone16, GoldenDevice.ipadAir]) {
    goldenTest('home_richer guest ${d.name}', (t) async {
      await pumpGoldenScreen(t,
          screen: const HomeScreen(),
          device: d,
          auth: Fakes.signedOut,
          home: _rich());
      await expectGolden(t, goldenName('home_richer', 'guest', d, Brightness.light));
    });
  }

  // Dark, same 2 sizes.
  for (final d in [GoldenDevice.iphone16, GoldenDevice.ipadAir]) {
    goldenTest('home_richer dark ${d.name}', (t) async {
      await pumpGoldenScreen(t,
          screen: const HomeScreen(),
          device: d,
          brightness: Brightness.dark,
          auth: Fakes.signedOut,
          home: _rich());
      await expectGolden(t, goldenName('home_richer', 'guest', d, Brightness.dark));
    });
  }

  // Signed-in → personalized greeting header (compact, light).
  goldenTest('home_richer signedin iphone16', (t) async {
    await pumpGoldenScreen(t,
        screen: const HomeScreen(),
        device: GoldenDevice.iphone16,
        auth: Fakes.signedIn,
        home: _rich());
    await expectGolden(
        t, goldenName('home_richer', 'signedin', GoldenDevice.iphone16, Brightness.light));
  });
}
