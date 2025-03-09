package com.lkrjangid.rar

import androidx.annotation.NonNull
import com.github.junrar.Junrar
import com.github.junrar.Archive
import com.github.junrar.exception.RarException

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

import java.io.File
import java.io.IOException
import java.util.ArrayList

/** RarPlugin */
class RarPlugin: FlutterPlugin, MethodCallHandler {
  private lateinit var channel : MethodChannel

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.lkrjangid.rar")
    channel.setMethodCallHandler(this)
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    when (call.method) {
      "extractRarFile" -> {
        val rarFilePath = call.argument<String>("rarFilePath")
        val destinationPath = call.argument<String>("destinationPath")
        val password = call.argument<String>("password")

        if (rarFilePath == null || destinationPath == null) {
          result.error("INVALID_ARGUMENTS", "Missing required arguments", null)
          return
        }

        extractRar(rarFilePath, destinationPath, password, result)
      }
      "createRarArchive" -> {
        // Note: Pure Java RAR creation is not well supported
        // We'll use command-line tools or suggest using ZIP instead
        result.error("UNSUPPORTED", "RAR creation is not supported on Android. Consider using ZIP format instead.", null)
      }
      "listRarContents" -> {
        val rarFilePath = call.argument<String>("rarFilePath")
        val password = call.argument<String>("password")

        if (rarFilePath == null) {
          result.error("INVALID_ARGUMENTS", "Missing required arguments", null)
          return
        }

        listRarContents(rarFilePath, password, result)
      }
      else -> {
        result.notImplemented()
      }
    }
  }

  private fun extractRar(rarFilePath: String, destinationPath: String, password: String?, result: Result) {
    try {
      val rarFile = File(rarFilePath)
      val destDir = File(destinationPath)
      
      if (!rarFile.exists()) {
        result.error("FILE_NOT_FOUND", "RAR file does not exist", null)
        return
      }

      if (!destDir.exists() && !destDir.mkdirs()) {
        result.error("DIRECTORY_ERROR", "Could not create destination directory", null)
        return
      }

      // Using the updated Junrar API for extraction
      if (password != null) {
        Junrar.extract(rarFile, destDir, password)
      } else {
        Junrar.extract(rarFile, destDir)
      }
      
      result.success(mapOf(
        "success" to true,
        "message" to "Extraction completed successfully"
      ))
    } catch (e: RarException) {
      result.success(mapOf(
        "success" to false,
        "message" to "RAR error: ${e.message}"
      ))
    } catch (e: IOException) {
      result.success(mapOf(
        "success" to false,
        "message" to "IO error: ${e.message}"
      ))
    } catch (e: Exception) {
      result.success(mapOf(
        "success" to false,
        "message" to "Error: ${e.message}"
      ))
    }
  }

  private fun listRarContents(rarFilePath: String, password: String?, result: Result) {
    try {
      val rarFile = File(rarFilePath)
      
      if (!rarFile.exists()) {
        result.error("FILE_NOT_FOUND", "RAR file does not exist", null)
        return
      }

      // Get the content descriptions using Archive directly since Junrar doesn't have a password parameter
      val archive = com.github.junrar.Archive(rarFile, password)
      val fileList = ArrayList<String>()
      
      archive.fileHeaders.forEach { fileHeader ->
        fileList.add(fileHeader.fileName)
      }
      
      result.success(mapOf(
        "success" to true,
        "message" to "Successfully listed RAR contents",
        "files" to fileList
      ))
    } catch (e: RarException) {
      result.success(mapOf(
        "success" to false,
        "message" to "RAR error: ${e.message}",
        "files" to ArrayList<String>()
      ))
    } catch (e: IOException) {
      result.success(mapOf(
        "success" to false,
        "message" to "IO error: ${e.message}",
        "files" to ArrayList<String>()
      ))
    } catch (e: Exception) {
      result.success(mapOf(
        "success" to false,
        "message" to "Error: ${e.message}",
        "files" to ArrayList<String>()
      ))
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }
}