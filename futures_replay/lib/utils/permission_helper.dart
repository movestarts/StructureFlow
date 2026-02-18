import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

/// 权限请求帮助类
class PermissionHelper {
  /// 请求存储权限
  /// 
  /// Android 13+ (API 33) 不再需要存储权限（使用 SAF）
  /// Android 6-12 需要请求 READ/WRITE_EXTERNAL_STORAGE
  static Future<bool> requestStoragePermission(BuildContext context) async {
    // iOS 或其他平台直接返回 true
    if (!Platform.isAndroid) {
      return true;
    }
    
    // Android 13+ (API 33+) 使用新的媒体权限或 SAF
    // file_picker 会自动处理，不需要额外权限
    if (await _isAndroid13OrHigher()) {
      debugPrint('[Permission] Android 13+, no storage permission needed');
      return true;
    }
    
    // Android 6-12: 请求存储权限
    final status = await Permission.storage.status;
    
    if (status.isGranted) {
      debugPrint('[Permission] Storage permission already granted');
      return true;
    }
    
    if (status.isDenied) {
      debugPrint('[Permission] Requesting storage permission...');
      final result = await Permission.storage.request();
      
      if (result.isGranted) {
        debugPrint('[Permission] Storage permission granted');
        return true;
      }
      
      if (result.isPermanentlyDenied) {
        debugPrint('[Permission] Storage permission permanently denied');
        _showPermissionDeniedDialog(context);
        return false;
      }
      
      debugPrint('[Permission] Storage permission denied');
      return false;
    }
    
    if (status.isPermanentlyDenied) {
      debugPrint('[Permission] Storage permission permanently denied');
      _showPermissionDeniedDialog(context);
      return false;
    }
    
    return false;
  }
  
  /// 检查是否为 Android 13 或更高版本
  static Future<bool> _isAndroid13OrHigher() async {
    if (!Platform.isAndroid) return false;
    
    try {
      // 检查是否有 Android 13 的权限
      final photosStatus = await Permission.photos.status;
      // 如果能查询到 photos 权限，说明是 Android 13+
      return true;
    } catch (e) {
      // 如果查询失败，说明不是 Android 13+
      return false;
    }
  }
  
  /// 显示权限被拒绝的对话框
  static void _showPermissionDeniedDialog(BuildContext context) {
    if (!context.mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('需要存储权限'),
        content: const Text(
          '应用需要存储权限来导入和导出CSV文件。\n\n'
          '请在系统设置中授予存储权限。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('去设置'),
          ),
        ],
      ),
    );
  }
  
  /// 请求通知权限（用于后台任务通知）
  static Future<bool> requestNotificationPermission() async {
    if (!Platform.isAndroid) {
      return true;
    }
    
    final status = await Permission.notification.status;
    if (status.isGranted) {
      return true;
    }
    
    final result = await Permission.notification.request();
    return result.isGranted;
  }
  
  /// 检查所有必要权限
  static Future<Map<String, bool>> checkAllPermissions() async {
    return {
      'storage': await Permission.storage.status.isGranted,
      'notification': await Permission.notification.status.isGranted,
    };
  }
}
