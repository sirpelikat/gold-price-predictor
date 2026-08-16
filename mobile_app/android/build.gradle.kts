allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val buildDirLocation = File(System.getProperty("java.io.tmpdir"), "flutter_gold_price_predictor_build")

val newBuildDir: Directory = rootProject.objects.directoryProperty().apply {
    set(buildDirLocation)
}.get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = rootProject.objects.directoryProperty().apply {
        set(File(buildDirLocation, project.name))
    }.get()
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
