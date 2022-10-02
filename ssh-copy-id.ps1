#
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer
#    in this position and unchanged.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#



param(
	[Parameter(HelpMessage="Identity File - public key e.g.: ~\.ssh\id_rsa.pub")]
	[string]$I, 
	[Parameter(HelpMessage="Load keys from ssh-agent")]
	[switch]$L,
	[Parameter(HelpMessage="ssh-option argument to pass to ssh -o command line")]
	[string]$O,
	[Parameter(HelpMessage="Port number for ssh session (default = 22)")]
	[string]$P,
	[Parameter(HelpMessage="Verbose mode to pass to ssh")]
	[switch]$V,
	[Parameter(HelpMessage="Debug mode for powershell script")]
	[switch]$D,
	[Parameter(HelpMessage="Detailed usage / syntax help.")]
	[switch]$HELP,
	[Parameter(HelpMessage="[user@]host [user@host]...", Position = 0, ValueFromRemainingArguments = $true)]
	[string]$HOSTS
)

function usage ($verbose) {
        write-host "usage: ssh-copy-id [-l] [-v] [-d] [-help] [-i keyfile] [-o option] [-p port] [user@]hostname" -foregroundcolor yellow
		if (! $verbose) { exit 1 }
		write-host "`nDESCRIPTION
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
     one optionally qualified by a user name."
        exit 1
}

function sendkey ($h, $k, $user, $port, $options) {
	#Please use an editor that displays TAB,CR,LF as visible elements. Use only unix-style line endings (LF).
	#Be very careful with LF vs CRLF, and quoting of strings for sh -c.  Use sh -cx to help debug.
	#Use powershell here_string with single quote to not do variable replacement, and treat everything very literal.
	#sh -c string must have single quotes around entire entity, but is very picky about escaping strings based on both sh logic, and powershell.
	#TODO: This does *NOT* currently take into consideration moving public keys to a windows host, just 'sh' capable endpoints.
    $here_string=@'
/bin/sh -c ' \
set -e; \
umask 077; \
keyfile=$HOME/.ssh/authorized_keys ; \
mkdir -p -- "$HOME/.ssh/" ; \
while read alg key comment ; do \
	[ -n \"$key\" ] || continue; \
	#[ -n \"$alg\" ] || continue; \
	#[ -n \"$comment\" ] || continue; \
	if ! grep -sqwF \"$key\" "$keyfile"; then \
		printf \"$alg $key $comment\n\" | sed \"s/\x0D//g\" >> "$keyfile" ; \
		echo "Added SSH public key to $USER@`hostname`." ; \
	fi ; \
done ; \
if [ -x /sbin/restorecon ]; then \
	/sbin/restorecon -F "$HOME/.ssh/" "$keyfile" >/dev/null 2>&1 || true ; \
fi 	\
'
'@

		# Use write-output to enable proper pipeline support
		write-output "${k}" | ssh $port -S none $options "$user$h" $here_string
}

function agentKeys {
        $keys = ssh-add -L | Out-String
		if ($keys -contains 'The agent has no') { 
			Write-Warning "ssh-agent: No keys present."
			return 1 
		}
		write-debug "agentkeys: $keys"
		return $keys
}

## MAIN

if ($D) {
	$DebugPreference = "Continue"
}

Write-debug "identity: 		$I"
Write-debug "ssh-agent:	 	$L"
Write-debug "options: 		$O"
Write-debug "ssh port: 		$P"
Write-debug "verbose: 		$V"
Write-debug "debug_ps: 		$D"
Write-debug "user@host[s]:		$HOSTS"

if ($HELP) {
	usage True
	exit 1
}

if ($L) {
	$keys = agentKeys
}

# Validation of Identity param
switch ($I) {
	# Handle $I not being set at all.
	"" {
		if (! $L) { 
			Write-Error "You must provide either -l or -i.  -help for full syntax."
			usage
		}
		break 
	}
	# Check if identity file was passed without the .pub file extension, and add it.
	{Test-Path "${I}.pub" -PathType Leaf} {
		$keys += get-content "${I}.pub"
		write-debug "keys-appendpub: $keys"
		break
	}
	# Check for identity file verbatim
	{Test-Path $I -PathType Leaf} { 
		$keys += get-content $I 
		write-debug "keys-default: $keys"
		break
	}
	# Check the ~\.ssh folder for .pub
	{Test-Path "${env:USERPROFILE}\.ssh\${I}.pub" -PathType Leaf} {
		$keys += get-content "${env:USERPROFILE}\.ssh\${I}.pub" 
		write-debug "keys-.ssh-appendpub: $keys"
		break
	}
	# Check the ~\.ssh folder verbatim
	{Test-Path "${env:USERPROFILE}\.ssh\${I}" -PathType Leaf} {
		$keys += get-content "${env:USERPROFILE}\.ssh\${I}" 
		write-debug "keys-.ssh: $keys"
		break
	}
	default	{ 
		Write-Error "Identity File: $I not found.  Try -i ${env:USERPROFILE}\.ssh\id_rsa.pub or similar."
		usage
	}
}
# handle the edge cases where the user tried to pass in a private key instead of a public key, or an oddly formatted file.
if ($keys -like "*OPENSSH PRIVATE KEY*") {
	Write-Error "Private Key Detected. Invalid public key"
	usage
	}
if (($keys -inotlike "*@openssh.com*") -and ($keys -inotlike "*ssh-*") -and ($key -inotlike "*ecdsa-*") -and ($key -inotlike "*rsa-sha*")) { 
	Write-Error "Missing verified keytype (ssh-/ecdsa-/rsa-sha/openssh.com). Invalid public key"
	usage
}

# Validation of port param
if ($P) {
	if ($P -notmatch '^[0-9]+$') { 
		write-warning "Invalid port: $P" 
		usage 
	}
	# Fixup to simplify logic and match ssh syntax
	$P = "-p $P"
	write-debug "Port: $P"
}

# We don't need to pass around verbose and -o ssh-options seperately, so combine them
if ($V) {
	$O += "-v"
	write-debug "Combined Options: $O"
}

if ($HOSTS) {
	# Make it a collection by space delimiter to allow iteration using foreach.
	$HOSTS_COLLECTION = $HOSTS.Split(" ") 
	foreach ($hostname in $HOSTS_COLLECTION) {
		# inherit username from shell variable if not specified on cli.
		if ($hostname -notlike "*@*") {
			$user = "${env:USERNAME}@"
			write-warning "Username not specified, using $user from environment."
		}
		write-debug "`nHost: $hostname`n User(env): $user`n Port: $P`n Options: $O`n Keys: $keys"
		sendkey "$hostname" "$keys" "$user" "$P" "$O"
	}
} else { 
write-error "user@host parameter is required. Use -help for full syntax."
usage
exit 1
}