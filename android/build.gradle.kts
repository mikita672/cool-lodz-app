allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// Optional machine-local NDK pin: set `coollodz.ndkVersion=<installed version>` in
// ~/.gradle/gradle.properties (or $GRADLE_USER_HOME) to build every Android module with an NDK
// you already have instead of Flutter's default. Without it nothing changes.
val localNdkVersion: String? = providers.gradleProperty("coollodz.ndkVersion").orNull
if (localNdkVersion != null) {
    subprojects {
        // Registered before the Android plugin applies, so it runs before AGP checks the NDK.
        afterEvaluate {
            extensions.findByType(com.android.build.api.dsl.LibraryExtension::class.java)?.ndkVersion =
                localNdkVersion
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
