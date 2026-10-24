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

subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    configurations.all {
        resolutionStrategy.eachDependency {
            if (requested.group == "org.jetbrains.kotlin") {
                useVersion("2.1.0")
            }
        }
    }
}

subprojects {
    val project = this
    val fixNamespace = {
        val android = project.extensions.findByName("android")
        if (android != null) {
            try {
                // Force compileSdk to 36
                val setCompileSdk = android.javaClass.getMethod("setCompileSdk", Integer::class.java)
                setCompileSdk.invoke(android, 36)
            } catch (e: Exception) {
                try {
                    val compileSdkVersion = android.javaClass.getMethod("compileSdkVersion", Integer::class.java)
                    compileSdkVersion.invoke(android, 36)
                } catch (e2: Exception) {}
            }

            try {
                val getNamespace = android.javaClass.getMethod("getNamespace")
                if (getNamespace.invoke(android) == null) {
                    val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                    setNamespace.invoke(android, "dev.isar.${project.name.replace("-", "_")}")
                }
            } catch (e: Exception) {}
        }
    }
    
    if (project.state.executed) {
        fixNamespace()
    } else {
        project.afterEvaluate { fixNamespace() }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}


subprojects {
    tasks.configureEach {
        if (this.javaClass.name.contains("KotlinCompile")) {
            try {
                val kotlinOptions = this.javaClass.getMethod("getKotlinOptions").invoke(this)
                val getFreeArgs = kotlinOptions.javaClass.getMethod("getFreeCompilerArgs")
                val setFreeArgs = kotlinOptions.javaClass.getMethod("setFreeCompilerArgs", List::class.java)
                @Suppress("UNCHECKED_CAST")
                val current = getFreeArgs.invoke(kotlinOptions) as? List<String> ?: emptyList()
                if (!current.contains("-Xskip-metadata-version-check")) {
                    setFreeArgs.invoke(kotlinOptions, current + "-Xskip-metadata-version-check")
                }
            } catch (e: Exception) {}
        }
    }
}
