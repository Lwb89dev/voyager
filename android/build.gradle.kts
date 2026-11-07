allprojects {
    configurations.all {
        exclude(group = "com.google.android.gms")
        exclude(group = "com.google.android.play")
        exclude(group = "com.google.firebase")
    }
}

subprojects {
    afterEvaluate {
        extensions.findByType(com.android.build.gradle.BaseExtension::class.java)?.apply {
            compileSdkVersion(36)
            ndkVersion = "27.1.12297006"
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
