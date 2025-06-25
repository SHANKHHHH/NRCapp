import 'package:go_router/go_router.dart';
import 'package:nrc/presentation/pages/job/PurchaseOrderInput.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/purchase_order.dart';
import '../pages/home/HomeScreen.dart';
import '../pages/job/JobInputPage.dart';
import '../pages/job/job_list_page.dart';
import '../pages/login/login_page.dart';
import '../pages/members/AddMembers.dart';
import '../pages/members/UserListPage.dart';
import 'UserRoleManager.dart';

final UserRoleManager userRoleManager = UserRoleManager();

final GoRouter router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => LoginScreen()),
    GoRoute(path: '/job-input', builder: (context, state) {
      final PurchaseOrder order = state.extra as PurchaseOrder;
      return JobInputPage(order: order);
    }),
    GoRoute(path: '/create-id', builder: (context, state) => CreateID()),
    GoRoute(path: '/user-list', builder: (context, state) => UserListPage()),
    GoRoute(path: '/purchase-order-input', builder: (context, state) => PurchaseOrderManagement()),
    GoRoute(
      path: '/job-list',
      builder: (context, state) => JobListPage()
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => HomeScreen()
    ),
  ],
);
