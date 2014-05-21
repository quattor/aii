# AII FreeIPA

## Package

For now, the pom.xml has the python version hardcoded to 2.6 for EL6.
For EL7, change the `pyversion.short` property, like this:

```bash
mvn -Dpyversion.short=2.7 <goal1> [<goal2> ...]
```

## Run tests

```bash
PERL5LIB=/usr/lib/perl:$PWD/target/dependency/build-scripts/:$PWD/src/test/perl mvn test
```
