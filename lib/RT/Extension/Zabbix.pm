use warnings;
use strict;

package RT::Extension::Zabbix;

=head1 NAME

RT::Extension::Zabbix - Merge and resolve Zabbix tickets

=cut

our $VERSION = '1.00';

1;

=head1 DESCRIPTION

Zabbix is a monitoring system.  It's email alerts can be piped to request tracker. This extension automatically merges and resolves issues when it receives the OK alert.

=head1 ZABBIX SETUP

Notifications need to be setup to go from zabbix to your request tracker queue.

The emails from Zabbix must have the default subject line of:
 {TRIGGER.STATUS}: {TRIGGER.NAME}

If the subject line is changed, this extension won't be able to match them.

The body of the email must also contain:
 Host: {HOST.NAME}

The combination of {TRIGGER.NAME} in the subject and {HOST.NAME} in the body will be used to uniquely identify the alerts.

=head1 REQUEST TRACKER CONFIGURATION

After the new ticket is created, the following is done:

1. find all the other active tickets in the same queue( unless
C<<< RT->Config->Get('ZabbixSearchAllQueues') >>> is true, which will cause
to search all the queues ) with the same values of $triggerstatus and $host.

2. if C<< RT->Config->Get('ZabbixMergeTickets') >> is true, merge all of
them. if $triggerstatus is 'OK', resolve the merged ticket.

if C<< RT->Config->Get('ZabbixMergeTickets') >> is false and $triggerstatus is
'OK', resolve all them.

NOTE:

config items like C<ZabbixSearchAllQueues> and C<ZabbixMergeTickets> can be set
in etc/RT_SiteConfig.pm like this:

    Set($ZabbixSearchAllQueues, 1); # true
    Set($ZabbixMergeTickets, 0); # false, don't merge
    Set($ZabbixMergeTickets, 1); # merge into the newest ticket.
    Set($ZabbixMergeTickets, -1); # merge into the oldest ticket.

by default, tickets will be resolved with status C<resolved>, you can
customize this via config item C<ZabbixResolvedStatus>, e.g.

    Set($ZabbixResolvedStatus, "recovered");

=head1 AUTHOR

Grant Emsley  C<< <grant@emsley.ca> >>

=head1 LICENCE AND COPYRIGHT

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

