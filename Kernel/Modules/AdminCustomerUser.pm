# --
# Kernel/Modules/AdminCustomerUser.pm - to add/update/delete customer user and preferences
# Copyright (C) 2001-2011 OTRS AG, http://otrs.org/
# --
# $Id: AdminCustomerUser.pm,v 1.89.2.6 2011/04/06 16:37:27 en Exp $
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AdminCustomerUser;

use strict;
use warnings;

use Kernel::System::CustomerUser;
use Kernel::System::CustomerCompany;
use Kernel::System::Valid;
use Kernel::System::CheckItem;

use vars qw($VERSION);
$VERSION = qw($Revision: 1.89.2.6 $) [1];

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # check all needed objects
    for my $Needed (
        qw(ParamObject DBObject EncodeObject LayoutObject ConfigObject LogObject UserObject)
        )
    {
        if ( !$Self->{$Needed} ) {
            $Self->{LayoutObject}->FatalError( Message => "Got no $Needed!" );
        }
    }

    # create additonal objects
    $Self->{CustomerUserObject}    = Kernel::System::CustomerUser->new(%Param);
    $Self->{CustomerCompanyObject} = Kernel::System::CustomerCompany->new(%Param);
    $Self->{ValidObject}           = Kernel::System::Valid->new(%Param);

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $Nav    = $Self->{ParamObject}->GetParam( Param => 'Nav' )    || '';
    my $Source = $Self->{ParamObject}->GetParam( Param => 'Source' ) || 'CustomerUser';
    my $Search = $Self->{ParamObject}->GetParam( Param => 'Search' );
    $Search
        ||= $Self->{ConfigObject}->Get('AdminCustomerUser::RunInitialWildcardSearch') ? '*' : '';

    #create local object
    my $CheckItemObject = Kernel::System::CheckItem->new( %{$Self} );

    my $NavBar = '';
    if ( $Nav eq 'None' ) {
        $NavBar = $Self->{LayoutObject}->Header( Type => 'Small' );
    }
    else {
        $NavBar = $Self->{LayoutObject}->Header();
        $NavBar .= $Self->{LayoutObject}->NavigationBar(
            Type => $Nav eq 'Agent' ? 'Customers' : 'Admin',
        );
    }

    # search user list
    if ( $Self->{Subaction} eq 'Search' ) {
        $Self->_Overview(
            Nav    => $Nav,
            Search => $Search,
        );
        my $Output = $NavBar;
        $Output .= $Self->{LayoutObject}->Output(
            TemplateFile => 'AdminCustomerUser',
            Data         => \%Param,
        );

        if ( $Nav eq 'None' ) {
            $Output .= $Self->{LayoutObject}->Footer( Type => 'Small' );
        }
        else {
            $Output .= $Self->{LayoutObject}->Footer();
        }

        return $Output;
    }

    # ------------------------------------------------------------ #
    # download file preferences
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'Download' ) {
        my $Group = $Self->{ParamObject}->GetParam( Param => 'Group' ) || '';
        my $User  = $Self->{ParamObject}->GetParam( Param => 'ID' )    || '';
        my $File  = $Self->{ParamObject}->GetParam( Param => 'File' )  || '';

        # get user data
        my %UserData    = $Self->{CustomerUserObject}->CustomerUserDataGet( User => $User );
        my %Preferences = %{ $Self->{ConfigObject}->Get('CustomerPreferencesGroups') };
        my $Module      = $Preferences{$Group}->{Module};
        if ( !$Self->{MainObject}->Require($Module) ) {
            return $Self->{LayoutObject}->FatalError();
        }
        my $Object = $Module->new(
            %{$Self},
            ConfigItem => $Preferences{$Group},
            UserObject => $Self->{CustomerUserObject},
            Debug      => $Self->{Debug},
        );
        my %File = $Object->Download( UserData => \%UserData );

        return $Self->{LayoutObject}->Attachment(%File);
    }

    # ------------------------------------------------------------ #
    # change
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'Change' ) {
        my $User = $Self->{ParamObject}->GetParam( Param => 'ID' ) || '';

        # get user data
        my %UserData = $Self->{CustomerUserObject}->CustomerUserDataGet( User => $User );
        my $Output = $NavBar;
        $Output .= $Self->_Edit(
            Nav    => $Nav,
            Action => 'Change',
            Source => $Source,
            Search => $Search,
            ID     => $User,
            %UserData,
        );

        if ( $Nav eq 'None' ) {
            $Output .= $Self->{LayoutObject}->Footer( Type => 'Small' );
        }
        else {
            $Output .= $Self->{LayoutObject}->Footer();
        }

        return $Output;
    }

    # ------------------------------------------------------------ #
    # change action
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'ChangeAction' ) {
        my $Note = '';
        my ( %GetParam, %Errors );
        for my $Entry ( @{ $Self->{ConfigObject}->Get($Source)->{Map} } ) {
            $GetParam{ $Entry->[0] } = $Self->{ParamObject}->GetParam( Param => $Entry->[0] ) || '';

            # check mandatory fields
            if ( !$GetParam{ $Entry->[0] } && $Entry->[4] ) {
                $Errors{ $Entry->[0] . 'Invalid' } = 'ServerError';
            }
        }
        $GetParam{ID} = $Self->{ParamObject}->GetParam( Param => 'ID' ) || '';

        # check email address
        if (
            $GetParam{UserEmail}
            && !$CheckItemObject->CheckEmail( Address => $GetParam{UserEmail} )
            )
        {
            $Errors{UserEmailInvalid} = 'ServerError';
            $Errors{ErrorType}        = $CheckItemObject->CheckErrorType() . 'ServerErrorMsg';
        }

        # if no errors occurred
        if ( !%Errors ) {

            # update user
            my $Update = $Self->{CustomerUserObject}->CustomerUserUpdate(
                %GetParam,
                UserID => $Self->{UserID},
            );
            if ($Update) {

                # update preferences
                my %Preferences = %{ $Self->{ConfigObject}->Get('CustomerPreferencesGroups') };
                for my $Group ( keys %Preferences ) {
                    next if $Group eq 'Password';

                    # get user data
                    my %UserData = $Self->{CustomerUserObject}->CustomerUserDataGet(
                        User => $GetParam{UserLogin}
                    );
                    my $Module = $Preferences{$Group}->{Module};
                    if ( !$Self->{MainObject}->Require($Module) ) {
                        return $Self->{LayoutObject}->FatalError();
                    }
                    my $Object = $Module->new(
                        %{$Self},
                        ConfigItem => $Preferences{$Group},
                        UserObject => $Self->{CustomerUserObject},
                        Debug      => $Self->{Debug},
                    );
                    my @Params = $Object->Param( UserData => \%UserData );
                    if (@Params) {
                        my %GetParam;
                        for my $ParamItem (@Params) {
                            my @Array
                                = $Self->{ParamObject}->GetArray( Param => $ParamItem->{Name} );
                            $GetParam{ $ParamItem->{Name} } = \@Array;
                        }
                        if ( !$Object->Run( GetParam => \%GetParam, UserData => \%UserData ) ) {
                            $Note .= $Self->{LayoutObject}->Notify( Info => $Object->Error() );
                        }
                    }
                }

                # get user data and show screen again
                if ( !$Note ) {
                    $Self->_Overview(
                        Nav    => $Nav,
                        Search => $Search,
                    );
                    my $Output = $NavBar . $Note;
                    $Output .= $Self->{LayoutObject}->Notify( Info => 'Customer updated!' );
                    $Output .= $Self->{LayoutObject}->Output(
                        TemplateFile => 'AdminCustomerUser',
                        Data         => \%Param,
                    );

                    if ( $Nav eq 'None' ) {
                        $Output .= $Self->{LayoutObject}->Footer( Type => 'Small' );
                    }
                    else {
                        $Output .= $Self->{LayoutObject}->Footer();
                    }

                    return $Output;
                }
            }
            else {
                $Note .= $Self->{LayoutObject}->Notify( Priority => 'Error' );
            }
        }

        # something has gone wrong
        my $Output = $NavBar;
        $Output .= $Note;
        $Output .= $Self->_Edit(
            Nav    => $Nav,
            Action => 'Change',
            Source => $Source,
            Search => $Search,
            Errors => \%Errors,
            %GetParam,
        );

        if ( $Nav eq 'None' ) {
            $Output .= $Self->{LayoutObject}->Footer( Type => 'Small' );
        }
        else {
            $Output .= $Self->{LayoutObject}->Footer();
        }

        return $Output;
    }

    # ------------------------------------------------------------ #
    # add
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'Add' ) {
        my %GetParam;
        $GetParam{UserLogin} = $Self->{ParamObject}->GetParam( Param => 'UserLogin' ) || '';
        my $Output = $NavBar;
        $Output .= $Self->_Edit(
            Nav    => $Nav,
            Action => 'Add',
            Source => $Source,
            Search => $Search,
            %GetParam,
        );

        if ( $Nav eq 'None' ) {
            $Output .= $Self->{LayoutObject}->Footer( Type => 'Small' );
        }
        else {
            $Output .= $Self->{LayoutObject}->Footer();
        }

        return $Output;
    }

    # ------------------------------------------------------------ #
    # add action
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'AddAction' ) {
        my $Note = '';
        my ( %GetParam, %Errors );

        my $AutoLoginCreation = $Self->{ConfigObject}->Get($Source)->{AutoLoginCreation};

        ENTRY:
        for my $Entry ( @{ $Self->{ConfigObject}->Get($Source)->{Map} } ) {
            $GetParam{ $Entry->[0] } = $Self->{ParamObject}->GetParam( Param => $Entry->[0] ) || '';

            # don't validate UserLogin if AutoLoginCreation is configured
            next ENTRY if ( $AutoLoginCreation && $Entry->[0] eq 'UserLogin' );

            # check mandatory fields
            if ( !$GetParam{ $Entry->[0] } && $Entry->[4] ) {
                $Errors{ $Entry->[0] . 'Invalid' } = 'ServerError';
            }
        }

        # check email address
        if (
            $GetParam{UserEmail}
            && !$CheckItemObject->CheckEmail( Address => $GetParam{UserEmail} )
            )
        {
            $Errors{UserEmailInvalid} = 'ServerError';
            $Errors{ErrorType}        = $CheckItemObject->CheckErrorType() . 'ServerErrorMsg';
        }

        # if no errors occurred
        if ( !%Errors ) {

            # add user
            my $User = $Self->{CustomerUserObject}->CustomerUserAdd(
                %GetParam,
                UserID => $Self->{UserID},
                Source => $Source
            );
            if ($User) {

                # update preferences
                my %Preferences = %{ $Self->{ConfigObject}->Get('CustomerPreferencesGroups') };
                for my $Group ( keys %Preferences ) {
                    next if $Group eq 'Password';

                    # get user data
                    my %UserData = $Self->{CustomerUserObject}->CustomerUserDataGet(
                        User => $GetParam{UserLogin}
                    );
                    my $Module = $Preferences{$Group}->{Module};
                    if ( !$Self->{MainObject}->Require($Module) ) {
                        return $Self->{LayoutObject}->FatalError();
                    }
                    my $Object = $Module->new(
                        %{$Self},
                        ConfigItem => $Preferences{$Group},
                        UserObject => $Self->{CustomerUserObject},
                        Debug      => $Self->{Debug},
                    );
                    my @Params
                        = $Object->Param( %{ $Preferences{$Group} }, UserData => \%UserData );
                    if (@Params) {
                        my %GetParam;
                        for my $ParamItem (@Params) {
                            my @Array
                                = $Self->{ParamObject}->GetArray( Param => $ParamItem->{Name} );
                            $GetParam{ $ParamItem->{Name} } = \@Array;
                        }
                        if ( !$Object->Run( GetParam => \%GetParam, UserData => \%UserData ) ) {
                            $Note .= $Self->{LayoutObject}->Notify( Info => $Object->Error() );
                        }
                    }
                }

                # get user data and show screen again
                if ( !$Note ) {

                    # in borrowed view, take the new created customer over into the new ticket
                    if ( $Nav eq 'None' ) {
                        my $Output = $NavBar;

                        $Self->{LayoutObject}->Block(
                            Name => 'BorrowedViewSubmitJS',
                            Data => {
                                Customer => $User,
                            },
                        );

                        $Output .= $Self->{LayoutObject}->Output(
                            TemplateFile => 'AdminCustomerUser',
                            Data         => \%Param,
                        );

                        $Output .= $Self->{LayoutObject}->Footer( Type => 'Small' );

                        return $Output;
                    }

                    $Self->_Overview(
                        Nav    => $Nav,
                        Search => $Search,
                    );

                    my $Output        = $NavBar . $Note;
                    my $URL           = '';
                    my $UserHTMLQuote = $Self->{LayoutObject}->LinkEncode($User);
                    my $UserQuote     = $Self->{LayoutObject}->Ascii2Html( Text => $User );
                    if ( $Self->{ConfigObject}->Get('Frontend::Module')->{AgentTicketPhone} ) {
                        $URL
                            .= "<a href=\"\$Env{\"CGIHandle\"}?Action=AgentTicketPhone;Subaction=StoreNew;ExpandCustomerName=2;CustomerUser=$UserHTMLQuote\">"
                            . $Self->{LayoutObject}->{LanguageObject}->Get('New phone ticket')
                            . "</a>";
                    }
                    if ( $Self->{ConfigObject}->Get('Frontend::Module')->{AgentTicketEmail} ) {
                        if ($URL) {
                            $URL .= " - ";
                        }
                        $URL
                            .= "<a href=\"\$Env{\"CGIHandle\"}?Action=AgentTicketEmail;Subaction=StoreNew;ExpandCustomerName=2;CustomerUser=$UserHTMLQuote\">"
                            . $Self->{LayoutObject}->{LanguageObject}->Get('New email ticket')
                            . "</a>";
                    }
                    if ($URL) {
                        $Output
                            .= $Self->{LayoutObject}->Notify(
                            Data => $Self->{LayoutObject}->{LanguageObject}->Get(
                                'Customer %s added", "' . $UserQuote
                                )
                                . " ( $URL )!",
                            );
                    }
                    else {
                        $Output
                            .= $Self->{LayoutObject}->Notify(
                            Data => $Self->{LayoutObject}->{LanguageObject}->Get(
                                'Customer %s added", "' . $UserQuote
                                )
                                . "!",
                            );
                    }
                    $Output .= $Self->{LayoutObject}->Output(
                        TemplateFile => 'AdminCustomerUser',
                        Data         => \%Param,
                    );

                    if ( $Nav eq 'None' ) {
                        $Output .= $Self->{LayoutObject}->Footer( Type => 'Small' );
                    }
                    else {
                        $Output .= $Self->{LayoutObject}->Footer();
                    }

                    return $Output;
                }
            }
            else {
                $Note .= $Self->{LayoutObject}->Notify( Priority => 'Error' );
            }
        }

        # something has gone wrong
        my $Output = $NavBar . $Note;
        $Output .= $Self->_Edit(
            Nav    => $Nav,
            Action => 'Add',
            Source => $Source,
            Search => $Search,
            Errors => \%Errors,
            %GetParam,
        );

        if ( $Nav eq 'None' ) {
            $Output .= $Self->{LayoutObject}->Footer( Type => 'Small' );
        }
        else {
            $Output .= $Self->{LayoutObject}->Footer();
        }

        return $Output;
    }

    # ------------------------------------------------------------ #
    # overview
    # ------------------------------------------------------------ #
    else {
        $Self->_Overview(
            Nav    => $Nav,
            Search => $Search,
        );
        my $Output = $NavBar;
        $Output .= $Self->{LayoutObject}->Output(
            TemplateFile => 'AdminCustomerUser',
            Data         => \%Param,
        );

        if ( $Nav eq 'None' ) {
            $Output .= $Self->{LayoutObject}->Footer( Type => 'Small' );
        }
        else {
            $Output .= $Self->{LayoutObject}->Footer();
        }

        return $Output;
    }
}

sub _Overview {
    my ( $Self, %Param ) = @_;

    # build source string
    $Param{SourceOption} = $Self->{LayoutObject}->BuildSelection(
        Data       => { $Self->{CustomerUserObject}->CustomerSourceList() },
        Name       => 'Source',
        SelectedID => $Param{Source} || '',
    );

    $Self->{LayoutObject}->Block(
        Name => 'Overview',
        Data => \%Param,
    );

    $Self->{LayoutObject}->Block( Name => 'ActionList' );
    $Self->{LayoutObject}->Block(
        Name => 'ActionSearch',
        Data => \%Param,
    );
    $Self->{LayoutObject}->Block(
        Name => 'ActionAdd',
        Data => \%Param,
    );

    $Self->{LayoutObject}->Block(
        Name => 'OverviewHeader',
        Data => {},
    );

    if ( $Param{Search} ) {
        my %List = $Self->{CustomerUserObject}->CustomerSearch(
            Search => $Param{Search},
            Valid  => 0,
        );
        $Self->{LayoutObject}->Block(
            Name => 'OverviewResult',
            Data => \%Param,
        );

        # if there are results to show
        if (%List) {

            # get valid list
            my %ValidList = $Self->{ValidObject}->ValidList();
            for my $ListKey ( sort { lc($a) cmp lc($b) } keys %List ) {

                my %UserData = $Self->{CustomerUserObject}->CustomerUserDataGet( User => $ListKey );
                $Self->{LayoutObject}->Block(
                    Name => 'OverviewResultRow',
                    Data => {
                        Valid => $ValidList{ $UserData{ValidID} || '' } || '-',
                        Search => $Param{Search},
                        %UserData,
                    },
                );
                if ( $Param{Nav} eq 'None' ) {
                    $Self->{LayoutObject}->Block(
                        Name => 'OverviewResultRowLinkNone',
                        Data => {
                            Search => $Param{Search},
                            %UserData,
                        },
                    );
                }
                else {
                    $Self->{LayoutObject}->Block(
                        Name => 'OverviewResultRowLink',
                        Data => {
                            Search => $Param{Search},
                            Nav    => $Param{Nav},
                            %UserData,
                        },
                    );
                }
            }
        }

        # otherwise it displays a no data found message
        else {
            $Self->{LayoutObject}->Block(
                Name => 'NoDataFoundMsg',
                Data => {},
            );
        }
    }

    # if there is nothing to search it shows a message
    else
    {
        $Self->{LayoutObject}->Block(
            Name => 'NoSearchTerms',
            Data => {},
        );
    }

    if ( $Param{Nav} eq 'None' ) {
        $Self->{LayoutObject}->Block( Name => 'BorrowedViewJS' );
    }
}

sub _Edit {
    my ( $Self, %Param ) = @_;

    my $Output = '';

    $Self->{LayoutObject}->Block(
        Name => 'Overview',
        Data => \%Param,
    );

    $Self->{LayoutObject}->Block( Name => 'ActionList' );
    $Self->{LayoutObject}->Block(
        Name => 'ActionOverview',
        Data => \%Param,
    );

    $Self->{LayoutObject}->Block(
        Name => 'OverviewUpdate',
        Data => \%Param,
    );

    # shows header
    if ( $Param{Action} eq 'Change' ) {
        $Self->{LayoutObject}->Block( Name => 'HeaderEdit' );
    }
    else {
        $Self->{LayoutObject}->Block( Name => 'HeaderAdd' );
    }

    for my $Entry ( @{ $Self->{ConfigObject}->Get( $Param{Source} )->{Map} } ) {
        next if !$Entry->[0];

        my $Block = 'Input';

        # check input type
        if ( $Entry->[0] =~ /^UserPasswor/i ) {
            $Block = 'Password';
        }

        # check if login auto creation
        if (
            $Self->{ConfigObject}->Get( $Param{Source} )->{AutoLoginCreation}
            && $Entry->[0] eq 'UserLogin'
            )
        {
            $Block = 'InputHidden';
        }
        if ( $Entry->[7] ) {
            $Param{ReadOnlyType} = 'readonly';
            $Param{ReadOnly}     = '*';
        }
        else {
            $Param{ReadOnlyType} = '';
            $Param{ReadOnly}     = '';
        }

        # show required flag
        if ( $Entry->[4] ) {
            $Param{RequiredClass}          = 'Validate_Required';
            $Param{RequiredLabelClass}     = 'Mandatory';
            $Param{RequiredLabelCharacter} = '*';
        }
        else {
            $Param{RequiredClass}          = '';
            $Param{RequiredLabelClass}     = '';
            $Param{RequiredLabelCharacter} = '';
        }

        # add class to validate emails
        if ( $Entry->[0] eq 'UserEmail' ) {
            $Param{RequiredClass} .= ' Validate_Email';
        }

        # build selections or input fields
        if ( $Self->{ConfigObject}->Get( $Param{Source} )->{Selections}->{ $Entry->[0] } ) {
            $Block = 'Option';

            # Change the validation class
            if ( $Param{RequiredClass} ) {
                $Param{RequiredClass} = 'Validate_Required';
            }

            # get the data of the current selection
            my $SelectionsData
                = $Self->{ConfigObject}->Get( $Param{Source} )->{Selections}->{ $Entry->[0] };

            # make sure the encoding stamp is set
            for my $Key ( keys %{$SelectionsData} ) {
                $SelectionsData->{$Key} = $Self->{EncodeObject}->Encode( $SelectionsData->{$Key} );
            }

            $Param{Option} = $Self->{LayoutObject}->BuildSelection(
                Data        => $SelectionsData,
                Name        => $Entry->[0],
                Translation => 0,
                SelectedID  => $Param{ $Entry->[0] },
                Class => $Param{RequiredClass} . ' ' . $Param{Errors}->{ $Entry->[0] . 'Invalid' }
                    || '',
            );

        }
        elsif ( $Entry->[0] =~ /^ValidID/i ) {

            # Change the validation class
            if ( $Param{RequiredClass} ) {
                $Param{RequiredClass} = 'Validate_Required';
            }

            # build ValidID string
            $Block = 'Option';
            $Param{Option} = $Self->{LayoutObject}->BuildSelection(
                Data       => { $Self->{ValidObject}->ValidList(), },
                Name       => $Entry->[0],
                SelectedID => defined( $Param{ $Entry->[0] } ) ? $Param{ $Entry->[0] } : 1,
                Class => $Param{RequiredClass} || ''
                    . ' ' . $Param{Errors}->{ $Entry->[0] . 'Invalid' } || '',
            );
        }
        elsif (
            $Entry->[0] =~ /^UserCustomerID$/i
            && $Self->{ConfigObject}->Get( $Param{Source} )->{CustomerCompanySupport}
            )
        {
            my %CompanyList = (
                $Self->{CustomerCompanyObject}->CustomerCompanyList(),
                '' => '-',
            );
            if ( $Param{ $Entry->[0] } ) {
                my %Company = $Self->{CustomerCompanyObject}->CustomerCompanyGet(
                    CustomerID => $Param{ $Entry->[0] },
                );
                if ( !%Company ) {
                    $CompanyList{ $Param{ $Entry->[0] } } = $Param{ $Entry->[0] } . ' (-)';
                }
            }
            $Block = 'Option';

            # Change the validation class
            if ( $Param{RequiredClass} ) {
                $Param{RequiredClass} = 'Validate_Required';
            }
            $Param{Option} = $Self->{LayoutObject}->BuildSelection(
                Data       => \%CompanyList,
                Name       => $Entry->[0],
                Max        => 80,
                SelectedID => $Param{ $Entry->[0] },
                Class      => $Param{RequiredClass} . ' '
                    . ( $Param{Errors}->{ $Entry->[0] . 'Invalid' } || '' ),
            );
        }
        else {
            $Param{Value} = $Param{ $Entry->[0] } || '';
        }

        # add form option
        if ( $Param{Type} && $Param{Type} eq 'hidden' ) {
            $Param{Preferences} .= $Param{Value};
        }
        else {
            $Self->{LayoutObject}->Block(
                Name => 'PreferencesGeneric',
                Data => { Item => $Entry->[1], %Param },
            );
            $Self->{LayoutObject}->Block(
                Name => "PreferencesGeneric$Block",
                Data => {
                    Item         => $Entry->[1],
                    Name         => $Entry->[0],
                    InvalidField => $Param{Errors}->{ $Entry->[0] . 'Invalid' } || '',
                    %Param,
                },
            );

            # add the correct client side error msg
            if ( $Block eq 'Input' && $Entry->[0] eq 'UserEmail' ) {
                $Self->{LayoutObject}->Block(
                    Name => 'PreferencesUserEmailErrorMsg',
                    Data => { Name => $Entry->[0] },
                );
            }
            else {
                $Self->{LayoutObject}->Block(
                    Name => "PreferencesGenericErrorMsg",
                    Data => { Name => $Entry->[0] },
                );
            }

            # add the correct server error msg
            if ( $Block eq 'Input' && $Param{UserEmail} && $Entry->[0] eq 'UserEmail' ) {

                # display server error msg according with the occurred email error type
                $Self->{LayoutObject}->Block(
                    Name => 'PreferencesUserEmail' . ( $Param{Errors}->{ErrorType} || '' ),
                    Data => { Name => $Entry->[0] },
                );
            }
            else {
                $Self->{LayoutObject}->Block(
                    Name => "PreferencesGenericServerErrorMsg",
                    Data => { Name => $Entry->[0] },
                );
            }
        }
    }
    my $PreferencesUsed = $Self->{ConfigObject}->Get( $Param{Source} )->{AdminSetPreferences};
    if ( ( defined $PreferencesUsed && $PreferencesUsed != 0 ) || !defined $PreferencesUsed ) {
        my @Groups = @{ $Self->{ConfigObject}->Get('CustomerPreferencesView') };
        for my $Column (@Groups) {
            my %Data;
            my %Preferences = %{ $Self->{ConfigObject}->Get('CustomerPreferencesGroups') };
            for my $Group ( keys %Preferences ) {
                if ( $Preferences{$Group}->{Column} eq $Column ) {
                    if ( $Data{ $Preferences{$Group}->{Prio} } ) {
                        for ( 1 .. 151 ) {
                            $Preferences{$Group}->{Prio}++;
                            if ( !$Data{ $Preferences{$Group}->{Prio} } ) {
                                $Data{ $Preferences{$Group}->{Prio} } = $Group;
                                last;
                            }
                        }
                    }
                    $Data{ $Preferences{$Group}->{Prio} } = $Group;
                }
            }

            # sort
            for my $Key ( keys %Data ) {
                $Data{ sprintf( "%07d", $Key ) } = $Data{$Key};
                delete $Data{$Key};
            }

            # show each preferences setting
            for my $Prio ( sort keys %Data ) {
                my $Group = $Data{$Prio};
                if ( !$Self->{ConfigObject}->{CustomerPreferencesGroups}->{$Group} ) {
                    next;
                }
                my %Preference = %{ $Self->{ConfigObject}->{CustomerPreferencesGroups}->{$Group} };
                if ( $Group eq 'Password' ) {
                    next;
                }
                my $Module = $Preference{Module}
                    || 'Kernel::Output::HTML::CustomerPreferencesGeneric';

                # load module
                if ( $Self->{MainObject}->Require($Module) ) {
                    my $Object = $Module->new(
                        %{$Self},
                        ConfigItem => \%Preference,
                        UserObject => $Self->{CustomerUserObject},
                        Debug      => $Self->{Debug},
                    );
                    my @Params = $Object->Param( UserData => \%Param );
                    if (@Params) {
                        for my $ParamItem (@Params) {
                            $Self->{LayoutObject}->Block(
                                Name => 'Item',
                                Data => {%Param},
                            );
                            if (
                                ref $ParamItem->{Data}   eq 'HASH'
                                || ref $Preference{Data} eq 'HASH'
                                )
                            {
                                $ParamItem->{Option} = $Self->{LayoutObject}->BuildSelection(
                                    %Preference, %{$ParamItem},
                                );
                            }
                            $Self->{LayoutObject}->Block(
                                Name => $ParamItem->{Block} || $Preference{Block} || 'Option',
                                Data => {
                                    Group => $Group,
                                    %Param,
                                    %Data,
                                    %Preference,
                                    %{$ParamItem},
                                },
                            );
                        }
                    }
                }
                else {
                    return $Self->{LayoutObject}->FatalError();
                }
            }
        }

    }

    if ( $Param{Nav} eq 'None' ) {
        $Self->{LayoutObject}->Block( Name => 'BorrowedViewJS' );
    }

    return $Self->{LayoutObject}->Output(
        TemplateFile => 'AdminCustomerUser',
        Data         => \%Param
    );
}

1;
