# .bashrc
[ -z "$PS1" ] && return
. /etc/profile

# Source global definitions
if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi

# User specific aliases and functions
PS1='[\e[37m\#\e[31m@\t \e[37m\u\e[31m@\h\e[37m]:\w\e[31m>\e[37m'
cd
echo
echo "Uptime:`uptime`"
echo
echo "Who's here:"
who -u
echo
df -h | grep -P "^(F|\/)"
echo
free -lt
echo
netstat -lptu
echo
service --status-all | grep -iP "is\srunning"
export EDITOR=vi
alias yi='yum install -y $1'
alias yin='yum info $1'
alias yl='yum list $1'
alias yr='yum remove $1'
alias yre='yum repolist'
alias ys='yum search $1'
alias yu='yum update'
