#!/bin/sh

bold=$(tput bold)
cyan=$(tput setaf 6)
reset=$(tput sgr0)

# podmah.sh demo script.
# This script will demonstrate a new security features of podman

setup() {
    # rpm -q podman audit oci-seccomp-bpf-hook perl-JSON-PP >/dev/null
    # if [[ $? != 0 ]]; then
	# echo $0 requires the podman, oci-seccomp-bpf-hook, perl-JSON-PP, and audit packages be installed
	# exit 1
    # fi
    augenrules --load > /dev/null
    systemctl restart auditd 2> /dev/null
    cat > /tmp/Containerfile <<EOF
FROM ubi8
RUN  dnf -y install iputils
EOF
    podman build -t ping -f /tmp/Containerfile /tmp
    cat > /tmp/Fedorafile <<EOF
FROM fedora
RUN dnf install -y nc
EOF
    podman build -t myfedora -f /tmp/Fedorafile /tmp
    cat > /tmp/Capfile <<EOF
FROM fedora
LABEL "io.containers.capabilities=SETUID,SETGID"
EOF
    podman build -t fedoracap -f /tmp/Capfile /tmp
    cat > /tmp/InvalidCapfile <<EOF
FROM fedora
LABEL "io.containers.capabilities=NET_ADMIN,SYS_ADMIN"
EOF
    podman build -t fedorainvalidcap -f /tmp/InvalidCapfile /tmp
    clear
}

ping() {
    read -p "
Dropping capabilities prevents ${bold}ping${reset} command from working.

This demonstration show how to drop the NET_RAW Linux capability, and
then how to set a syscall inside of the container, which allows the ping
command to work again.
"
    # Podman ping inside a container
    read -p "--> podman run ping ping -c 3 4.2.2.2"
    echo ""
    podman run ping ping -c 3 4.2.2.2
    echo ""

    # Podman inside a container
    read -p "--> podman run ${bold}--cap-drop NET_RAW${reset} ping ping -c 3 4.2.2.2"
    echo ""
    podman run --cap-drop NET_RAW ping ping -c 3 4.2.2.2
    echo ""
    read -p "
Fails because ${bold}NET_RAW${reset} disabled."

    # Podman inside a container
    read -p "
Execute same container with --sysctl 'net.ipv4.ping_group_range=0 1000' enabled

--> podman run -sysctl --cap-drop NET_RAW ${bold}--sysctl 'net.ipv4.ping_group_range=0 1000'${reset} ping ping -c 3 4.2.2.2"
    echo ""
    podman run -ti --cap-drop NET_RAW --sysctl 'net.ipv4.ping_group_range=0 1000' ping ping -c 3 4.2.2.2
    echo ""
    read -p "--> clear"
    clear
}

capabilities_in_image() {
    # Let image developer select the capabilities they want in the image by setting a label
    read -p "--> cat /tmp/Capfile"
    cat /tmp/Capfile
    echo ""
    read -p "--> podman run --name capctr -d fedoracap sleep 1000"
    podman run --name capctr -d fedoracap sleep 1000
    echo ""
    read -p "--> podman top capctr capeff"
    podman top capctr capeff
    echo ""
    read -p "--> podman run --name defctr -d fedora sleep 1000"
    podman run --name defctr -d fedora sleep 1000
    echo ""
    read -p "--> podman top defctr capeff"
    podman top defctr capeff
    echo ""
    read -p "--> cat /tmp/InvalidCapfile"
    cat /tmp/InvalidCapfile
    echo ""
    read -p "--> podman run --name invalidcapctr -d fedorainvalidcap sleep 1000"
    podman run --name invalidcapctr -d fedorainvalidcap sleep 1000
    echo ""
    read -p "--> podman top invalidcapctr capeff"
    podman top invalidcapctr capeff
    echo ""
    read -p "--> cleanup"
    podman rm -af
    read -p "--> clear"
    clear
}


udica_demo() {
    # Podman run with volumes using udica
    # check /home, /var/spool, and the network nc -lvp (port)
    read -p "--> podman run --rm -v /home:/home:ro -v /var/spool:/var/spool:rw -p 21:21 -it myfedora bash"
    echo ""
    podman run -v /home:/home:ro -v /var/spool:/var/spool:rw -p 21:21 -it myfedora bash
    echo ""
    read -p "Use udica to generate a custom policy for this container"
    echo ""
    read -p "--> podman run --name myctr -v /home:/home:ro -v /var/spool:/var/spool:rw -p 21:21 -d myfedora sleep 1000"
    echo ""
    podman run --name myctr -v /home:/home:ro -v /var/spool:/var/spool:rw -p 21:21 -d myfedora sleep 1000
    echo ""
    read -p "--> podman inspect myctr | udica my_container"
    echo ""
    podman inspect myctr | udica my_container
    echo ""
    read -p "--> semodule -i my_container.cil /usr/share/udica/templates/{base_container.cil,net_container.cil,home_container.cil}"
    semodule -i my_container.cil /usr/share/udica/templates/{base_container.cil,net_container.cil,home_container.cil}
    echo ""
    read -p "--> cleanup"
    podman rm -af 2> /dev/null
    echo ""
    read -p "Let's restart the container"
    echo ""
    read -p "--> podman run --name udica_ctr --security-opt label=type:my_container.process -v /home:/home:ro -v /var/spool:/var/spool:rw -p 21:21 -d myfedora sleep 1000"
    echo ""
    podman run --name udica_ctr --security-opt label=type:my_container.process -v /home:/home:ro -v /var/spool:/var/spool:rw -p 21:21 -d myfedora sleep 1000
    echo ""
    read -p "--> ps -efZ | grep my_container.process"
    ps -efZ | grep my_container.process
    echo ""
    read -p "--> podman exec -it udica_ctr bash"
    podman exec -it udica_ctr bash
    echo ""
    read -p "--> clear"
    clear
}

syscalls() {
    out=$(awk '/SYSCALL/{print $NF}' /var/log/audit/audit.log | grep SYSCALL | cut -f2 -d = | sort -u)
    echo "
"
    for i in $out; do echo -n \"$i\",; done
    echo "
"
    read -p ""
}

seccomp() {
    # Podman Generate Seccomp Rules
    read -p "
Podman Generate Seccomp Rules

This demonstration with use an OCI Hook to fire up a BPF Program to trace
all sycalls generated from a container.

We will then use the generated seccomp file to lock down the container, only
allowing the generated syscalls, rather then the system default.
"
    echo ""

    read -p "--> less /usr/share/containers/oci/hooks.d/oci-seccomp-bpf-hook.json"
    less /usr/share/containers/oci/hooks.d/oci-seccomp-bpf-hook.json
    echo ""
    echo ""

    read -p "--> podman run ${bold}--annotation io.containers.trace-syscall=of:/tmp/myseccomp.json${reset} fedora ls /"
    podman run --annotation io.containers.trace-syscall=of:/tmp/myseccomp.json fedora ls /
    echo ""

    read -p "--> cat /tmp/myseccomp.json | json_pp"
    cat /tmp/myseccomp.json | json_pp > /tmp/myseccomp.pp
    less /tmp/myseccomp.pp
    echo ""
    clear
    read -p "--> podman run ${bold}--security-opt seccomp=/tmp/myseccomp.json${reset} fedora ls /"
    podman run --security-opt seccomp=/tmp/myseccomp.json fedora ls /
    echo ""
    read -p "--> clear"
    clear

    read -p "--> podman run --security-opt seccomp=/tmp/myseccomp.json fedora ${bold}ls -l /${reset}"
    podman run --security-opt seccomp=/tmp/myseccomp.json fedora ls -l /
    echo ""

    read -p "--> grep --color SYSCALL=.* /var/log/audit/audit.log"
    grep --color SYSCALL=.* /var/log/audit/audit.log
    echo ""

    syscalls

    read -p "--> podman run --annotation io.containers.trace-syscall=\"if:/tmp/myseccomp.json;of:/tmp/myseccomp2.json\" fedora ls -l / > /dev/null"
    podman run --annotation io.containers.trace-syscall="if:/tmp/myseccomp.json;of:/tmp/myseccomp2.json" fedora ls -l /
    echo ""

    read -p "--> podman run ${bold}--security-opt seccomp=/tmp/myseccomp2.json${reset} fedora ls -l /"
    podman run --security-opt seccomp=/tmp/myseccomp2.json fedora ls -l /
    echo ""

    read -p "--> diff -u /tmp/myseccomp.json /tmp/myseccomp2.json"
    cat /tmp/myseccomp2.json | json_pp > /tmp/myseccomp2.pp
    diff -u /tmp/myseccomp.pp /tmp/myseccomp2.pp | less
    read -p "--> clear"
    clear
}


containers_conf_ping() {
    read -p "
This demonstration will show how you can specify the default linux capabilities
for all containers on your system.

Then of the demonstration will show ping still running without NET_RAW
Capability, since containers_conf will automatically set the sycall.
"
cat > containers.conf <<EOF
[containers]

# List of default capabilities for containers. If it is empty or commented out,
# the default capabilities defined in the container engine will be added.
#
default_capabilities = [
    "CHOWN",
    "DAC_OVERRIDE",
    "FOWNER",
    "FSETID",
    "KILL",
    "NET_BIND_SERVICE",
    "SETFCAP",
    "SETGID",
    "SETPCAP",
    "SETUID",
]
EOF

    # Podman ping inside a container
    read -p "--> podman run -d fedora sleep 6000"
    echo ""
    podman run -d fedora sleep 6000
    echo ""

    # Podman ping inside a container
    read -p "--> podman top -l capeff"
    echo ""
    podman top -l capeff |  grep --color=auto -B 1 NET_RAW
    echo ""

    # Podman ping inside a container
    read -p "--> cat containers.conf"
    echo ""
    cat containers.conf
    echo ""

    # Podman ping inside a container
    read -p "--> CONTAINERS_CONF=containers.conf podman run -d fedora sleep 6000"
    echo ""
    CONTAINERS_CONF=containers.conf podman run -d fedora sleep 6000
    echo ""

    # Podman ping inside a container
    read -p "--> CONTAINERS_CONF=containers.conf podman top -l capeff"
    echo ""
    CONTAINERS_CONF=containers.conf podman top -l capeff
    echo ""

    # Podman inside a container
    read -p "
Notice NET_RAW as well as AUDIT_WRITE, SYS_CHROOT, and MKNOD capabilies are gone

--> CONTAINERS_CONF=containers.conf podman run ping ping -c 3 4.2.2.2"
    echo ""
    CONTAINERS_CONF=containers.conf podman run ping ping -c 3 4.2.2.2
    echo ""
    read -p "
Fails because ${bold}NET_RAW${reset} disabled.

"

cat >> containers.conf <<EOF

default_sysctls = [
  "net.ipv4.ping_group_range=0 1000",
]

EOF

    # Podman ping inside a container
    read -p "
Let's add the net.ipv4.ping_group syscall to the containers.conf

cat containers.conf
"
    echo ""
    cat containers.conf
    echo ""

    # Podman inside a container
    read -p "--> CONTAINERS_CONF=containers.conf podman run ping ping -c 3 4.2.2.2"
    echo ""
    CONTAINERS_CONF=containers.conf podman run ping ping -c 3 4.2.2.2
    echo ""
    read -p "--> clear"
    clear
}

userns() {
    # Podman user namespace
    read -p "Podman User Namespace Support"
    echo ""

    read -p "--> podman run --uidmap 0:100000:5000 -d fedora sleep 1000"
    podman run --net=host --uidmap 0:100000:5000 -d fedora sleep 1000
    echo ""

    read -p "--> podman top --latest user huser | grep --color=auto -B 1 100000"
    podman top --latest user huser | grep --color=auto -B 1 100000
    echo ""

    read -p "--> ps -ef | grep -v grep | grep --color=auto 100000"
    ps -ef | grep -v grep | grep --color=auto 100000
    echo ""

    read -p "--> podman run --uidmap 0:200000:5000 -d fedora sleep 1000"
    podman run --net=host --uidmap 0:200000:5000 -d fedora sleep 1000
    echo ""

    read -p "--> podman top --latest user huser | grep --color=auto -B 1 200000"
    podman top --latest user huser | grep --color=auto -B 1 200000
    echo ""

    read -p "--> ps -ef | grep -v grep | grep --color=auto 200000"
    ps -ef | grep -v grep | grep --color=auto 200000
    echo ""

    read -p "--> clear"
    clear
}

setup
ping
capabilities_in_image
udica_demo
seccomp
userns
containers_conf_ping

read -p "End of Demo"
echo "Thank you!"
