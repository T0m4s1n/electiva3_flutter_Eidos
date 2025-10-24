import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../controllers/navigation_controller.dart';
import '../widgets/edit_profile_view.dart';

class EditProfilePage extends StatelessWidget {
  const EditProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthController authController = Get.find<AuthController>();
    final NavigationController navController = Get.find<NavigationController>();

    return Obx(() {
      return EditProfileView(
        currentName: authController.userName.value,
        currentEmail: authController.userEmail.value,
        onBack: () => navController.hideEditProfileView(),
        onSaveProfile: (name, email, bio) async {
          try {
            await authController.updateUserProfile(fullName: name, bio: bio);

            navController.hideEditProfileView();

            Get.snackbar(
              'Success',
              'Profile updated successfully!',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: Colors.green,
              colorText: Colors.white,
              duration: const Duration(seconds: 2),
            );
          } catch (e) {
            Get.snackbar(
              'Error',
              'Failed to update profile: ${e.toString()}',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: Colors.red,
              colorText: Colors.white,
              duration: const Duration(seconds: 3),
            );
          }
        },
        onDeleteAccount: () async {
          try {
            await authController.deleteAccount();

            navController.resetAllViews();

            Get.snackbar(
              'Account Deleted',
              'Your account has been successfully deleted.',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: Colors.orange,
              colorText: Colors.white,
              duration: const Duration(seconds: 3),
            );
          } catch (e) {
            Get.snackbar(
              'Error',
              'Failed to delete account: ${e.toString()}',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: Colors.red,
              colorText: Colors.white,
              duration: const Duration(seconds: 3),
            );
          }
        },
      );
    });
  }
}
