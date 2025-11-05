import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends GetxController {
  // Observable for theme mode
  final Rx<ThemeMode> themeMode = ThemeMode.light.obs;
  final RxBool isDarkMode = false.obs;
  final RxBool isChangingTheme = false.obs;

  @override
  void onInit() {
    super.onInit();
    _loadThemePreference();
  }

  // Load theme preference from storage
  Future<void> _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool? isDark = prefs.getBool('isDarkMode');
      if (isDark != null) {
        isDarkMode.value = isDark;
        themeMode.value = isDark ? ThemeMode.dark : ThemeMode.light;
      }
    } catch (e) {
      debugPrint('Error loading theme preference: $e');
    }
  }

  // Toggle between light and dark mode
  Future<void> toggleTheme() async {
    // Show loading animation
    isChangingTheme.value = true;
    
    // Small delay to show animation
    await Future.delayed(const Duration(milliseconds: 150));
    
    isDarkMode.value = !isDarkMode.value;
    themeMode.value = isDarkMode.value ? ThemeMode.dark : ThemeMode.light;
    
    // Save preference
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDarkMode', isDarkMode.value);
    } catch (e) {
      debugPrint('Error saving theme preference: $e');
    }
    
    // Update GetX theme
    Get.changeThemeMode(themeMode.value);
    
    // Wait for theme to apply
    await Future.delayed(const Duration(milliseconds: 100));
    
    // Hide loading animation
    isChangingTheme.value = false;
  }

  // Set specific theme mode
  Future<void> setThemeMode(bool dark) async {
    // Only show animation if theme is actually changing
    if (isDarkMode.value != dark) {
      // Show loading animation
      isChangingTheme.value = true;
      
      // Small delay to show animation
      await Future.delayed(const Duration(milliseconds: 150));
    }
    
    isDarkMode.value = dark;
    themeMode.value = dark ? ThemeMode.dark : ThemeMode.light;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDarkMode', dark);
    } catch (e) {
      debugPrint('Error saving theme preference: $e');
    }
    
    Get.changeThemeMode(themeMode.value);
    
    // Wait for theme to apply
    if (isChangingTheme.value) {
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Hide loading animation
      isChangingTheme.value = false;
    }
  }
}

