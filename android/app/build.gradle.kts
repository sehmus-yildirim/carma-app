import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystoreFile = keystorePropertiesFile.exists()

if (hasReleaseKeystoreFile) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

val requiredSigningProperties = listOf(
    "storePassword",
    "keyPassword",
    "keyAlias",
    "storeFile",
)

fun keystoreValue(name: String): String =
    keystoreProperties.getProperty(name)?.trim().orEmpty()

val missingReleaseSigningProperties = if (hasReleaseKeystoreFile) {
    requiredSigningProperties.filter { keystoreValue(it).isEmpty() }
} else {
    requiredSigningProperties
}

val releaseStoreFile = keystoreValue("storeFile")
    .takeIf { it.isNotEmpty() }
    ?.let { rootProject.file(it) }

val hasReleaseStoreFile = releaseStoreFile?.exists() == true
val hasCompleteReleaseSigning =
    hasReleaseKeystoreFile &&
        missingReleaseSigningProperties.isEmpty() &&
        hasReleaseStoreFile

gradle.taskGraph.whenReady {
    val requestedReleaseBuild = allTasks.any { task ->
        task.name.contains("Release", ignoreCase = true)
    }

    if (requestedReleaseBuild && !hasCompleteReleaseSigning) {
        val reason = when {
            !hasReleaseKeystoreFile ->
                "android/key.properties fehlt."
            missingReleaseSigningProperties.isNotEmpty() ->
                "android/key.properties ist unvollstaendig: ${missingReleaseSigningProperties.joinToString()}."
            !hasReleaseStoreFile ->
                "Keystore-Datei fehlt: ${releaseStoreFile?.path ?: "nicht angegeben"}."
            else ->
                "Release-Signing ist unvollstaendig."
        }

        throw org.gradle.api.GradleException(
            "$reason Release-Build abgebrochen. Lege android/key.properties mit storePassword, keyPassword, keyAlias und storeFile an. Die Keystore-Datei und key.properties duerfen nicht in Git."
        )
    }
}

android {
    namespace = "de.plaqa.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "de.plaqa.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasCompleteReleaseSigning) {
                keyAlias = keystoreValue("keyAlias")
                keyPassword = keystoreValue("keyPassword")
                storeFile = releaseStoreFile
                storePassword = keystoreValue("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(
                if (hasCompleteReleaseSigning) "release" else "debug"
            )
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}
