# supercharged
supercharged is a set of bash scripts that I use to set up my MacBook for development. The script utilitses `brew` to install system dependencies and `mas` to install apps from the App Store.

The script is idempotent and will upgrade existings dependency instead of overwriting the symlink.

Install
-------

```
git clone git@github.com:robinsalehjan/supercharged.git && cd supercharged && ./init.sh
```

Update
------

To update all the installed dependencies run the `update.sh` script
```
cd supercharged && /.update.sh
```
