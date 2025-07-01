import 'package:go_router/go_router.dart';
import 'package:nrc/presentation/pages/job/AllJobs.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/Job.dart';
import '../../data/models/purchase_order.dart';
import '../pages/home/HomeScreen.dart';
import '../pages/job/JobInputPage.dart';
import '../pages/job/job_list_page.dart';
import '../pages/login/login_page.dart';
import '../pages/main/MainHomePage.dart';
import '../pages/members/AddMembers.dart';
import '../pages/members/UserListPage.dart';
import '../pages/purchaseorder/PoAssignDetailsPage.dart';
import '../pages/purchaseorder/PurchaseOrderInput.dart';
import 'UserRoleManager.dart';

final UserRoleManager userRoleManager = UserRoleManager();

final GoRouter router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => LoginScreen()),
    GoRoute(path: '/job-input', builder: (context, state) => JobInputPage()),
    GoRoute(path: '/create-id', builder: (context, state) => CreateID()),
    GoRoute(path: '/user-list', builder: (context, state) => UserListPage()),
    GoRoute(path: '/all-Jobs', builder: (context, state) => AllJobsScreen()),
    GoRoute(
      path: '/add-po',
      builder: (context, state) => PurchaseOrderInput(job: state.extra as Job),
    ),
    GoRoute(
      path: '/job-details/:jobNumber',
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>;
        final job = data['job'] as Job;
        final po = data['po'] as PurchaseOrder;
        return PoAssignDetailsPage(job: job, purchaseOrder: po);
      },
    ),

    GoRoute(
      path: '/edit-po/:jobNumber',
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>;
        final job = data['job'] as Job;
        final po = data['po'] as PurchaseOrder;
        return PurchaseOrderInput(job: job, existingPo: po);
      },
    ),


    GoRoute(
      path: '/job-list',
      builder: (context, state) => JobListPage()
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => MainScaffold()
    ),
  ],
);
