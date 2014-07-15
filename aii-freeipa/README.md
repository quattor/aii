# AII FreeIPA

## Package

For now, the pom.xml has the python version hardcoded to 2.6 for EL6.
For EL7, change the `pyversion.short` property, like this:

```bash
mvn -Dpyversion.short=2.7 <goal1> [<goal2> ...]
```


