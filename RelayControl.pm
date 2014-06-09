#!/usr/bin/perl


package RelayControl;

use strict;
use warnings;
use Lock::File qw( lockfile );

my $FILE = "/dev/hidraw0";

sub new {
    my $class = shift;
    my $self = {};
    $self->{file} = shift || $FILE;
    return bless( $self, $class );
}

sub _repeatedGetState {
    my $self = shift;
    my $state;
    while( !defined( $state ) ) {
        $state = $self->_getState();
    }
    return $state;
}
    


sub getAllRelayStates {
    my $self = shift;
    my $state = $self->_repeatedGetState();
    my $states = {};
    my $num = 1;
    foreach my $val ( split( //, $state ) ) {
        $states->{$num++} = $val;
    }
    return $states;
}

sub getRelayState {
    my $self = shift;
    my $relayNum = int( shift );
    if( $relayNum > 16 || $relayNum < 1 ) {
        die( "Invalid relay number: $relayNum" );
    }
    my $state = $self->_repeatedGetState( 0 );
    return substr( $state, $relayNum - 1, 1 ) eq '1';
}

sub setRelayStates {
    my $self = shift;
    my $states = shift;
    $self->_lock();
    my $state = $self->_repeatedGetState( 1 );
    foreach my $key ( keys %$states ) {
        my $val = $states->{$key} ? '1' : '0';
        if( int( $key ) < 1 || int( $key ) > 16 ) {
            die( "Invalid relay number: $key" );
        }
        my $idx = int( $key ) - 1;
        substr( $state, $idx, 1 ) = $val;
    }
    $self->_setState( $state );
    $self->_unlock();
}

sub getRelayCount {
    my $self = shift;
    $self->_loadVersion();
    return $self->{numRelays};
}

sub _fixOrder { #Relays map like this: [7,6,5,4,3,2,1,0,15,14,13,12,11,10,9,8]
    my $inState = shift;
    return( reverse( substr( $inState, 0, 8 ) ) . reverse( substr( $inState, 8, 8 ) ) );
}

sub _setState {
    my $self = shift;
    my $binaryState = shift;
    $self->_lock();
    $self->_sendMessage( hexToData( endPad( '21' . binaryToHex( _fixOrder( $binaryState ) ), 128 ) ) );
    $self->_unlock();
    $self->{state} = $binaryState;
}

#returns binary representation of state as string (1010100011, etc)
sub _getState {
    my $self = shift;
    my $force = shift;
    my $message = hexToData( endPad( '31', 128 ) );    
    $self->_lock();
    my $result = $self->_sendMessage( $message, 1 );
    $self->_unlock();
    my $resultHex = dataToHex( $result );
    if( $resultHex =~ /^a4000000000000000000000000000000(....)000/ ) {
        return _fixOrder( hexToBinary( $1 ) );
    }
    else {
        print STDERR "Invalid return data in _getState: ", $resultHex, "\n"; 
    }
    return undef;
}

sub _loadVersion {
    my $self = shift;
    if( !$self->{version} ) {
        $self->_lock();
        my $result = $self->_sendMessage( hexToData( endPad( 'AA', 128 ) ), 1 );
        $self->_unlock();
        my $resultHex = dataToHex( $result );
        if( $resultHex =~ /^a572(..)(..)(..)0000000000000000000000(....)000/ ) {
            $self->{numRelays} = hex( $1 );
            $self->{version} = "$2.$3";
            $self->{state} = _fixOrder( hexToBinary( $4 ) );
        }
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

sub isLocked {
    my $self = shift;
    return $self->{lockCount};
}

sub _sendMessage {
    my $self = shift;
    my $binMsg = shift;
    my $readAfter = shift;
    open( TTY, "+< $self->{file}" );
    binmode( TTY );
    print TTY $binMsg;
    my $buf;
    if( $readAfter ) {
        $buf;
        my $read = read( TTY, $buf, 64 );
        if( $read && $read != 64 ) {
            print STDERR "Didn't get 64, only $read\n";
        }
    }
    close( TTY );
    return $buf;
}

sub _lock {
    my $self = shift;
    if( !defined( $self->{lock} ) ) {
        $self->{lock} = lockfile( '/tmp/relaycontrol.lock' );
    }
    $self->{lockCount}++;
}
sub _unlock {
    my $self = shift;
    if( defined( $self->{lockCount} ) ) {
        $self->{lockCount}--;
        if( $self->{lockCount} == 0 ) {
            $self->{lock}->unlock();
            delete( $self->{lock} );
        }
    }
}

