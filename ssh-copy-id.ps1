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
	[Parameter(HelpMessage="[user@]host [user@host]...", Mandatory = $True, Position = 0, ValueFromRemainingArguments = $true)]
	[string]$H
)

function usage {
        write-host "usage: ssh-copy-id [-lv] [-i keyfile] [-o option] [-p port] [user@]hostname" -foregroundcolor yellow
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
		write-debug "Keys: $k"
}

function agentKeys {
        $keys = ssh-add -L
		if ($keys -contains 'The agent has no') { return 1 }
		$keys = "${nl}${keys}"
}

#$DebugPreference = "Continue"

Write-debug "identity: 		$I"
Write-debug "ssh-agent:	 	$L"
Write-debug "options: 		$O"
Write-debug "ssh port: 		$P"
Write-debug "verbose: 		$V"
Write-debug "host:			$H"

# Validation of Identity param
switch ($I) {
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
	(Test-Path "${env:USERPROFILE}\.ssh\${I}.pub" -PathType Leaf) {
		$keys += get-content "${env:USERPROFILE}\.ssh\${I}.pub" 
		write-debug "keys-.ssh-appendpub: $keys"
		break
	}
	# Check the ~\.ssh folder verbatim
	(Test-Path "${env:USERPROFILE}\.ssh\${I}" -PathType Leaf) {
		$keys += get-content "${env:USERPROFILE}\.ssh\${I}" 
		write-debug "keys-.ssh: $keys"
		break
	}
	default	{ 
		Write-Error "Identity File: $I not found.  Try -i ${env:USERPROFILE}\.ssh\id_rsa.pub or similar."
		usage
	}
}
# handle the edge case where the user tried to pass in a private key instead of a public key, or an oddly formatted file.
if (($keys -like "*OPENSSH PRIVATE KEY*") -or ($keys -inotlike "*@openssh.com*")) { Write-Error "Invalid public key file $I"; usage }

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

foreach ($hostname in "$H") {
	write-debug "`nHost: $hostname`n Keys: $keys`n User: $user`n Port: $P`n Options: $O"
    sendkey "$hostname" "$keys" "$user" "$P" "$O"
}