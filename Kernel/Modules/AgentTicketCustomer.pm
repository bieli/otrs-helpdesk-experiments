# --
# Kernel/Modules/AgentTicketCustomer.pm - to set the ticket customer and show the customer history
# Copyright (C) 2001-2011 OTRS AG, http://otrs.org/
# --
# $Id: AgentTicketCustomer.pm,v 1.38.2.2 2011/05/09 22:35:48 en Exp $
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentTicketCustomer;

use strict;
use warnings;

use Kernel::System::CustomerUser;

use vars qw($VERSION);
$VERSION = qw($Revision: 1.38.2.2 $) [1];

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # check needed Objects
    for my $Needed (qw(ParamObject DBObject TicketObject LayoutObject LogObject ConfigObject)) {
        if ( !$Self->{$Needed} ) {
            $Self->{LayoutObject}->FatalError( Message => "Got no $Needed!" );
        }
    }

    $Self->{Search}     = $Self->{ParamObject}->GetParam( Param => 'Search' )     || 0;
    $Self->{CustomerID} = $Self->{ParamObject}->GetParam( Param => 'CustomerID' ) || '';

    # customer user object
    $Self->{CustomerUserObject} = Kernel::System::CustomerUser->new(%Param);

    $Self->{Config} = $Self->{ConfigObject}->Get("Ticket::Frontend::$Self->{Action}");

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $Output;

    # check needed stuff
    if ( !$Self->{TicketID} ) {

        # error page
        return $Self->{LayoutObject}->ErrorScreen(
            Message => 'No TicketID is given!',
            Comment => 'Please contact the admin.',
        );
    }

    # check permissions
    if (
        !$Self->{TicketObject}->TicketPermission(
            Type     => $Self->{Config}->{Permission},
            TicketID => $Self->{TicketID},
            UserID   => $Self->{UserID}
        )
        )
    {

        # error screen, don't show ticket
        return $Self->{LayoutObject}->NoPermission(
            Message    => "You need $Self->{Config}->{Permission} permissions!",
            WithHeader => 'yes',
        );
    }

    # check permissions
    if ( $Self->{TicketID} ) {
        if (
            !$Self->{TicketObject}->TicketPermission(
                Type     => 'customer',
                TicketID => $Self->{TicketID},
                UserID   => $Self->{UserID}
            )
            )
        {

            # no permission screen, don't show ticket
            return $Self->{LayoutObject}->NoPermission( WithHeader => 'yes' );
        }
    }

    if ( $Self->{Subaction} eq 'Update' ) {

        # challenge token check for write action
        $Self->{LayoutObject}->ChallengeTokenCheck();

        # set customer id
        my $ExpandCustomerName1 = $Self->{ParamObject}->GetParam( Param => 'ExpandCustomerName1' )
            || 0;
        my $ExpandCustomerName2 = $Self->{ParamObject}->GetParam( Param => 'ExpandCustomerName2' )
            || 0;
        my $CustomerUserOption = $Self->{ParamObject}->GetParam( Param => 'CustomerUserOption' )
            || '';
        $Param{CustomerUserID} = $Self->{ParamObject}->GetParam( Param => 'CustomerUserID' ) || '';
        $Param{CustomerID}     = $Self->{ParamObject}->GetParam( Param => 'CustomerID' )     || '';
        $Param{SelectedCustomerUser}
            = $Self->{ParamObject}->GetParam( Param => 'SelectedCustomerUser' ) || '';

        # use customer login instead of email address if applicable
        if ( $Param{SelectedCustomerUser} ne q{} ) {
            $Param{CustomerUserID} = $Param{SelectedCustomerUser};
        }

        # Expand Customer Name
        if ($ExpandCustomerName1) {

            # search customer
            my %CustomerUserList = ();
            %CustomerUserList
                = $Self->{CustomerUserObject}->CustomerSearch( Search => $Param{CustomerUserID}, );

            # check if just one customer user exists
            # if just one, fillup CustomerUserID and CustomerID
            $Param{CustomerUserListCount} = 0;
            for my $KeyCustomerUser ( keys %CustomerUserList ) {
                $Param{CustomerUserListCount}++;
                $Param{CustomerUserListLast}     = $CustomerUserList{$KeyCustomerUser};
                $Param{CustomerUserListLastUser} = $KeyCustomerUser;
            }
            if ( $Param{CustomerUserListCount} == 1 ) {
                $Param{CustomerUserID} = $Param{CustomerUserListLastUser};
                my %CustomerUserData = $Self->{CustomerUserObject}->CustomerUserDataGet(
                    User => $Param{CustomerUserListLastUser},
                );
                if ( $CustomerUserData{UserCustomerID} ) {
                    $Param{CustomerID} = $CustomerUserData{UserCustomerID};
                }

            }

            # if more the one customer user exists, show list
            # and clean CustomerID
            else {
                $Param{CustomerID} = '';
                $Param{"CustomerUserOptions"} = \%CustomerUserList;
            }
            return $Self->Form(%Param);
        }

        # get customer user and customer id
        elsif ($ExpandCustomerName2) {
            my %CustomerUserData
                = $Self->{CustomerUserObject}->CustomerUserDataGet( User => $CustomerUserOption, );
            my %CustomerUserList
                = $Self->{CustomerUserObject}->CustomerSearch( UserLogin => $CustomerUserOption, );
            for my $KeyCustomerUser ( keys %CustomerUserList ) {
                $Param{CustomerUserID} = $KeyCustomerUser;
            }
            if ( $CustomerUserData{UserCustomerID} ) {
                $Param{CustomerID} = $CustomerUserData{UserCustomerID};
            }
            return $Self->Form(%Param);
        }

        my %Error;

        # check needed data
        if ( !$Param{CustomerUserID} ) {
            $Error{'CustomerUserIDInvalid'} = 'ServerError';
        }
        if ( !$Param{CustomerID} ) {
            $Error{'CustomerIDInvalid'} = 'ServerError';
        }

        if (%Error) {
            return $Self->Form( { %Param, %Error } );
        }

        # update customer user data
        if (
            $Self->{TicketObject}->TicketCustomerSet(
                TicketID => $Self->{TicketID},
                No       => $Param{CustomerID},
                User     => $Param{CustomerUserID},
                UserID   => $Self->{UserID},
            )
            )
        {

            # redirect
            return $Self->{LayoutObject}->PopupClose(
                URL =>
                    $Self->{LastScreenView}
                    || "Action=AgentTicketZoom;TicketID=$Self->{TicketID}",
            );
        }
        else {

            # error?!
            return $Self->{LayoutObject}->ErrorScreen();
        }
    }

    # show form
    else {
        return $Self->Form(%Param);
    }
}

sub Form {
    my ( $Self, %Param ) = @_;

    my $Output;

    # get autocomplete config
    my $AutoCompleteConfig
        = $Self->{ConfigObject}->Get('Ticket::Frontend::CustomerSearchAutoComplete');

    # print header
    $Output .= $Self->{LayoutObject}->Header(
        Type => 'Small',
    );
    my $TicketCustomerID = $Self->{CustomerID};

    # print change form if ticket id is given
    my %CustomerUserData = ();
    if ( $Self->{TicketID} ) {

        # set some customer search autocomplete properties
        $Self->{LayoutObject}->Block(
            Name => 'CustomerSearchAutoComplete',
            Data => {
                minQueryLength      => $AutoCompleteConfig->{MinQueryLength}      || 2,
                queryDelay          => $AutoCompleteConfig->{QueryDelay}          || 100,
                typeAhead           => $AutoCompleteConfig->{TypeAhead}           || 'false',
                maxResultsDisplayed => $AutoCompleteConfig->{MaxResultsDisplayed} || 20,
                ActiveAutoComplete  => $AutoCompleteConfig->{Active},
            },
        );

        # get ticket data
        my %TicketData = $Self->{TicketObject}->TicketGet( TicketID => $Self->{TicketID} );
        if ( $TicketData{CustomerUserID} || $Param{CustomerUserID} ) {
            %CustomerUserData
                = $Self->{CustomerUserObject}->CustomerUserDataGet(
                User => $Param{CustomerUserID}
                    || $TicketData{CustomerUserID},
                );
        }
        $TicketCustomerID = $TicketData{CustomerID};
        $Param{Table} = $Self->{LayoutObject}->AgentCustomerViewTable(
            Data => \%CustomerUserData,
            Max  => $Self->{ConfigObject}->Get('Ticket::Frontend::CustomerInfoComposeMaxSize'),
        );

        # show customer field as "FirstName Lastname" <MailAddress>
        if (%CustomerUserData) {
            $TicketData{CustomerUserID} = "\"$CustomerUserData{UserFirstname} " .
                "$CustomerUserData{UserLastname}\" <$CustomerUserData{UserEmail}>";
        }
        $Self->{LayoutObject}->Block(
            Name => 'Customer',
            Data => { %TicketData, %Param, },
        );
    }

    $Output
        .= $Self->{LayoutObject}->Output( TemplateFile => 'AgentTicketCustomer', Data => \%Param );
    $Output .= $Self->{LayoutObject}->Footer(
        Type => 'Small',
    );
    return $Output;
}

1;
