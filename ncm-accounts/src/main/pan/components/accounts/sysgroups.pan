# ${license-info}
# ${developer-info}
# ${author-info}


############################################################
#
# System groups which shouldn't be removed by component.
# This template MUST be included in the configuration!
#
############################################################

unique template components/accounts/sysgroups;

'/software/components/accounts/kept_groups' ?= nlist(
    'bin', '',
    'daemon' ,'',
    'sys' ,'',
    'adm' ,'',
    'tty' ,'',
    'disk' ,'',
    'lp' ,'',
    'mem' ,'',
    'kmem' ,'',
    'wheel' ,'',
    'mail' ,'',
    'news' ,'',
    'uucp' ,'',
    'man' ,'',
    'floppy' ,'',
    'games' ,'',
    'slocate' ,'',
    'utmp' ,'',
    'nscd' ,'',
    'rpcuser' ,'',
    'gopher' ,'',
    'rpc' ,'',
    'rpm' ,'',
    'ntp' ,'',
    'dip' ,'',
    'gdm' ,'',
    'xfs' ,'',
    'mailnull' ,'',
    'ftp' ,'',
    'lock' ,'',
    'wine' ,'',
    'vcsa' ,'',
    'sshd' ,'',
    'radvd' ,'',
    'postfix' ,'',
    'postgres' ,'',
    'postdrop' ,'',
    'ident' ,'',
    'nobody' ,'',
    'users' ,'',
    'nfsnobody' ,'',
    'apache' ,'',
    'pcap' ,'',
    'mysql' ,'',
    'ident' ,'',
    'radvd' ,'',
    'smmsp' ,'',
    'root' ,'',
    'nagios' ,'',
    'plugdev' ,'',
    'usb' ,'',
    'sindes' ,'',
    'stapusr' ,'',
    'exim' ,'',
    'stapdev' ,'',
    'lemon', '',
    'haldaemon' ,'');
