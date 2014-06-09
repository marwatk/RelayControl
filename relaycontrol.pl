#!/usr/bin/perl

use strict;
use warnings;

use RelayControl;
#Examples:

#relaycontrol.pl 
#Prints out current state

#relaycontrol.pl all:on
#Turns on all relays

#relaycontrol.pl all:off
#Turns off all relays

#relaycontrol.pl 1:on 3:on 5:off
#Turns on 1 and 3, turns off 5, leaves others along

my @ARGS = @ARGV;

my $rc = RelayControl->new( '/dev/hidraw0' );

my $initial = $rc->getAllRelayStates();

my $target = {};

if( scalar( @ARGS ) > 0 ) {
    foreach my $arg ( @ARGV ) {
        $arg = lc( $arg );
        if( $arg =~ /(all|\d+):(off|on)/ ) {
            my $num = $1;
            if( $num eq 'all' ) {
                for( my $i = 1; $i <= 16; $i++ ) {
                    $target->{$i} = $on ? '1' : '0';
                }
            }
            else {
                $target->{$num} = $on ? '1' : '0';
            }
        }
        else {
            print "Invalid argument: $arg\n";
            exit( 1 );
        }
    }
    $rc->setRelayStates( $target );
    my $result = $rc->getAllRelayStates();
    
    print "Relay   Initial Target  Result\n";
    foreach my $relay ( sort { $a <=> $b } keys %$initial ) {
        my $initial = $initial->{$relay} ? 'on' : 'off';
        my $target = defined( $target->{$relay} ) ? ( $target->{$relay} ? 'on' : 'off' ) : '***';
        my $result = $result->{$relay} ? 'on' : 'off';
        printf( "%-8s%-8s%-8s%-8s\n", $relay, $initial, $target, $result );
    }
    
}
else {
    print "Current state:\n";
    foreach my $relay ( sort { $a cmp $b } keys %$initial ) {
        print "$relay: ", $states->{$relay} ? 'on' : 'off', "\n";
    }
}

exit( 0 );


