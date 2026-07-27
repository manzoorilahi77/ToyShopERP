import 'app_env.dart';

class ApiConfig {
  ApiConfig._();

  // The host is resolved to the deployed subdomain:
  static String get _host => 'toys.aspirasys.in';

  static String get baseUrl => 'https://$_host/api/v1';

  static String get authPublicUsers => '$baseUrl/auth/users';
  static String get authLogin => '$baseUrl/auth/login';
  static String get authRefreshToken => '$baseUrl/auth/refresh-token';

  static String get dashboardOwner => '$baseUrl/dashboard/owner';
  static String get dashboardStaff => '$baseUrl/dashboard/staff';

  static String get products => '$baseUrl/products';
  static String get categories => '$baseUrl/categories';
  static String get branches => '$baseUrl/branches';
  static String get sales => '$baseUrl/sales';
  static String get salesMySales => '$baseUrl/sales/my-sales';

  static String get reportsSalesSummary => '$baseUrl/reports/sales-summary';
  static String get reportsTopProducts => '$baseUrl/reports/top-products';
  static String get reportsTopStaff => '$baseUrl/reports/top-staff';
  static String get reportsCategoryMix => '$baseUrl/reports/category-mix';
  static String get reportsAgingStock => '$baseUrl/reports/aging-stock';
  static String get reportsLowStock => '$baseUrl/reports/low-stock';
  static String get reportsGstSnapshot => '$baseUrl/reports/gst-snapshot';
  static String get reportsGst => '$baseUrl/reports/gst';

  static String get gst => '$baseUrl/gst-registrations';
  static String get notifications => '$baseUrl/notifications';
  static String get users => '$baseUrl/users';
  static String get usersLeaderboard => '$baseUrl/users/leaderboard';

  /// Re-writes a URL that was stored in the DB as `http://localhost:5000/...`
  /// so it points to the correct host for the current environment.
  static String fixImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    return url.replaceFirst(
      RegExp(r'http://(localhost|127\.0\.0\.1|10\.0\.2\.2):\d+'),
      'https://$_host',
    );
  }
}
