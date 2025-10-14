class AppStrings {
  static const String appName = 'ASSURED.';
  static const String splashTagline = 'Ride with Intelligence';
  static const String ReviewCompletePageGreeting ="You're all set! We're reviewing your documents. In the meantime, just sit back and relax — we'll notify you as soon as everything's good to go!";
  
  // Backend URLs - Change this to switch between localhost and production
  static const String localhostUrl = 'http://localhost:3000/api';
  static const String productionUrl = 'https://nrprod.nrcontainers.com/api';
  
  // Alternative URLs (keeping for reference)
  static const String awsUrl = 'https://nrc-shankh-62gr.vercel.app/api';
  static const String awsUrlAlt1 = 'https://nrc-shankh-62gr.vercel.app';
  static const String awsUrlAlt2 = 'https://nrc-backend-his4.onrender.com/api';
  
  // Set to true for production backend, false for localhost
  // To switch to localhost: Change this to false and run your local backend
  // To switch to production: Change this to true (current setting)
  static const bool useProductionBackend = false;  // Changed to localhost for testing
  
  // Active base URL based on configuration
  static String get baseUrl => useProductionBackend ? productionUrl : localhostUrl;
}
