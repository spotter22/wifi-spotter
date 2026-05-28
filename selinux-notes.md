# Bypassing SELinux restrictions

### SELinux notes:
1. Proper patching is required by [Magisk](https://github.com/topjohnwu/Magisk/pull/433) so utils like `cmd` and `pm` can run without no issues.
2. Termux can execute some commands from `cmd` and `pm` because it bypasses the restrictions by using a [tricky method](https://github.com/termux/termux-packages/discussions/8292#discussioncomment-5102555).
3. Even wifi-spotter uses it's own [tricky method](https://stackoverflow.com/a/3502108) to bypass SELinux restrictions.

### Examples:
1. Trying with system's shipped binary:
```BASH
$ su -c which cmd
/system/bin/cmd
$ su -c cmd wifi status
cmd: Failure calling service wifi: Failed transaction (2147483646)
```

2. Trying with Termux's binary:
```BASH
$ sudo which cmd
/data/data/com.termux/files/usr/bin/cmd
$ sudo cmd wifi status
Wifi is disabled
Wifi scanning is only available when wifi is enabled
```
