= AII FreeIPA
== Package
For now, the pom.xml has the python version hardcoded to 2.7 for EL7 
(for EL6, change the pyversion.short property)
== Run tests
PERL5LIB=/usr/lib/perl:$PWD/target/dependency/build-scripts/:$PWD/src/test/perl mvn test
