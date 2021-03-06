# --
# RPM spec file for OpenSUSE 11.x of the OTRS package
# Copyright (C) 2001-2011 OTRS AG, http://otrs.org/
# --
# $Id: suse-otrs-11.0.spec,v 1.7.2.2 2011/09/08 14:29:36 mg Exp $
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --
#
# please send bugfixes or comments to bugs+rpm@otrs.org
#
# --
Summary:      The Open Ticket Request System.
Name:         otrs
Version:      0.0
Copyright:    GNU AFFERO GENERAL PUBLIC LICENSE Version 3, 19 November 2007
Group:        Applications/Mail
Provides:     otrs
Requires:     perl perl-DBI perl-GD perl-GDGraph perl-GDTextUtil perl-Net-DNS perl-Digest-MD5 apache2 apache2-mod_perl mysql mysql-client perl-DBD-mysql procmail perl-libwww-perl perl-Encode-HanExtra perl-ldap perl-IO-Socket-SSL perl-SOAP-Lite perl-PDF-API2
Autoreqprov:  on
Release:      01
Source0:      otrs-%{version}.tar.bz2
BuildArch:    noarch
BuildRoot:    %{_tmppath}/%{name}-%{version}-build

%description
<DESCRIPTION>

SuSE series: ap

%prep
%setup

%build
# copy config file
cp Kernel/Config.pm.dist Kernel/Config.pm
cd Kernel/Config/ && for foo in *.dist; do cp $foo `basename $foo .dist`; done && cd ../../
# copy all crontab dist files
for foo in var/cron/*.dist; do mv $foo var/cron/`basename $foo .dist`; done
# copy all .dist files
cp .procmailrc.dist .procmailrc
cp .fetchmailrc.dist .fetchmailrc
cp .mailfilter.dist .mailfilter

%install
# delete old RPM_BUILD_ROOT
rm -rf $RPM_BUILD_ROOT
# set DESTROOT
export DESTROOT="/opt/otrs/"
# create RPM_BUILD_ROOT DESTROOT
mkdir -p $RPM_BUILD_ROOT/$DESTROOT/
# copy files
cp -R . $RPM_BUILD_ROOT/$DESTROOT
# install init-Script and rc.config entry
install -d -m 755 $RPM_BUILD_ROOT/etc/init.d
install -d -m 755 $RPM_BUILD_ROOT/usr/sbin
install -d -m 755 $RPM_BUILD_ROOT/etc/sysconfig
install -d -m 744 $RPM_BUILD_ROOT/var/adm/fillup-templates
install -d -m 755 $RPM_BUILD_ROOT/etc/apache2/conf.d

# replace apache with apache2
sed  "s/rcapache/rcapache2/" scripts/suse-rcotrs-config > /tmp.otrs.$$ && mv /tmp.otrs.$$ scripts/suse-rcotrs-config
sed  "s/apache/apache2/" scripts/suse-rcotrs > /tmp.otrs.$$ && mv /tmp.otrs.$$ scripts/suse-rcotrs
install -m 644 scripts/suse-rcotrs-config $RPM_BUILD_ROOT/etc/sysconfig/otrs

install -m 755 scripts/suse-rcotrs $RPM_BUILD_ROOT/etc/init.d/otrs
rm -f $RPM_BUILD_ROOT/sbin/otrs
ln -s ../../etc/init.d/otrs $RPM_BUILD_ROOT/usr/sbin/rcotrs

install -m 644 scripts/apache2-httpd.include.conf $RPM_BUILD_ROOT/etc/apache2/conf.d/otrs.conf

# set permission
export OTRSUSER=otrs
useradd $OTRSUSER || :
useradd wwwrun || :
groupadd www || :
$RPM_BUILD_ROOT/opt/otrs/bin/otrs.SetPermissions.pl --otrs-user=$OTRSUSER --web-user=wwwrun --otrs-group=www --web-group=www $RPM_BUILD_ROOT/opt/otrs

%pre
# remember about the installed version
if test -e /opt/otrs/RELEASE; then
    cat /opt/otrs/RELEASE|grep VERSION|sed 's/VERSION = //'|sed 's/ /-/g' > /tmp/otrs-old.tmp
fi
# useradd
export OTRSUSER=otrs
echo -n "Check OTRS user ... "
if id $OTRSUSER >/dev/null 2>&1; then
    echo "$OTRSUSER exists."
    # update groups
    usermod -g www $OTRSUSER
    # update home dir
    usermod -d /opt/otrs $OTRSUSER
else
    useradd $OTRSUSER -d /opt/otrs/ -s /bin/false -g www -c 'OTRS System User' && echo "$OTRSUSER added."
fi


%post
# sysconfig
%{fillup_and_insserv -s otrs START_OTRS}

# if it's a major-update backup old version templates (maybe not compatible!)
if test -e /tmp/otrs-old.tmp; then
    TOINSTALL=`echo %{version}| sed 's/..$//'`
    OLDOTRS=`cat /tmp/otrs-old.tmp`
    if echo $OLDOTRS | grep -v "$TOINSTALL" > /dev/null; then
        echo "backup old (maybe not compatible) templates (of $OLDOTRS)"
        for i in /opt/otrs/Kernel/Output/HTML/Standard/*.rpmnew;
            do BF=`echo $i|sed 's/.rpmnew$//'`; mv -v $BF $BF.backup_maybe_not_compat_to.$OLDOTRS; mv $i $BF;
        done
    fi
    rm -rf /tmp/otrs-old.tmp
fi

# OTRS 2.0 -> OTRS 2.1
# remove old ticket config file
if test -e /opt/otrs/Kernel/Config/Files/Ticket.pm; then
    mv /opt/otrs/Kernel/Config/Files/Ticket.pm /opt/otrs/Kernel/Config/Files/Ticket.pm.not_longer_used
fi;
# remove old ticket postmaster config file
if test -e /opt/otrs/Kernel/Config/Files/TicketPostMaster.pm; then
    mv /opt/otrs/Kernel/Config/Files/TicketPostMaster.pm /opt/otrs/Kernel/Config/Files/TicketPostMaster.pm.not_longer_used;
fi
# remove old faq config file
if test -e /opt/otrs/Kernel/Config/Files/FAQ.pm; then
    mv /opt/otrs/Kernel/Config/Files/FAQ.pm /opt/otrs/Kernel/Config/Files/FAQ.pm.not_longer_used;
fi

# run OTRS rebuild config, delete cache, if the system was already in use (i.e. upgrade).
if test -e /opt/otrs/Kernel/Config/Files/ZZZAAuto.pm; then
    /opt/otrs/bin/otrs.RebuildConfig.pl;
    /opt/otrs/bin/otrs.DeleteCache.pl;
fi

# note
HOST=`hostname -f`
echo ""
echo "Next steps: "
echo ""
echo "[SuSEconfig]"
echo " Execute 'SuSEconfig' to configure the webserver."
echo ""
echo "[start Apache and MySQL]"
echo " Execute 'rcapache2 restart' and 'rcmysql start' in case they don't run."
echo ""
echo "[install the OTRS database]"
echo " Use a webbrowser and open this link:"
echo " http://$HOST/otrs/installer.pl"
echo ""
echo "[OTRS services]"
echo " Start OTRS 'rcotrs start-force' (rcotrs {start|stop|status|restart|start-force|stop-force})."
echo ""
echo "((enjoy))"
echo ""
echo " Your OTRS Team"
echo " http://otrs.org/"
echo ""

%clean
rm -rf $RPM_BUILD_ROOT

%files
%config(noreplace) /etc/sysconfig/otrs
%config /etc/apache2/conf.d/otrs.conf

/etc/init.d/otrs
/usr/sbin/rcotrs

<FILES>

%changelog
* Thu Oct 18 2006 - martin+rpm@otrs.org
- added rename of old /opt/otrs/Kernel/Config/Files/(Ticket|TicketPostMaster|FAQ).pm files
* Sun Mar 25 2006 - martin+rpm@otrs.org
- added SUSE 10.0 support
