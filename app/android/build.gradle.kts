allprojects {
    repositories {
        google()
        mavenCentral()
    }
    // posthog_flutter asks for posthog-android "[3.48.0,4.0.0]", a range, so
    // every build first downloads Maven's version list, and when Maven answers
    // 429 or nothing the build fails ("no versions available"; four CI runs in
    // a week). One exact version needs no list. 3.77.1 is what the range picked
    // anyway (1.8.2 shipped with it); raise it when posthog_flutter is upgraded.
    configurations.all {
        resolutionStrategy.eachDependency {
            if (requested.group == "com.posthog" && requested.name == "posthog-android") {
                useVersion("3.77.1")
            }
        }
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
