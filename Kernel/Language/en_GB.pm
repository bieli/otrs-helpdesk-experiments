# --
# Kernel/Language/en_GB.pm - provides British English language translation
# Copyright (C) 2001-2011 OTRS AG, http://otrs.org/
# --
# $Id: en_GB.pm,v 1.7.2.2 2011/04/05 09:10:52 mb Exp $
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Language::en_GB;

use strict;
use warnings;

use vars qw($VERSION);
$VERSION = qw($Revision: 1.7.2.2 $) [1];

sub Data {
    my $Self = shift;

    # http://en.wikipedia.org/wiki/Date_and_time_notation_by_country#United_Kingdom
    # day-month-year (e.g., "31/12/99")

    # $$START$$
    # Last translation file sync: Thu Apr  9 10:12:50 2009

    # possible charsets
    $Self->{Charset} = ['us-ascii', 'UTF-8', 'iso-8859-1', 'iso-8859-15', ];

    # date formats (%A=WeekDay;%B=LongMonth;%T=Time;%D=Day;%M=Month;%Y=Year;)
    $Self->{DateFormat}          = '%D/%M/%Y %T';
    $Self->{DateFormatLong}      = '%T - %D/%M/%Y';
    $Self->{DateFormatShort}     = '%D/%M/%Y';
    $Self->{DateInputFormat}     = '%D/%M/%Y';
    $Self->{DateInputFormatLong} = '%D/%M/%Y - %T';
    $Self->{Separator}           = ',';

    # maybe nothing ... or help texts
    $Self->{Translation} = {
        'May_long' => 'May',
        'History::Move' => 'Ticket moved into Queue "%s" (%s) from Queue "%s" (%s).',
        'History::TypeUpdate' => 'Updated Type to %s (ID=%s).',
        'History::ServiceUpdate' => 'Updated Service to %s (ID=%s).',
        'History::SLAUpdate' => 'Updated SLA to %s (ID=%s).',
        'History::NewTicket' => 'New Ticket [%s] created (Q=%s;P=%s;S=%s).',
        'History::FollowUp' => 'FollowUp for [%s]. %s',
        'History::SendAutoReject' => 'AutoReject sent to "%s".',
        'History::SendAutoReply' => 'AutoReply sent to "%s".',
        'History::SendAutoFollowUp' => 'AutoFollowUp sent to "%s".',
        'History::Forward' => 'Forwarded to "%s".',
        'History::Bounce' => 'Bounced to "%s".',
        'History::SendAnswer' => 'Email sent to "%s".',
        'History::SendAgentNotification' => '"%s"-notification sent to "%s".',
        'History::SendCustomerNotification' => 'Notification sent to "%s".',
        'History::EmailAgent' => 'Email sent to customer.',
        'History::EmailCustomer' => 'Added email. %s',
        'History::PhoneCallAgent' => 'Agent called customer.',
        'History::PhoneCallCustomer' => 'Customer called us.',
        'History::AddNote' => 'Added note (%s)',
        'History::Lock' => 'Locked ticket.',
        'History::Unlock' => 'Unlocked ticket.',
        'History::TimeAccounting' => '%s time unit(s) accounted. Now total %s time unit(s).',
        'History::Remove' => '%s',
        'History::CustomerUpdate' => 'Updated: %s',
        'History::PriorityUpdate' => 'Changed priority from "%s" (%s) to "%s" (%s).',
        'History::OwnerUpdate' => 'New owner is "%s" (ID=%s).',
        'History::ResponsibleUpdate' => 'New responsible is "%s" (ID=%s).',
        'History::LoopProtection' => 'Loop-Protection! No auto-response sent to "%s".',
        'History::Misc' => '%s',
        'History::SetPendingTime' => 'Updated: %s',
        'History::StateUpdate' => 'Old: "%s" New: "%s"',
        'History::TicketFreeTextUpdate' => 'Updated: %s=%s;%s=%s;',
        'History::WebRequestCustomer' => 'Customer request via web.',
        'History::TicketLinkAdd' => 'Added link to ticket "%s".',
        'History::TicketLinkDelete' => 'Deleted link to ticket "%s".',
        'History::Subscribe' => 'Added subscription for user "%s".',
        'History::Unsubscribe' => 'Removed subscription for user "%s".',
        'History::SystemRequest' => 'System Request (%s).',
        'History::ArchiveFlagUpdate' => 'Archive state changed: "%s"',
        #CustomerUser fields
        'Title{CustomerUser}' => 'Title',
        'Firstname{CustomerUser}' => 'First name',
        'Lastname{CustomerUser}' => 'Surname',
        'Username{CustomerUser}' => 'Username',
        'Email{CustomerUser}' => 'E-mail address',
        'CustomerID{CustomerUser}' => 'Customer ID',
        'Phone{CustomerUser}' => 'Phone',
        'Fax{CustomerUser}' => 'Fax',
        'Mobile{CustomerUser}' => 'Mobile',
        'Street{CustomerUser}' => 'Street',
        'Zip{CustomerUser}' => 'Postcode',
        'City{CustomerUser}' => 'City',
        'Country{CustomerUser}' => 'Country',
        'Comment{CustomerUser}' => 'Comment',
        #User field
        'Title{user}' => 'Title',
        #'Statuses' is American English
        'Statuses'    => 'Status',
        #'License' is American English
        'License' => 'Licence',
        'To accept some news, a license or some changes.' => 'To accept some news, a licence or some changes.',
        'Accept license' => 'Accept licence',
        'Don\'t accept license' => 'Don\'t accept licence'
    };
    # $$STOP$$
    return;
}

1;
