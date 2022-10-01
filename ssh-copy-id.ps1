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
	[switch]$H,
	[Parameter(HelpMessage="[user@]host [user@host]...", Position = 0, ValueFromRemainingArguments = $true)]
	[string]$HOSTS
)

function usage {
        write-host "usage: ssh-copy-id [-l] [-v] [-d] [-i keyfile] [-o option] [-p port] [user@]hostname" -foregroundcolor yellow
		
		write-host "`nDESCRIPTION
     The ssh-copy-id utility copies public keys to a remote host's
     ~/.ssh/authorized_keys file (creating the file and directory, if
     required).

     The following options are available:

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
	#Please use an editor that displays TAB,CR,LF as visible elements. Use unix-style line endings (LF).
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
	[ -n "$key" ] || continue; \
	#[ -n "$alg" ] || continue; \
	#[ -n "$comment" ] || continue; \
	if ! grep -sqwF "$key" "$keyfile"; then \
		printf \"$alg $key $comment\n\" >> "$keyfile" ; \
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
        $keys = ssh-add -L
		if ($keys -contains 'The agent has no') { 
			Write-Warning "ssh-agent: No keys present."
			return 1 
		}
		return $keys
}

if ($D) {
	$DebugPreference = "Continue"
}

Write-debug "identity: 		$I"
Write-debug "ssh-agent:	 	$L"
Write-debug "options: 		$O"
Write-debug "ssh port: 		$P"
Write-debug "verbose: 		$V"
Write-debug "debug_ps: 		$D"
Write-debug "host:			$H"

if ($H) {
	usage
	exit 1
}

if ($L) {
	$keys = agentKeys
}

# Validation of Identity param
switch ($I) {
	# Handle $I not being set at all.
	"" {
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
if ($P -ne "") {
	if (! $P -is [int]) { Write-error "Invalid port: $P" ; usage }
	# Fixup to use ssh syntax, but only if set so that an unset variable will not impact syntax
	$P = "-p $P"
	write-debug "Port: $P"
}
# We don't need to pass around verbose and -o ssh-options seperately, so combine them
if ($V) {
	$O += "-v"
	write-debug "Combined Options: $O"
}






#while getopts 'i:lo:p:v' arg; do
#        case $arg in
#       i)
#                hasarg="x"
#                if [ -r "${OPTARG}.pub" ]; then
#                        keys="$(cat -- "${OPTARG}.pub")$nl$keys"
#                elif [ -r "$OPTARG" ]; then
#                        keys="$(cat -- "$OPTARG")$nl$keys"
#                else
#                        echo "File $OPTARG not found" >&2
#                        exit 1
#                fi
#                ;;
#        l)
#                hasarg="x"
#                agentKeys
#                ;;
#		p)
#                port=-p$nl$OPTARG
#                ;;
#        o)
#                options=$options$nl-o$nl$OPTARG
#                ;;
#        v)
#                options="$options$nl-v"
#                ;;
#        *)
#                usage
#                ;;
#        esac
#done >&2

#shift $((OPTIND-1))

#if [ -z "$hasarg" ]; then
#        agentKeys
#fi
#if [ -z "$keys" ] || [ "$keys" = "$nl" ]; then
#        echo "no keys found" >&2
#        exit 1
#fi
#if [ "$#" -eq 0 ]; then
#        usage
#fi

foreach ($hostname in "$HOSTS") {
	write-debug "`nHost: $hostname`n Keys: $keys`n User: $user`n Port: $P`n Options: $O"
    sendkey "$hostname" "$keys" "$user" "$P" "$O"
}