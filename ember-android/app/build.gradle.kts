import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("org.jetbrains.kotlin.plugin.serialization")
    id("io.github.takahirom.roborazzi") version "1.50.0"
}

android {
    namespace = "app.ember.ideas"
    compileSdk = 36

    defaultConfig {
        applicationId = "app.ember.ideas"
        minSdk = 26
        targetSdk = 36
        versionCode = 10
        versionName = "1.4.0"
        vectorDrawables { useSupportLibrary = true }

        // 출시 설정. gradle.properties 나 -P 옵션으로 넣는다(비우면 해당 기능이 숨겨진다).
        fun prop(name: String) = (project.findProperty(name) as String?)?.trim().orEmpty()
        buildConfigField("String", "EMBER_SERVER_URL", "\"${prop("ember.serverUrl")}\"")
        buildConfigField("String", "REPORT_EMAIL", "\"${prop("ember.reportEmail")}\"")
        buildConfigField("String", "PRIVACY_URL", "\"${prop("ember.privacyUrl")}\"")
        buildConfigField("double", "CREDIT_MARKUP", prop("ember.creditMarkup").ifEmpty { "1.5" })
        buildConfigField("int", "FREE_CREDITS", prop("ember.freeCredits").ifEmpty { "40" })
        // 작업대(PC 브리지)는 다음 업데이트에서 켠다. 꺼 두면 화면에 나오지 않고 동작하지도 않는다.
        buildConfigField("boolean", "WORKBENCH_ENABLED", prop("ember.workbench").ifEmpty { "false" })
        // Google 로그인용 OAuth 웹 클라이언트 ID(서버의 GOOGLE_OAUTH_CLIENT_IDS 와 같은 값).
        buildConfigField("String", "GOOGLE_WEB_CLIENT_ID", "\"${prop("ember.googleWebClientId")}\"")
    }

    // 서명 정보는 저장소에 넣지 않는다. keystore.properties(무시 목록)가 있으면 그 키로 서명한다.
    val keystoreProps = Properties().apply {
        val f = rootProject.file("keystore.properties")
        if (f.exists()) f.inputStream().use { load(it) }
    }
    signingConfigs {
        if (keystoreProps.getProperty("storeFile") != null) {
            create("release") {
                storeFile = rootProject.file(keystoreProps.getProperty("storeFile"))
                storePassword = keystoreProps.getProperty("storePassword")
                keyAlias = keystoreProps.getProperty("keyAlias")
                keyPassword = keystoreProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Anthropic SDK 는 Jackson·Kotlin 리플렉션을 쓰므로, 실기기 검증 전까지는 축소를 끈다.
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
        }
        debug {
            applicationIdSuffix = ".debug"
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }
    buildFeatures { compose = true; buildConfig = true }
    packaging {
        resources.excludes += setOf("/META-INF/{AL2.0,LGPL2.1}", "META-INF/DEPENDENCIES", "META-INF/LICENSE*", "META-INF/NOTICE*", "META-INF/*.kotlin_module", "META-INF/versions/9/OSGI-INF/MANIFEST.MF")
    }
    testOptions {
        unitTests {
            isIncludeAndroidResources = true
            all {
                it.maxHeapSize = "4g"
                it.systemProperty("robolectric.dependency.repo.url", "https://maven-central.storage-download.googleapis.com/maven2")
                it.systemProperty("robolectric.dependency.repo.id", "gcs-mirror")
            }
        }
    }
}

kotlin {
    compilerOptions { jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17) }
}

dependencies {
    val composeBom = platform("androidx.compose:compose-bom:2025.10.01")
    implementation(composeBom)
    implementation("androidx.core:core-ktx:1.17.0")
    implementation("androidx.activity:activity-compose:1.11.0")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.animation:animation")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.navigation:navigation-compose:2.9.6")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.9.4")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.9.4")
    implementation("androidx.core:core-splashscreen:1.2.0")
    implementation("androidx.security:security-crypto:1.1.0")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.9.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")
    implementation("com.anthropic:anthropic-java:3.4.0")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("androidx.exifinterface:exifinterface:1.4.1")
    implementation("com.android.billingclient:billing-ktx:8.3.0")
    implementation("com.google.android.play:integrity:1.4.0")
    // Google 로그인(Credential Manager). 크레딧 계정을 Google 계정에 묶는다.
    implementation("androidx.credentials:credentials:1.5.0")
    implementation("androidx.credentials:credentials-play-services-auth:1.5.0")
    implementation("com.google.android.libraries.identity.googleid:googleid:1.1.1")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")

    debugImplementation("androidx.compose.ui:ui-tooling")
    debugImplementation("androidx.compose.ui:ui-test-manifest")

    testImplementation("junit:junit:4.13.2")
    testImplementation("com.squareup.okhttp3:mockwebserver:4.12.0")
    testImplementation("org.robolectric:robolectric:4.16")
    testImplementation("androidx.compose.ui:ui-test-junit4")
    testImplementation("io.github.takahirom.roborazzi:roborazzi:1.50.0")
    testImplementation("io.github.takahirom.roborazzi:roborazzi-compose:1.50.0")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.10.2")
}

// Play 에 올리는 번들(bundleRelease)은 출시 키가 없으면 만들지 않는다(디버그 키로 서명된 번들은 Play 가 거절한다).
tasks.matching { it.name == "bundleRelease" }.configureEach {
    doFirst {
        if (android.signingConfigs.findByName("release") == null) {
            throw GradleException("출시 서명 키가 없어요. 프로젝트 루트에 keystore.properties 를 두세요(README '빌드' 참고).")
        }
    }
}
