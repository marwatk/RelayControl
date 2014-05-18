#!/usr/bin/perl

use strict;
use warnings;

#Examples:

#relaycontrol.pl 
#Prints out current state

#relaycontrol.pl 1010000000000000000
#Turns on relay 1 and 3, turns others off

#relaycontrol.pl 101
#Turns on relay 1 and 3, turns off 2, leaves others alon

#relaycontrol.pl **1
#Turns on relay 3, leaves all others along

#relaycontrol.pl all:on
#Turns on all relays

#relaycontrol.pl all:off
#Turns off all relays

#relaycontrol.pl 1:on 3:on 5:off
#Turns on 1 and 3, turns off 5, leaves others along

#Change this to your device or use udev
my $FILE = "/dev/hidraw0";

my @ARGS = @ARGV;

#printVersion();

my $state = getRelayState();
print( "         1234567890123456\n" );
print( "Current: $state (" . binaryToHex( $state ) . ")\n" );


if( scalar( @ARGV ) == 1 && $ARGV[0] =~ /^[10*]+$/ ) {
    my $newState = $ARGV[0];
    for( my $i = 0; $i < length( $newState ); $i++ ) {
        my $newChar = substr( $newState, $i, 1 );
        if( $newChar eq '1' || $newChar eq '0' ) {
            substr( $state, $i, 1 ) = $newChar;
        }
    }
    
    print "Setting: $state (" . binaryToHex( $state ) . ")\n";
    setRelayState( $state );
    my $test = $state;
    $state = getRelayState();
    print "Result:  $state (" . binaryToHex( $state ) . ")\n";
    if( $state eq $test ) {
        print "SUCCESS\n";
        exit( 0 );
    }
    else {
        print "FAILURE\n";
        exit( 1 );
    }
}
elsif( scalar( @ARGV ) >= 1 ) {
    my $newState = $state;
    foreach my $arg ( @ARGV ) {
        $arg = lc( $arg );
        if( $arg =~ /(all|\d+):(off|on)/ ) {
            my $num = $1;
            my $on = $2 eq 'on' ? 1 : 0;
            if( $num eq 'all' ) {
                $newState = $on ? '1111111111111111' : '0000000000000000';
            }
            else {
                $num--;
                substr( $newState, $num, 1 ) = $on;
            }
        }
        else {
            print "Invalid argument: $arg\n";
            print "FAILURE\n";
            exit( 1 );
        }
    }
    $state = $newState;
    print "Setting: $state (" . binaryToHex( $state ) . ")\n";
    setRelayState( $state );
    my $test = $state;
    $state = getRelayState();
    print "Result:  $state (" . binaryToHex( $state ) . ")\n";
    if( $state eq $test ) {
        print "SUCCESS\n";
        exit( 0 );
    }
    else {
        print "FAILURE\n";
        exit( 1 );
    }
    
    
}

exit( 0 );


sub fixOrder { #Relays map like this: [7,6,5,4,3,2,1,0,15,14,13,12,11,10,9,8]
    my $inState = shift;
    return( reverse( substr( $inState, 0, 8 ) ) . reverse( substr( $inState, 8, 8 ) ) );
}

sub setRelayState {
    my $binaryState = shift;
    sendMessage( hexToData( endPad( '21' . binaryToHex( fixOrder( $binaryState ) ), 128 ) ) );
}


sub getRelayState {
    my $message = hexToData( endPad( '31', 128 ) );    
    sendMessage( $message );
    my $result = readMessage();
    my $resultHex = dataToHex( $result );
    if( $resultHex =~ /^a4000000000000000000000000000000(....)000/ ) {
        return fixOrder( hexToBinary( $1 ) );
    }
    return undef;
}

sub printVersion {
    sendMessage( hexToData( endPad( 'AA', 128 ) ) );
    my $result = readMessage();
    my $resultHex = dataToHex( $result );
    if( $resultHex =~ /^a572(..)(..)(..)0000000000000000000000(....)000/ ) {
        my $numRelays = hex( $1 );
        my $v1 = $2;
        my $v2 = $3;
        my $vState = fixOrder( hexToBinary( $4 ) );
        print "Num Relays: $numRelays\nVersion $v1.$v2\nRelay State: $vState\n";
    }
}

sub hexToBinary {
    return frontPad( sprintf( "%b", hex( shift ) ), 16 );
}
sub binaryToHex {
    return unpack( "H*", pack( "B*", shift ) );
}
sub binaryToData {
    return pack( "B*", shift );
}
sub dataToBinary {
    return unpack( "B*", shift );
}
sub hexToData {
    return pack( "H*", shift );
}
sub dataToHex {
    return unpack( "H*", shift );
}

sub frontPad {
    my $in = shift;
    my $len = shift;
    while( length( $in ) < $len ) {
        $in = '0' . $in;
    }
    return $in;
}
sub endPad {
    my $in = shift;
    my $len = shift;
    while( length( $in ) < $len ) {
        $in .= '0';
    }
    return $in;
}

sub sendMessage {
    my $binMsg = shift;
    open( FILE, "> $FILE" );
    binmode( FILE );
    print FILE $binMsg;
    close( FILE );
}

sub readMessage {
    open( FILE, "< $FILE" );
    my $buf;
    my $read = read( FILE, $buf, 64 );
    if( $read != 64 ) {
        print "Didn't get 64, only $read\n";
    }
    return $buf;
}


