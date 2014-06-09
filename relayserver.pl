#!/usr/bin/perl

package RelayServer;

use strict;
use warnings;

use RelayControl;
use HTTP::Server::Simple::CGI;
use base qw(HTTP::Server::Simple::CGI);

my $FAIL_SAFE_TIME = 600; #10 Minutes
my $FAIL_SAFE_INTERVAL = 10;

my $rc = RelayControl->new( '/dev/hidraw0' );

my $killTimes = {};
my $reqCount = 0;


sub handle_request {
    my $self = shift;
    my $cgi = shift;
    
    
    my $target = {};
    my $haveValues = 0;
    my @params = $cgi->param();
    for( my $i = 1; $i <= 16; $i++ ) {
        my $val = $cgi->param( $i );
        if( defined( $val ) ) {
            $val = lc( $val );
            if( $val eq 'on' ) {
                $target->{$i} = '1';
                $haveValues = 1;
                my $inTimeVal = $cgi->param( $i . "time" ) || 0;
                my $killTime = int( $inTimeVal ) || $FAIL_SAFE_TIME;
                $killTimes->{$i} = time + $killTime;
            }
            elsif( $val eq 'off' ) {
                $target->{$i} = '0';
                $haveValues = 1;
                $killTimes->{$i} = 0;
            }
        }
    }
    if( $haveValues ) {
        $rc->setRelayStates( $target );
    }
    my $result = $rc->getAllRelayStates();
    print "HTTP/1.0 200 OK\n";
    print "Content-type: application/json\n\n";
    print "{\n";
    my @lines;
    for( my $i = 1; $i <= 16; $i++ ) {
        push( @lines, " \"$i\":" . ( $result->{$i} ? '"on"' : '"off"' ) );
    }
    
    print join( ",\n", @lines );
    print "\n}\n";
}

sub after_setup_listener {
    $SIG{ALRM} = sub { failsafe(); alarm( $FAIL_SAFE_INTERVAL ); };
    alarm( $FAIL_SAFE_INTERVAL );
}

sub failsafe {
    if( !$rc->isLocked() ) { #Don't interrupt an in progress switch
        my $states = $rc->getAllRelayStates();
        my $now = time;
        for( my $i = 1; $i <= 16; $i++ ) {
            if( $states->{$i} ) {
                my $killTime = int( $killTimes->{$i} || 0 );
                if( $now > $killTime ) {
                    $rc->setRelayStates( { $i => 0 } );
                }
            }
        }
    }
}

my $pid = RelayServer->new(4932)->background();
print "Use 'kill $pid' to stop server\n";

