# ssh-utils-powershell
Powershell scripts for ssh management on Windows.


# ssh-copy-id Powershell script
Windows Powershell script to Mimic linux/freebsd shell script functionality to copy SSH public keys to destination host.
```
usage: ssh-copy-id [-l] [-v] [-d] [-help] [-i keyfile] [-o option] [-p port] [user@]hostname

DESCRIPTION
     The ssh-copy-id utility copies public keys to a remote host's
     ~/.ssh/authorized_keys file.

     The following options are available:

     -help   Provide this detailed cli syntax help.

     -i file
             Copy the public key contained in file.  This option can be
             specified multiple times and can be combined with the -l option.
             If a private key is specified and a public key is found then the
             public key will be used.

     -l      Copy the keys currently held by ssh-agent(1).

     -o ssh-option
             Pass this option directly to ssh(1).  This option can be
             specified multiple times.

     -p port
             Connect to the specified port on the remote host instead of the
             default.

     -v      Pass -v to ssh(1).

     -d      Enable debugging output for Powershell script.

     The remaining arguments are a list of remote hosts to connect to, each
     one optionally qualified by a user name.
```
## TODO:
[ ] Add support for multiple `-i` cli options and iteration
[X] Add support for `user@` automagic handling if not specified on cli
[ ] Add support for multiple `user@host` objects and iteration
[ ] Add support for powershell-scriptlet module 
[ ] Add support for signed powershell ?
[ ] Check all return codes, and document success/fail/other (match upstream ?)
[ ] Ask upstream [PowerShell/Win32-OpenSSH] / openssh-portable if they might have interest after maturing
[ ] style(9) improvements - if possible with LF not being mangled for sh -c foo
[ ] lint improvements
[ ] check $psversiontable and test older versions/variants
 