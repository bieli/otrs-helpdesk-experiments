# --
# scripts/test/LayoutTicket.t - layout module testscript
# Copyright (C) 2001-2011 OTRS AG, http://otrs.org/
# --
# $Id: LayoutTicket.t,v 1.4.2.2 2011/11/17 11:32:16 mg Exp $
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;
use vars (qw($Self %Param));

use Kernel::System::AuthSession;
use Kernel::System::Web::Request;
use Kernel::System::Web::UploadCache;
use Kernel::System::Group;
use Kernel::System::Ticket;
use Kernel::System::User;
use Kernel::Output::HTML::Layout;

# create local objects
my $SessionObject = Kernel::System::AuthSession->new( %{$Self} );
my $GroupObject   = Kernel::System::Group->new( %{$Self} );
my $UserObject    = Kernel::System::User->new( %{$Self} );
my $TicketObject  = Kernel::System::Ticket->new( %{$Self} );
my $ParamObject   = Kernel::System::Web::Request->new(
    %{$Self},
    WebRequest => $Param{WebRequest} || 0,
);
my $UploadCacheObject = Kernel::System::Web::UploadCache->new( %{$Self} );
my $FormID            = $UploadCacheObject->FormIDCreate();
my $LayoutObject      = Kernel::Output::HTML::Layout->new(
    ConfigObject       => $Self->{ConfigObject},
    LogObject          => $Self->{LogObject},
    TimeObject         => $Self->{TimeObject},
    MainObject         => $Self->{MainObject},
    EncodeObject       => $Self->{EncodeObject},
    SessionObject      => $SessionObject,
    DBObject           => $Self->{DBObject},
    ParamObject        => $ParamObject,
    TicketObject       => $TicketObject,
    UserObject         => $UserObject,
    GroupObject        => $GroupObject,
    UserChallengeToken => 'TestToken',
    UserID             => 1,
    Lang               => 'de',
    SessionID          => 123,
);

# create test data
my $TicketID = $TicketObject->TicketCreate(
    Title        => 'Some Ticket Title',
    Queue        => 'Raw',
    Lock         => 'unlock',
    Priority     => '3 normal',
    State        => 'closed successful',
    CustomerNo   => '123465',
    CustomerUser => 'customer@example.com',
    OwnerID      => 1,
    UserID       => 1,
);
$Self->True(
    $TicketID,
    'TicketCreate()',
);

# add html
my $HTML = '<html>
<head>
<title>Test</title>
</head>
<body>
<b>Test HTML document.</b>
<img src="cid:1234" border="0">
<img src="Untitled%20Attachment" border="0">
Special case from Lotus Notes:
<img src=cid:_1_09B1841409B1651C003EDE23C325785D border="0">
</body>
</html>';

my $ArticleID = $TicketObject->ArticleCreate(
    TicketID       => $TicketID,
    ArticleType    => 'note-internal',
    SenderType     => 'agent',
    From           => 'Some Agent <email@example.com>',
    To             => 'Some Customer <customer@example.com>',
    Subject        => 'Fax Agreement laalala',
    Body           => $HTML,
    ContentType    => 'text/html; charset=ISO-8859-15',
    HistoryType    => 'OwnerUpdate',
    HistoryComment => 'Some free text!',
    UserID         => 1,
    NoAgentNotify => 1,    # if you don't want to send agent notifications
);

$TicketObject->ArticleWriteAttachment(
    Filename    => 'image.png',
    MimeType    => 'image/png',
    ContentType => 'image/png',
    Content     => '#fake image#',
    ContentID   => '1234',
    ArticleID   => $ArticleID,
    UserID      => 1,
);

$TicketObject->ArticleWriteAttachment(
    Filename    => 'image2.png',
    MimeType    => 'image/png',
    ContentType => 'image/png',
    Content     => '#fake image2#',
    ArticleID   => $ArticleID,
    UserID      => 1,
);
$TicketObject->ArticleWriteAttachment(
    Filename    => 'image3.png',
    MimeType    => 'image/png',
    ContentType => 'image/png',
    Content     => '#fake image3#',
    ArticleID   => $ArticleID,
    UserID      => 1,
);

$TicketObject->ArticleWriteAttachment(
    Filename    => 'image4.png',
    MimeType    => 'image/png',
    ContentType => 'image/png',
    Content     => '#fake image3#',
    ContentID   => '_1_09B1841409B1651C003EDE23C325785D',
    ArticleID   => $ArticleID,
    UserID      => 1,
);

$TicketObject->ArticleWriteAttachment(
    Filename    => 'image.bmp',
    MimeType    => 'image/bmp',
    ContentType => 'image/bmp',
    Content     => '#fake image#',
    ContentID   => 'Untitled%20Attachment',
    ArticleID   => $ArticleID,
    UserID      => 1,
);

# defined tests
my @Tests = (
    {
        Config => {
            'Frontend::RichText' => 1,
        },
        BodyRegExp => [
            '<b>Test HTML document.<\/b>',
            '<img src="[^;]+?Action=PictureUpload;FormID=[0-9.]+;SessionID=123;ContentID=1234" border="0">',
        ],
        AttachmentsInclude => 1,
        Attachment         => {
            'image.png'  => 1,
            'image2.png' => 1,
            'image3.png' => 1,
            }
    },
    {
        Config => {
            'Frontend::RichText' => 1,
        },
        BodyRegExp => [
            '<b>Test HTML document.<\/b>',
            '<img src="[^;]+?Action=PictureUpload;FormID=[0-9.]+;SessionID=123;ContentID=_1_09B1841409B1651C003EDE23C325785D" border="0">',
        ],
        AttachmentsInclude => 1,
        Attachment         => {
            'image4.png' => 1,
            }
    },
    {
        Config => {
            'Frontend::RichText' => 1,
        },
        BodyRegExp => [
            '<b>Test HTML document.<\/b>',
            '<img src="[^;]+?Action=PictureUpload;FormID=[0-9.]+;SessionID=123;ContentID=1234" border="0">',
        ],
        AttachmentsInclude => 0,
        Attachment         => {
            'image.png' => 1,
            }
    },
    {
        Config => {
            'Frontend::RichText' => 0,
        },
        BodyRegExp => [
            'Test HTML document.'
        ],
        AttachmentsInclude => 1,
        Attachment         => {
            'file-2'     => 1,
            'image.png'  => 1,
            'image.png'  => 1,
            'image2.png' => 1,
            'image3.png' => 1,
        },
    },
    {
        Config => {
            'Frontend::RichText' => 0,
        },
        BodyRegExp => [
            'Test HTML document.'
        ],
        AttachmentsInclude => 0,
        Attachment         => {
            'file-2' => 1,
        },
    },
    {
        Config => {
            'Frontend::RichText' => 1,
        },
        BodyRegExp => [
            '<img src="[^;]+?Action=PictureUpload;FormID=[0-9.]+;SessionID=123;ContentID=Untitled%2520Attachment" border="0">',
        ],
        AttachmentsInclude => 0,
        Attachment         => {
            'image.bmp' => 1,
        },
    },
);

# execute tests
for my $Test (@Tests) {

    # set config settings
    for my $Key ( sort keys %{ $Test->{Config} } ) {
        $Self->{ConfigObject}->Set(
            Key   => $Key,
            Value => $Test->{Config}->{$Key},
        );
    }

    # quote article
    my $HTMLBody = $LayoutObject->ArticleQuote(
        TicketID           => $TicketID,
        ArticleID          => $ArticleID,
        FormID             => $FormID,
        UploadCacheObject  => $UploadCacheObject,
        AttachmentsInclude => $Test->{AttachmentsInclude},
    );

    # check body
    for my $RegExp ( @{ $Test->{BodyRegExp} } ) {
        if ( $HTMLBody =~ /$RegExp/ ) {
            $Self->True(
                1,
                "BodyRegExp - $RegExp",
            );
        }
        else {
            $Self->True(
                0,
                "BodyRegExp - $RegExp",
            );
        }
    }

    # check attachments
    my @Attachments = $UploadCacheObject->FormIDGetAllFilesMeta(
        FormID => $FormID,
    );
    ATTACHMENT:
    for my $Filename ( sort keys %{ $Test->{Attachment} } ) {
        next if !$Test->{Attachment}->{$Filename};
        for my $Attachment (@Attachments) {
            if ( $Attachment->{Filename} eq $Filename ) {
                $Self->True(
                    1,
                    "Attachment is included as expected - $Filename",
                );
                next ATTACHMENT;
            }
        }
        $Self->True(
            0,
            "Attachment is not included as expected - $Filename",
        );
    }
}

# cleanup
$Self->True(
    $TicketObject->TicketDelete(
        TicketID => $TicketID,
        UserID   => 1,
    ),
    "TicketDelete()",
);

1;
