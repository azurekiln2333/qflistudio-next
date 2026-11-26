import java.util.Properties
import com.android.build.api.dsl.ApplicationExtension
import org.gradle.kotlin.dsl.configure
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing is read from android/key.properties (git-ignored) or from the
// ANDROID_* environment variables used by CI. There is deliberately no debug
// fallback: a release build without an explicit key fails instead of shipping a
// debug-signed APK.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { stream -> load(stream) }
    }
}

fun signingValue(propertyName: String, environmentName: String): String? {
    val fromFile = keystoreProperties.getProperty(propertyName)?.trim()
    if (!fromFile.isNullOrEmpty()) return fromFile
    val fromEnvironment = System.getenv(environmentName)?.trim()
    return if (fromEnvironment.isNullOrEmpty()) null else fromEnvironment
}

val releaseStorePath = signingValue("storeFile", "ANDROID_KEYSTORE_PATH")
val releaseStorePassword = signingValue("storePassword", "ANDROID_KEYSTORE_PASSWORD")
val releaseKeyAlias = signingValue("keyAlias", "ANDROID_KEY_ALIAS")
val releaseKeyPassword = signingValue("keyPassword", "ANDROID_KEY_PASSWORD")
val hasReleaseSigning = listOf(
    releaseStorePath,
    releaseStorePassword,
    releaseKeyAlias,
    releaseKeyPassword,
).all { !it.isNullOrEmpty() }

extensions.configure<ApplicationExtension> {
    namespace = "com.azurekiln.qflistudio"
    compileSdk = flutter.compileSdkVersion
    // Keep the Android NDK aligned with the pinned CI toolchain.
    ndkVersion = "27.0.12077973"

    // The hosted lint detector can fail inside third-party dependencies.
    // APK architecture and signing checks remain explicit CI gates.
    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.azurekiln.qflistudio"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = rootProject.file(releaseStorePath!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

extensions.configure<KotlinAndroidProjectExtension> {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

// Fail only when a release build is actually requested, so debug runs and
// analyzer-only tasks work on machines without the keystore.
gradle.taskGraph.whenReady {
    val buildsRelease = allTasks.any { task -> task.name.contains("Release") }
    if (buildsRelease && !hasReleaseSigning) {
        throw GradleException(
            "Release signing is not configured. Provide android/key.properties " +
                "or set ANDROID_KEYSTORE_PATH, ANDROID_KEYSTORE_PASSWORD, " +
                "ANDROID_KEY_ALIAS and ANDROID_KEY_PASSWORD. The debug key is " +
                "never used for release builds.",
        )
    }
}

flutter {
    source = "../.."
}
