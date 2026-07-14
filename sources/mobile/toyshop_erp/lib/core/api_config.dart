class ApiConfig {
  // Use 10.0.2.2 for Android emulator to connect to local backend,
  // or localhost/127.0.0.1 for iOS simulator.
  // For physical devices on same network, use the host machine's IP (e.g. 192.168.x.x)
  static const String baseUrl = 'http://10.0.2.2:5000/api/v1';

  static const String authPublicUsers = '$baseUrl/auth/users';
  static const String authLogin = '$baseUrl/auth/login';
  static const String authRefreshToken = '$baseUrl/auth/refresh-token';

  static const String dashboardOwner = '$baseUrl/dashboard/owner';
  
  static const String products = '$baseUrl/products';
  static const String categories = '$baseUrl/categories';
}
