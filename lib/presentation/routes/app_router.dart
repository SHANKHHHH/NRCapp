import 'package:go_router/go_router.dart';
import 'package:nrc/presentation/pages/job/AllJobs.dart';
import 'package:nrc/presentation/pages/work/WorkScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/Job.dart';
import '../../data/models/WorkStepAssignment.dart';
import '../../data/models/purchase_order.dart';
import '../pages/dashboard/DispatchBoard.dart';
import '../pages/dashboard/PlanningDashboard.dart';
import '../pages/dashboard/PrintingManagerBoard.dart';
import '../pages/dashboard/ProductionBoard.dart';
import '../pages/dashboard/QualityBoard.dart';
import '../pages/home/HomeScreen.dart';
import '../pages/job/JobInputPage.dart';
import '../pages/job/job_list_page.dart';
import '../pages/login/login_page.dart';
import '../pages/machines/EditMachinesPage.dart';
import '../pages/main/MainHomePage.dart';
import '../pages/members/AddMembers.dart';
import '../pages/members/UserListPage.dart';
import '../pages/purchaseorder/PoAssignDetailsPage.dart';
import '../pages/purchaseorder/PurchaseOrderInput.dart';
import '../pages/stepsselections/AssignWorkSteps.dart';
import 'UserRoleManager.dart';
import '../pages/job/PendingJobsWorkPage.dart';
import '../pages/job/CompletedJobsPage.dart';
import '../pages/activity/UserActivityPage.dart';
import '../pages/activity/UserOwnActivityPage.dart';
import '../pages/work/EditWorkingDetailsPage.dart';

final UserRoleManager userRoleManager = UserRoleManager();

final GoRouter router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => LoginScreen()),
    GoRoute(path: '/edit-working-details', builder: (context, state) => const EditWorkingDetailsPage()),
    GoRoute(path: '/job-input', builder: (context, state) => JobInputPage()),
    GoRoute(path: '/create-id', builder: (context, state) => CreateID()),
    GoRoute(path: '/user-list', builder: (context, state) => UserListPage()),
    GoRoute(path: '/all-Jobs', builder: (context, state) => AllJobsScreen()),
    GoRoute(
      path: '/planning-dashboard',
      builder: (context, state) {
        final role = userRoleManager.userRole?.toLowerCase();
        if (role == null) return LoginScreen();
        if (role == 'admin' || role == 'planner') return const PlanningDashboard();
        return const MainScaffold();
      },
    ),
    GoRoute(
      path: '/production-dashboard',
      builder: (context, state) {
        final role = userRoleManager.userRole?.toLowerCase();
        if (role == null) return LoginScreen();
        if (role == 'admin' || role == 'production_head') return ProductionBoard();
        return const MainScaffold();
      },
    ),
    GoRoute(
      path: '/printing-dashboard',
      builder: (context, state) {
        final role = userRoleManager.userRole?.toLowerCase();
        if (role == null) return LoginScreen();
        if (role == 'admin' || role == 'printer') return PrintingManagerBoard();
        return const MainScaffold();
      },
    ),
    GoRoute(
      path: '/dispatch-dashboard',
      builder: (context, state) {
        final role = userRoleManager.userRole?.toLowerCase();
        if (role == null) return LoginScreen();
        if (role == 'admin' || role == 'dispatch_executive') return const DispatchBoard();
        return const MainScaffold();
      },
    ),
    GoRoute(
      path: '/qc-dashboard',
      builder: (context, state) {
        final role = userRoleManager.userRole?.toLowerCase();
        if (role == null) return LoginScreen();
        if (role == 'admin' || role == 'qc_manager') return QualityBoard();
        return const MainScaffold();
      },
    ),
    GoRoute(path: '/work-screen', builder: (context, state) => WorkScreen()),
    GoRoute(path: '/edit-machines', builder: (context, state) => EditMachinesPage()),
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
      path: '/assign-work-steps',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return AssignWorkSteps(
          job: extra?['job'] as Job?,
          jobPlanning: extra?['jobPlanning'] as Map<String, dynamic>?,
          step: extra?['step'] as Map<String, dynamic>?,
          assignment: extra?['assignment'] as WorkStepAssignment?,
          isEditMode: extra?['isEditMode'] as bool? ?? false,
        );
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
    GoRoute(
      path: '/pending-jobs-work',
      builder: (context, state) {
        final nrcJobNo = state.extra != null && state.extra is Map ? (state.extra as Map)['nrcJobNo'] as String : '';
        final pendingFields = state.extra != null && state.extra is Map
          ? List<Map<String, dynamic>>.from((state.extra as Map)['pendingFields'] as List)
          : <Map<String, dynamic>>[];
        return PendingJobsWorkPage(nrcJobNo: nrcJobNo, pendingFields: pendingFields);
      },
    ),
    GoRoute(
      path: '/completed-jobs',
      builder: (context, state) => const CompletedJobsPage(),
    ),
    GoRoute(
      path: '/user-activity',
      builder: (context, state) => const UserActivityPage(),
    ),
    GoRoute(
      path: '/my-activity',
      builder: (context, state) => const UserOwnActivityPage(),
    ),
  ],
);
