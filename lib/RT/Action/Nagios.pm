package RT::Action::Nagios;
require RT::Action::Generic;

use strict;
use warnings;

use base qw(RT::Action::Generic);

sub Describe {
    my $self = shift;
    return ( ref $self );
}

sub Prepare {
    return (1);
}

sub Commit {
    my $self = shift;

    my $attachment = $self->TransactionObj->Attachments->First;
    return 1 unless $attachment;
    my $new_ticket    = $self->TicketObj;
    my $new_ticket_id = $new_ticket->id;

    my $subject = $attachment->GetHeader('Subject');
    return unless $subject;
    if (
        my ( $key, $category, $host, $type, $info ) =
        $subject =~ m{(PROBLEM|RECOVERY) \s+ (Service|Host) \s+ Alert:
            \s+([^/]+)/(.*)\s+is\s+(\w+)}ix
      )
    {
        $RT::Logger->error( $1, $2, $3, $4, $5 );
        my $tickets = RT::Tickets->new( $self->CurrentUser );
        $tickets->LimitQueue( VALUE => $new_ticket->Queue );
        $tickets->LimitStatus(
            VALUE           => 'new',
            OPERATOR        => '=',
            ENTRYAGGREGATOR => 'or'
        );
        $tickets->LimitStatus(
            VALUE           => 'open',
            OPERATOR        => '=',
            ENTRYAGGREGATOR => 'or'
        );
        $tickets->LimitStatus( VALUE => 'stalled', OPERATOR => '=' );

        while ( my $ticket = $tickets->Next ) {
            next if $ticket->id == $new_ticket_id;
            if ( $ticket->Subject =~ m{$category\s+Alert:\s+$host/$type}i ) {
                my ( $ret, $msg ) = $ticket->MergeInto($new_ticket_id);
                if ( !$ret ) {
                    $RT::Logger->error( 'failed to merge ticket '
                          . $ticket->id
                          . " into $new_ticket_id:$msg" );
                }

            }
        }

        if ( $key eq 'RECOVERY' ) {
            my ( $ret, $msg ) = $new_ticket->Resolve();
            if ( !$ret ) {
                $RT::Logger->error(
                    'failed to resolve ticket ' . $new_ticket->id . ":$msg" );
            }
        }

    }
}

1;