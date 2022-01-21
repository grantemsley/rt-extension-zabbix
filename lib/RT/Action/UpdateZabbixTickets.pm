package RT::Action::UpdateZabbixTickets;

use strict;
use warnings;
use Data::Dumper;

use base qw(RT::Action);

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
    my $body = $self->TransactionObj->Content;
    return unless $subject;

    if ((my($type, $trigger) = $subject =~ m{(OK): (.*)}i) && (my ($host) = $body =~ m{Host: (.*)}i)) {
        $RT::Logger->info("Found a recovery message, extracted type, trigger and host with values $type, $trigger, $host");

		# Search for tickets
		my $tickets = RT::Tickets->new( $self->CurrentUser );
        $tickets->LimitQueue( VALUE => $new_ticket->Queue )
          unless RT->Config->Get('ZabbixSearchAllQueues');

		# Limit to tickets with this trigger
		$tickets->LimitSubject(
			VALUE => "PROBLEM: " . $trigger,
			OPERATOR => '='
		);
		$tickets->LimitSubject(
			VALUE => "OK: " . $trigger,
			OPERATOR => '='
		);

		# And limit to active tickets
        my @active = RT::Queue->ActiveStatusArray();
        for my $active (@active) {
            $tickets->LimitStatus(
                VALUE    => $active,
                OPERATOR => '=',
            );
        }

        my $resolved = RT->Config->Get('ZabbixResolvedStatus') || 'resolved';

        if ( my $merge_type = RT->Config->Get('ZabbixMergeTickets') ) {
            my $merged_ticket;

            $tickets->OrderBy(
                FIELD => 'Created',
                ORDER => $merge_type > 0 ? 'DESC' : 'ASC',
            );
            $merged_ticket = $tickets->Next;

            while ( my $ticket = $tickets->Next ) {
				$RT::Logger->info("Merging " . $ticket->id . " into " . $merged_ticket->id);
                my ( $ret, $msg ) = $ticket->MergeInto( $merged_ticket->id );
                if ( !$ret ) {
                    $RT::Logger->error( 'failed to merge ticket '
                          . $ticket->id
                          . " into "
                          . $merged_ticket->id
                          . ": $msg" );
                }
            }

            if ( not $merged_ticket or not $merged_ticket->id ) {
                $RT::Logger->error( "Recovery ticket with no initial ticket: $subject" );
                $merged_ticket = $new_ticket;
            }
            my ( $ret, $msg ) = $merged_ticket->SetStatus($resolved);
            if ( !$ret ) {
                $RT::Logger->error( 'failed to resolve ticket '
                      . $merged_ticket->id
                      . ":$msg" );
            }
        }
        else {
            while ( my $ticket = $tickets->Next ) {
                my ( $ret, $msg ) = $ticket->Comment(
                    Content => 'going to be resolved by ' . $new_ticket_id,
                    Status  => $resolved,
                );
                if ( !$ret ) {
                    $RT::Logger->error(
                        'failed to comment ticket ' . $ticket->id . ": $msg" );
                }

                ( $ret, $msg ) = $ticket->SetStatus($resolved);
                if ( !$ret ) {
                    $RT::Logger->error(
                        'failed to resolve ticket ' . $ticket->id . ": $msg" );
                }
            }
            my ( $ret, $msg ) = $new_ticket->SetStatus($resolved);
            if ( !$ret ) {
                $RT::Logger->error(
                    'failed to resolve ticket ' . $new_ticket->id . ":$msg" );
            }
        }
    }
}

1;

