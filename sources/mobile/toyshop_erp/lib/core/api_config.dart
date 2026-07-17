class ApiConfig {
  // Use 10.0.2.2 for Android emulator to connect to local backend,
  // or localhost/127.0.0.1 for iOS simulator.
  // For physical devices via USB debugging, we use adb reverse and 127.0.0.1
  static const String baseUrl = 'http://127.0.0.1:5000/api/v1';

  static const String authPublicUsers = '$baseUrl/auth/users';
  static const String authLogin = '$baseUrl/auth/login';
  static const String authRefreshToken = '$baseUrl/auth/refresh-token';

  static const String dashboardOwner = '$baseUrl/dashboard/owner';
  
  static const String products = '$baseUrl/products';
  static const String categories = '$baseUrl/categories';
  static const String branches = '$baseUrl/branches';
  static const String sales = '$baseUrl/sales';
  
  static const String reportsSalesSummary = '$baseUrl/reports/sales-summary';
  static const String reportsTopProducts = '$baseUrl/reports/top-products';
  static const String reportsTopStaff = '$baseUrl/reports/top-staff';
  static const String reportsCategoryMix = '$baseUrl/reports/category-mix';
  static const String reportsAgingStock = '$baseUrl/reports/aging-stock';
  static const String reportsLowStock = '$baseUrl/reports/low-stock';
  static const String reportsGstSnapshot = '$baseUrl/reports/gst-snapshot';
  static const String reportsGst = '$baseUrl/reports/gst';

  static const String gst = '$baseUrl/gst-registrations';
  static const String notifications = '$baseUrl/notifications';
  static const String users = '$baseUrl/users';
}
