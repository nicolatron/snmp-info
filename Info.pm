# SNMP::Info - Max Baker <max@warped.org>
# $Id$
#
# Copyright (c) 2002-3, Regents of the University of California
# All rights reserved.  
#
# See COPYRIGHT at bottom

package SNMP::Info;
$VERSION = 0.4;
use strict;

use Exporter;
use SNMP;
use Carp;
use Math::BigInt;

@SNMP::Info::ISA = qw/Exporter/;
@SNMP::Info::EXPORT_OK = qw//;

use vars qw/$VERSION %FUNCS %GLOBALS %MIBS %MUNGE $AUTOLOAD $INIT $DEBUG %SPEED_MAP 
            $NOSUCH $BIGINT/;

=head1 NAME

SNMP::Info - Object Oriented Perl5 Interface to Network devices and MIBs through SNMP. 

=head1 VERSION

SNMP::Info - Version 0.4

=head1 AUTHOR

Max Baker (C<max@warped.org>)

SNMP::Info was created for Netdisco (www.netdisco.org) at UCSC

=head1 SYNOPSIS

 use SNMP::Info;

 my $info = new SNMP::Info( 
                            # Auto Discover more specific Device Class
                            AutoSpecify => 1,
                            Debug       => 1,
                            # The rest is passed to SNMP::Session
                            DestHost    => 'router',
                            Community   => 'public',
                            Version     => 2 
                          ) or die "Can't connect to device.\n"

 $name  = $info->name();
 $class = $info->class()
 print "SNMP::Info is using this device class : $class\n";

 # Find out the Duplex status for the ports
 my $interfaces = $info->interfaces();
 my $i_duplex   = $info->i_duplex();

 # Get CDP Neighbor info
 my $c_if       = $info->c_if();
 my $c_ip       = $info->c_ip();
 my $c_port     = $info->c_port();

 # Print out data per port
 foreach my $iid (keys %$interfaces){
    my $duplex = $i_duplex->{$iid};
    # Print out physical port name, not snmp iid
    my $port  = $interfaces->{$iid};

    # The CDP Table has table entries different than the interface tables.
    # So we use c_if to get the map from cdp table to interface table.

    my %c_map = reverse %$c_if; 
    my $c_key = $c_map{$iid};
    my $neighbor_ip   = $c_ip->{$c_key};
    my $neighbor_port = $c_port->{$c_key};

    print "$port: $duplex duplex";
    print " connected to $neighbor_ip / $neighbor_port\n" if defined $remote_ip;
    print "\n";

 }

=head1 DESCRIPTION 

SNMP::Info gives an object oriented interface to information obtained through SNMP.

This module is geared towards network devices.  Subclasses exist for a number of 
network devices and common MIBs. 

The idea behind this module is to give a common interface to data from network devices,
leaving the device-specific hacks behind the scenes in subclasses.

In the SYNOPSIS example we fetch the name of all the ports on the device and the duplex
setting for that port with two methods -- interfaces() and i_duplex().

The information may be coming from any number of MIB files and is very vendor specific.
SNMP::Info provides you a common method for all supported devices.

Adding support for your own device is easy, and takes little much SNMP knowledge.

The module is not limited to network devices. Any MIB or device can be given an objected oriented
front-end by making a module that consists of a couple hashes.  See EXTENDING SNMP::INFO.

=head2 Requirements

=over

=item 1. Net-SNMP

To use this module, you must have Net-SNMP installed on your system.
More specifically you need the Perl modules that come with it.

DO NOT INSTALL SNMP:: or Net::SNMP from CPAN!

The SNMP module is matched to an install of net-snmp, and must be installed
from the net-snmp source tree.

The Perl module C<SNMP> is found inside the net-snmp distribution.  Go to the F<perl/> directory
of the distribution to install it, or run C<./configure --with-perl-modules> from the top directory
of the net-snmp distribution.

Net-SNMP can be found at http://net-snmp.sourceforge.net

Version 5.0.2 or greater is recommended.  Various version 4's will work, and 5.0.1 is kinda flaky
on the Perl side.

Note: Net-SNMP was previously called ucd-snmp.

=item 2. MIBS

SNMP::Info operates on textual descriptors found in MIBs. MIBs are text databases that
are freely and easily obtainable on the Net.

Make sure that your snmp.conf is updated to point to your MIB directory
and that the MIBs are world-readable.  

Then run C<snmpconf> and setup that directory as default.  Move F<snmp.conf>
into F</usr/local/share/snmp> when you are done.

=over

=item Basic MIBs

A minimum amount of MIBs to have are the Version 2 MIBs from Cisco, found at

ftp://ftp.cisco.com/pub/mibs/v2/v2.tar.gz

To install them : 

 mkdir -p /usr/local/share/snmp/mibs && cd /usr/local/share/snmp/mibs && tar xvfz /path/to/v2.tar.gz 

=item Version 1 MIBs

You will also need to install some of the version one MIBs from Cisco :

ftp://ftp.cisco.com/pub/mibs/v1/v1.tar.gz

Extract 

=over

=item BRIDGE-MIB

=item SNMP-REPEATER-MIB

=item STAND-ALONE-ETHERNET-SWITCH-MIB (ESSWITCH-MIB)

=back

by running 

 mkdir -p /usr/local/share/snmp/mibs
 cd /usr/local/share/snmp/mibs
 tar xvfz /path/to/v1.tar.gz BRIDGE-MIB.my SNMP-REPEATER-MIB.my ESSWITCH-MIB.my

=item More Specific MIBs

Some non-cisco subclasses will need MIBs other than the basic one available from Cisco.

Check below under each subclass for requirements.

=back

=back

=head2 Design Goals

=over

=item 1. Use of textual MIB leaf identifier and enumerated values 

=over

=item * All values are retrieved via MIB Leaf node names

For example SNMP::Info has an entry in its %GLOBALS hash for ``sysName'' instead
of 1.3.6.1.2.1.1.5.

=item * Data returned is in the enumerated value form.

For Example instead of looking up 1.3.6.1.2.1.2.2.1.3 and getting back C<23>

SNMP::Info will ask for C<RFC1213-MIB::ifType> and will get back C<ppp>. 

=back

=item 2. SNMP::Info is easily extended to new devices

You can create a new subclass for a device by providing four hashes :
%GLOBALS, %MIBS, %FUNCS, and %MUNGE.  

Or you can override any existing methods from a parent class by making a short subroutine. 

See the section EXTENDING SNMP::INFO for more details.

When you make a new subclass for a device, please be sure to send it
back to the developers at snmp@warped.org for inclusion in the next version.

=back

=head2 Subclasses

These are the subclasses that implement MIBs and support devices:

Required MIBs not included in the install instructions above are noted here.

=head3 MIB Subclasses

These subclasses implement method to access one or more MIBs.  These are not 
used directly, but rather inherited from device subclasses. 

=over

=item SNMP::Info::Bridge

BRIDGE-MIB (RFC1286).  Inherited by devices with Layer2 service.

=item SNMP::Info::CDP

CISCO-CDP-MIB.  Cisco Discovery Protocol (CDP) Support.  Inherited by devices serving Layer2 or Layer3.

=item SNMP::Info::CiscoStats

Provides common interfaces for memory, cpu, and os statistics for Cisco devices.  Provides methods for 
information in : OLD-CISCO-CPU-MIB, CISCO-PROCESS-MIB and CISCO-MEMORY-POOL-MIB

=item SNMP::Info::Entity

ENTITY-MIB.  Used for device info in Cisco and other vendors.

=item SNMP::Info::EtherLike

ETHERLIKE-MIB (RFC1398) - Some Layer3 devices implement this MIB, as well as some Aironet Layer 2 devices (non Cisco).

=item SNMP::Info::MAU

MAU-MIB (RFC2668).  Some Layer2 devices use this for extended Ethernet (Media Access Unit) interface information.

=back

=head3 Device Subclasses

These subclasses inherit from one or more classes to provide a common interface to data obtainable
from network devices. 

=over

=item SNMP::Info::Layer1

Generic Layer1 Device subclass.

=over 

=item SNMP::Info::Layer1::Allied

Subclass for Allied Telesys Repeaters / Hubs.  

Requires ATI-MIB

See SNMP::Info::Layer1::Allied for where to get MIBs required.

=item SNMP::Info::Layer1::Asante

Subclass for Asante 1012 Hubs. 

Requires ASANTE-HUB1012-MIB

See SNMP::Info::Layer1::Asante for where to get MIBs required.

=back

=item SNMP::Info::Layer2 

Generic Layer2 Device subclass.

=over

=item SNMP::Info::Layer2::Bay

Bay Networks BayStack switch Support.  Provides translation from Bay Network Topology Table
information to CDP.

Requires SYNOPTICS-ROOT-MIB and S5-ETH-MULTISEG-TOPOLOGY-MIB

See SNMP::Info::Bay for where to get MIBs required.

=item SNMP::Info::Layer2::C1900

Subclass for Cisco Catalyst 1900 and 1900c Devices running CatOS.

=item SNMP::Info::Layer2::C2900

Subclass for Cisco Catalyst 2900 devices running IOS.

=item SNMP::Info::Layer2::Catalyst

Subclass for Cisco Catalyst switches running CatOS.  These switches usually
report a model number that starts with ''wsc''.   Note that this class
does not support everything that has the name Catalyst. 

=item SNMP::Info::Layer2::HP

Subclass for HP Procurve Swithces

Requires HP-ICF-OID and ENTITY-MIB downloaded from HP.  

See SNMP::Info::Layer2::HP for more info.

=back

=item SNMP::Info::Layer3

Generic Layer3 and Layer2+3 Device subclass.

=over

=item SNMP::Info::Layer3::Aironet

Subclass for Cisco Aironet wireless access points (AP).

MIBs for these devices now included in v2.tar.gz available from ftp.cisco.com.

=item SNMP::Info::Layer3::Foundry

No longer supported.

Subclass for older Foundry Network devices.

Requires FOUNDRY-SN-ROOT-MIB. 

See SNMP::Info::Layer3::Foundry for more info.

=item SNMP::Info::Layer3::C3550

Subclass for Cisco Catalyst 3550 2/3 switches running IOS.

=back

=back

=head1 USAGE

=head2 Constructor

=over

=item new()

Creates a new object and connects via SNMP::Session. 

 my $info = new SNMP::Info( 'Debug'       => 1,
                            'AutoSpecify' => 1,
                            'BigInt'      => 1
                            'DestHost'    => 'myrouter',
                            'Community'   => 'public',
                            'Version'     => 2
                          ) or die;

SNMP::Info Specific Arguments :

 AutoSpecify = Returns an object of a more specific device class
               *See specify() entry*
 Debug       = Prints Lots of debugging messages
 Session     = SNMP::Session object to use instead of connecting on own.
 BigInt      = Return Math::BigInt objects for 64 bit counters.  Sets on a global scope, not object.
 RetryNoSuch = When using SNMP Version 1, try reading values even if they come back
               as "no such variable in this MIB".  Defaults to true, set to false if
               so desired.  This feature lets you read SNMPv2 data from an SNMP version
               1 connection, and should probably be left on.

All other arguments are passed to SNMP::Session.

See SNMP::Session for a list of other possible arguments.

=cut
sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my %args = @_;
    my $new_obj = {};
    bless $new_obj,$class;

    $new_obj->{class} = $class;

    # load references to all the subclass data structures
    {
        no strict 'refs';
        $new_obj->{init}    = \${$class . '::INIT'};
        $new_obj->{mibs}    = \%{$class . '::MIBS'};
        $new_obj->{globals} = \%{$class . '::GLOBALS'};
        $new_obj->{funcs}   = \%{$class . '::FUNCS'};
        $new_obj->{munge}   = \%{$class . '::MUNGE'};
    }

    # Initialize mibs if not done
    my $init_ref = $new_obj->{init};
    unless ( $$init_ref ) {
        $new_obj->init();
        $$init_ref=1;    
    }

    # SNMP::Info specific args :
    my $auto_specific = 0;
    if (defined $args{AutoSpecify}){
        $auto_specific = $args{AutoSpecify} || 0;
        delete $args{AutoSpecify};
    }
    if (defined $args{Debug}){
        $new_obj->debug($args{Debug});
        delete $args{Debug};
    } else {
        $new_obj->debug($DEBUG);
    }
    my $sess = undef;
    if (defined $args{Session}){
        $sess = $args{Session};
        delete $args{Session};
    }
    if (defined $args{BigInt}){
        $BIGINT = $args{BigInt};
        delete $args{BigInt};
    }

    $new_obj->{nosuch} = $args{RetryNoSuch} || $NOSUCH;

    # Connects to device unless open session is provided.  
    $sess = new SNMP::Session( 'UseEnums' => 1, %args , 'RetryNoSuch' => $new_obj->{nosuch}) 
        unless defined $sess;

    unless (defined $sess){
        my $sess_err = $sess->{ErrorStr} || '';
        $new_obj->error_throw("SNMP::Info::new() Failed to Create Session. $sess_err");
        return undef;
    }

    # Table function store
    my $store = {};

    # Save Args for later
    $new_obj->{store}     = $store;
    $new_obj->{sess}      = $sess;
    $new_obj->{args}      = \%args;
    $new_obj->{snmp_ver}  = $args{Version};
    $new_obj->{snmp_comm} = $args{Community};

    return $auto_specific ?
        $new_obj->specify() : $new_obj;
}

=back

=head2 Data is Cached

Methods and subroutines requesting data from a device will only load the data once, and then
return cached versions of that data. 

Run $info->load_METHOD() where method is something like 'i_name' to reload data from a 
table method.

Run $info->clear_cache() to clear the cache to allow reload of both globals and table methods.

=head2 Object Scalar Methods

These are for package related data, not direcly supplied
from SNMP.

=over

=item $info->clear_cache()

Clears the cached data.  This includes GLOBALS data and TABLE METHOD data.

=cut
sub clear_cache {
    my $self = shift;
    
    foreach my $key (keys %$self){
        next unless defined $key;
        next unless $key =~ /^_/;
        delete $self->{$key};
    }
}

=item $info->debug(1)

Returns current debug status, and optionally toggles debugging info for this object.

=cut
sub debug {
    my $self = shift;
    my $debug = shift;

    if (defined $debug){
        $self->{debug} = $debug;
#        $SNMP::debugging=$debug;
    }
    
    return $self->{debug};
}

=item $info->device_type()

Returns the Subclass name for this device.  C<SNMP::Info> is returned if no more
specific class is available.

First the device is checked for Layer 3 support and a specific subclass,
then Layer 2 support and subclasses are checked for.

This means that Layer 2 / 3  switches and routers will fall under the
SNMP::Info::Layer3 subclasses.

If the device still can be connected to via SNMP::Info, then 
SNMP::Info is returned.  

Algorithm for Subclass Detection:

        Layer3 Support                     -> SNMP::Info::Layer3
            Aironet (non IOS)              -> SNMP::Info::Layer3::Aironet
            Catalyst 3550                  -> SNMP::Info::Layer3::C3550
            Foundry                        -> SNMP::Info::Layer3::Foundry
        Elsif Layer2 (no Layer3)           -> SNMP::Info::Layer2 
            Aironet (Cisco) AP1100         -> SNMP::Info::Layer2::Aironet
            Bay Networks                   -> SNMP::Info::Layer2::Bay
            Catalyst 1900                  -> SNMP::Info::Layer2::C1900
            Catalyst 2900XL (IOS)          -> SNMP::Info::Layer2::C2900
            Catalyst WS-C (2926,5xxx,6xxx) -> SNMP::Info::Layer2::Catalyst
            HP Procurve                    -> SNMP::Info::Layer2::HP
        Elsif Layer1 Support               -> SNMP::Info::Layer1
            Allied                         -> SNMP::Info::Layer1::Allied
            Asante                         -> SNMP::Info::Layer1::Asante
        Else                               -> SNMP::Info

=cut
sub device_type {
    my $info = shift;

    my $objtype = "SNMP::Info";

    my $layers = $info->layers();
    # if we dont have sysServices, we dont have anything else either probably.
    return undef unless (defined $layers and length($layers));

    my $desc   = $info->description();

    # Layer 3 Supported 
    #   (usually has layer2 as well, so we check for 3 first)
    if ($info->has_layer(3)) {
        $objtype = 'SNMP::Info::Layer3';

        # Device Type Overrides

        return $objtype unless (defined $desc and length($desc));

        $objtype = 'SNMP::Info::Layer3::C3550'   if $desc =~ /C3550/ ;
        $objtype = 'SNMP::Info::Layer3::Foundry' if $desc =~ /foundry/i ;
        $objtype = 'SNMP::Info::Layer3::Aironet' if ($desc =~ /cisco/i and $desc =~ /\D3[45]0\D/) ;

    # Layer 2 Supported
    } elsif ($info->has_layer(2)) {
        $objtype = 'SNMP::Info::Layer2'; 

        return $objtype unless (defined $desc and $desc !~ /^\s*$/);

        # Device Type Overrides
        
        #   Catalyst 1900 series override
        $objtype = 'SNMP::Info::Layer2::C1900' if ($desc =~ /catalyst/i and $desc =~ /\D19\d{2}/);

        #   Catalyst 2900 (IOS) series override
        $objtype = 'SNMP::Info::Layer2::C2900' if ($desc =~ /C2900XL/i );

        #   Catalyst WS-C series override (2926,5xxx,6xxx)
        $objtype = 'SNMP::Info::Layer2::Catalyst' if ($desc =~ /WS-C\d{4}/);

        #   HP
        $objtype = 'SNMP::Info::Layer2::HP' if ($desc =~ /hp/i); 
    
        #  Bay Switch
        $objtype = 'SNMP::Info::Layer2::Bay' if ($desc =~ /bay/i);

        #  Aironet
        $objtype = 'SNMP::Info::Layer2::Aironet' if ($desc =~ /C1100/);
    
    } elsif ($info->has_layer(1)) {
        $objtype = 'SNMP::Info::Layer1';
        #  Allied crap-o-hub
        $objtype = 'SNMP::Info::Layer1::Allied' if ($desc =~ /allied/i);
        $objtype = 'SNMP::Info::Layer1::Asante' if ($desc =~ /asante/i);
    }

    return $objtype; 
}

=item $info->error(no_clear)

Returns Error message if there is an error, or undef if there is not.

Reading the error will clear the error unless you set the no_clear flag.

=cut
sub error {
    my $self     = shift;
    my $no_clear = shift;
    my $err      = $self->{error};

    $self->{error} = undef unless defined $no_clear and $no_clear;
    return $err;
}

=item $info->has_layer(3)

Returns non-zero if the device has the supplied layer in the OSI Model

Returns C<undef> if the device doesn't support the layers() call.

=cut
sub has_layer {
    my $self = shift;
    my $check_for = shift;

    my $layers = $self->layers();
    return undef unless defined $layers;
    return undef unless length($layers);
    return substr($layers,8-$check_for, 1);
}

=item $info->snmp_comm()

Returns SNMP Community string used in conncetion

=cut
sub snmp_comm {
    my $self = shift;
    return $self->{snmp_comm};
}

=item $info->snmp_ver()

Returns SNMP Version used for this connection

=cut
sub snmp_ver {
    my $self = shift;
    return $self->{snmp_ver};
} 

=item $info->specify()

Returns an object of a more-specific subclass.  

 my $info = new SNMP::Info(...);
 # Returns more specific object type
 $info = $info->specific();

Usually this method is called internally from new(AutoSpecify => 1)

See device_type() entry for how a subclass is chosen. 

=back

=cut
sub specify {
    my $self = shift;

    my $device_type = $self->device_type();
    unless (defined $device_type) {
        $self->error_throw("SNMP::Info::specify() - Could not get info from device");
        return undef;
    }
    return $self if $device_type eq 'SNMP::Info';

    # Load Subclass
    # By evaling a string the contents of device_type now becomes a bareword. 
    eval "require $device_type;";
    if ($@) {
        croak "SNMP::Info::specify() Loading $device_type Failed. $@\n";
    }

    my $args    = $self->args();
    my $session = $self->session();
    my $sub_obj = $device_type->new(%$args,'Session'=>$session);
    $sub_obj->debug($self->debug());

    unless (defined $sub_obj) {
        $self->error_throw("SNMP::Info::specify() - Could not connect with new class ($device_type)");
        return $self;
    }

    $self->debug() and print "SNMP::Info::specify() - Changed Class to $device_type.\n";
    return $sub_obj;
}

=head2 Globals (Scalar Methods)

These are methods to return scalar data from RFC1213.  

Some subset of these is probably available for any network device that speaks SNMP.

=over

=item $info->uptime()

Uptime in hundreths of seconds since device became available.

(B<sysUpTime>)

=item $info->contact()

(B<sysContact>)

=item $info->name()

(B<sysName>)

=item $info->location() 

(B<sysLocation>)

=item $info->layers()

This returns a binary encoded string where each
digit represents a layer of the OSI model served
by the device.  

    eg: 01000010  means layers 2 (physical) and 7 (Application) 
                  are served.

Note:  This string is 8 digits long.  

See $info->has_layer()

(B<sysServices>)

=item $info->ports()

Number of interfaces available on this device.

Not too useful as the number of SNMP interfaces usually does not 
correspond with the number of physical ports

(B<ifNumber>)

=back

=head2 Table Methods

Each of these methods returns a hash_reference to a hash keyed on the interface index in SNMP.

Example : $info->interfaces() might return  
    { '1.12' => 'FastEthernet/0',
      '2.15' => 'FastEthernet/1',
      '9.99' => 'FastEthernet/2'
    }

The key is what you would see if you were to do an snmpwalk, and in some cases changes between reboots of
the network device.

=head3 Interface Information

=over

=item $info->interfaces()

This methods is overriden in each subclass to provide a 
mapping between the Interface Table Index (iid) and the physical port name.

=item $info->if_ignore()

Returns a reference to a hash where key values that exist are 
interfaces to ignore.

Ignored interfaces are ones that are usually not physical ports or Virtual Lans (VLANs) such as the Loopback interface,
or the CPU interface. 

=cut
sub if_ignore {
    my %nothing;
    return \%nothing;
}

=item $info->i_index()

Default SNMP IID to Interface index.

(B<ifIndex>)

=item $info->i_description() 

Description of the interface. Usually a little longer single word name that is both
human and machine friendly.  Not always.

(B<ifDescr>)

=item $info->i_type()

Interface type, such as Vlan, 10baseT, Ethernet, Serial

(B<ifType>)

=item $info->i_mtu()

INTEGER. Interface MTU value.

(B<ifMtu>)

=item $info->i_speed()

Speed of the link, human format.  See munge_speed() later in document for details.

(B<ifSpeed>)

=item $info->i_mac() 

MAC address of the interface.  Note this is just the MAC of the port, not anything connected to it.

(B<ifPhysAddress>)

=item $info->i_up() 

Link Status of the interface.  Typical values are 'up' and 'down'.

(B<ifOperStatus>)

=item $info->i_up_admin()

Administrative status of the port.  Typical values are 'enabled' and 'disabled'.

(B<ifAdminStatus>)

=item $info->i_name()

Interface Name field.  Supported by a smaller subset of devices, this fields is often 
human set.

(B<ifName>)

=item $info->i_alias()

Interface Name field.  For certain devices this is a more human friendly form of i_description().
For others it is a human set field like i_name().

(B<ifAlias>)

=back

=head3 Interface Statistics

=over

=item $info->i_octet_in(), $info->i_octets_out(),
$info->i_octet_in64(), $info->i_octets_out64()

Bandwidth.

Number of octets sent/received on the interface including framing characters.

64 bit version may not exist on all devices. 

NOTE: To manipulate 64 bit counters you need to use Math::BigInt, since the values
are too large for a normal Perl scalar.   Set the global $SNMP::Info::BIGINT to 1 , or
pass the BigInt value to new() if you want SNMP::Info to do it for you.


(B<ifInOctets>) (B<ifOutOctets>)
(B<ifHCInOctets>) (B<ifHCOutOctets>)

=item $info->i_errors_in(), $info->i_errors_out()

Number of packets that contained an error prventing delivery.  See IF-MIB for more info.

(B<ifInErrors>) (B<ifOutErrors>)

=item $info->i_pkts_ucast_in(), $info->i_pkts_ucast_out(),
$info->i_pkts_ucast_in64(), $info->i_pkts_ucast_out64()

Number of packets not sent to a multicast or broadcast address.

64 bit version may not exist on all devices. 

(B<ifInUcastPkts>) (B<ifOutUcastPkts>)
(B<ifHCInUcastPkts>) (B<ifHCOutUcastPkts>)

=item $info->i_pkts_nucast_in(), $info->i_pkts_nucast_out(),

Number of packets sent to a multicast or broadcast address.

These methods are depricated by i_pkts_multi_in() and i_pkts_bcast_in()
according to IF-MIB.  Actual device usage may vary.

(B<ifInNUcastPkts>) (B<ifOutNUcastPkts>)

=item $info->i_pkts_multi_in() $info->i_pkts_multi_out(),
$info->i_pkts_multi_in64(), $info->i_pkts_multi_out64()

Number of packets sent to a multicast address.

64 bit version may not exist on all devices. 

(B<ifInMulticastPkts>) (B<ifOutMulticastPkts>)
(B<ifHCInMulticastPkts>) (B<ifHCOutMulticastPkts>)

=item $info->i_pkts_bcast_in() $info->i_pkts_bcast_out(),
$info->i_pkts_bcast_in64() $info->i_pkts_bcast_out64()

Number of packets sent to a broadcast address on an interface.

64 bit version may not exist on all devices. 

(B<ifInBroadcastPkts>) (B<ifOutBroadcastPkts>)
(B<ifHCInBroadcastPkts>) (B<ifHCOutBroadcastPkts>)

=back

=head3 IP Address Table

Each entry in this table is an IP address in use on this device.  Usually 
this is implemented in Layer3 Devices.

=over

=item $info->ip_index()

Maps the IP Table to the IID

(B<ipAdEntIfIndex>)

=item $info->ip_table()

Maps the Table to the IP address

(B<ipAdEntAddr>)

=item $info->ip_netmask()

Gives netmask setting for IP table entry.

(B<ipAdEntNetMask>)

=item $info->ip_broadcast()

Gives broadcast address for IP table entry.

(B<ipAdEntBcastAddr>)

=back

=head2 Setting data via SNMP

This section explains how to use SNMP::Info to do SNMP Set operations.

=over

=item $info->set_METHOD($value)

Sets the global METHOD to value.  Assumes that iid is .0

Returns undef if failed, or the return value from SNMP::Session::set() (snmp_errno)

 $info->set_location("Here!");

=item $info->set_METHOD($value,$iid)

Table Methods. Set iid of method to value. 

Returns undef if failed, or the return value from SNMP::Session::set() (snmp_errno)

 # Disable a port administratvely
 my %if_map = reverse %{$info->interfaces()}
 $info->set_i_up_admin('down', $if_map{'FastEthernet0/0') 
    or die "Couldn't disable the port. ",$info->error(1);

=back

NOTE: You must be connected to your device with a ReadWrite community string in order
for set operations to work.

NOTE: This will only set data listed in %FUNCS and %GLOBALS.  For data aquired from
overriden methods (subroutines) specific set_METHOD() subroutines will need to be
added.

=head2 Quiet Mode

SNMP::Info will not chirp anything to STDOUT unless there is a serious error (in which case it will probably
die).

To get lots of debug info, set the Debug flag when calling new() or call $info->debug(1);

When calling a method check the return value.  If the return value is undef then check $info->error()

Beware, calling $info->error() clears the error.

 my $name = $info->name() or die "Couldn't get sysName!" . $name->error();

=head1 EXTENDING SNMP::INFO

=head2 Data Structures required in new Subclass

A class inheriting this class must implement these data
structures : 

=over

=item  $INIT

Used to flag if the MIBs have been loaded yet.

=cut
$INIT    = 0;

=item %GLOBALS

Contains a hash in the form ( method_name => SNMP iid name )
These are scalar values such as name,uptime, etc. 

When choosing the name for the methods, be aware that other new
Sub Modules might inherit this one to get it's features.  Try to
choose a prefix for methods that will give it's own name space inside
the SNMP::Info methods.

=cut
%GLOBALS = (
            # from SNMPv2-MIB
            'id'          => 'sysObjectID',
            'description' => 'sysDescr',
            'uptime'      => 'sysUpTime',
            'contact'     => 'sysContact',
            'name'        => 'sysName',
            'location'    => 'sysLocation',
            'layers'      => 'sysServices',
            'ports'       => 'ifNumber',
            );

=item %FUNCS

Contains a hash in the form ( method_name => SNMP iid)
These are table entries, such as the IfIndex

=cut
%FUNCS   = (
            'interfaces'         => 'ifIndex',
            # from SNMPv2-MIB
            'i_index'            => 'ifIndex',
            'i_description'      => 'ifDescr',
            'i_type'             => 'ifType',
            'i_mtu'              => 'ifMtu',
            'i_speed'            => 'ifSpeed',
            'i_mac'              => 'ifPhysAddress',
            'i_up'               => 'ifOperStatus',
            'i_up_admin'         => 'ifAdminStatus',
            'i_name'             => 'ifName',
            'i_octet_in'         => 'ifInOctets',
            'i_octet_out'        => 'ifOutOctets',
            'i_errors_in'        => 'ifInErrors',
            'i_errors_out'       => 'ifOutErrors',
            'i_pkts_ucast_in'    => 'ifInUcastPkts',
            'i_pkts_ucast_out'   => 'ifOutUcastPkts',
            'i_pkts_nucast_in'   => 'ifInNUcastPkts',
            'i_pkts_nucast_out'  => 'ifOutNUcastPkts',
            # IP Address Table
            'ip_index'           => 'ipAdEntIfIndex',
            'ip_table'           => 'ipAdEntAddr',
            'ip_netmask'         => 'ipAdEntNetMask',
            'ip_broadcast'       => 'ipAdEntBcastAddr',
            # ifXTable - Extension Table
            'i_pkts_multi_in'    => 'ifInMulticastPkts',
            'i_pkts_multi_out'   => 'ifOutMulticastPkts',
            'i_pkts_bcast_in'    => 'ifInBroadcastPkts',
            'i_pkts_bcast_out'   => 'ifOutBroadcastPkts',
            'i_octet_in64'       => 'ifHCInOctets',
            'i_octet_out64'      => 'ifHCOutOctets',
            'i_pkts_ucast_in64'  => 'ifHCInUcastPkts',
            'i_pkts_ucast_out64' => 'ifHCOutUcastPkts',
            'i_pkts_multi_in64'  => 'ifHCInMulticastPkts',
            'i_pkts_multi_out64' => 'ifHCOutMulticastPkts',
            'i_pkts_bcast_in64'  => 'ifHCInBroadcastPkts',
            'i_pkts_bcast_out64' => 'ifHCOutBroadcastPkts',
            'i_alias'            => 'ifAlias'
           );

=item %MIBS

A list of each mib needed.  

('MIB-NAME' => 'itemToTestForPresence')

The value for each entry should be a MIB object to check for to make sure 
that the MIB is present and has loaded correctly. 

$info->init() will throw an exception if a MIB does not load. 

=cut
%MIBS    = ('RFC1213-MIB' => 'sysName');

=item %MUNGE

A map between method calls (from %FUNCS or %GLOBALS) and subroutine methods.
The subroutine called will be passed the data as it gets it from SNMP and 
it should return that same data in a more human friendly format. 

Sample %MUNGE:

 (my_ip     => \&munge_ip,
  my_mac    => \&munge_mac,
  my_layers => \&munge_dec2bin
 )

=cut
%MUNGE   = ('ip'                 => \&munge_ip,
            'mac'                => \&munge_mac,
            'i_mac'              => \&munge_mac,
            'layers'             => \&munge_dec2bin,
            'i_speed'            => \&munge_speed,
            'i_octet_in64'       => \&munge_counter64,
            'i_octet_out64'      => \&munge_counter64,
            'i_pkts_ucast_in64'  => \&munge_counter64,
            'i_pkts_ucast_out64' => \&munge_counter64,
            'i_pkts_mutli_in64'  => \&munge_counter64,
            'i_pkts_multi_out64' => \&munge_counter64,
            'i_pkts_bcast_in64'  => \&munge_counter64,
            'i_pkts_bcast_out64' => \&munge_counter64,
            );

=back

=head2 Sample Subclass

Let's make a sample Layer 2 Device subclass :

----------------------- snip --------------------------------

 # SNMP::Info::Layer2::Sample

 package SNMP::Info::Layer2::Sample;

 $VERSION = 0.1;

 use strict;

 use Exporter;
 use SNMP::Info::Layer2;

 @SNMP::Info::Layer2::Sample::ISA = qw/SNMP::Info::Layer2 Exporter/;
 @SNMP::Info::Layer2::Sample::EXPORT_OK = qw//;

 use vars qw/$VERSION %FUNCS %GLOBALS %MIBS %MUNGE $AUTOLOAD $INIT $DEBUG/;

 %MIBS    = (%SNMP::Info::Layer2::MIBS,
             'SUPER-DOOPER-MIB'  => 'supermibobject'
            );

 %GLOBALS = (%SNMP::Info::Layer2::GLOBALS,
             'name'              => 'supermib_supername',
             'favorite_color'    => 'supermib_fav_color_object',
             'favorite_movie'    => 'supermib_fav_movie_val'
             );

 %FUNCS   = (%SNMP::Info::Layer2::FUNCS,
             # Super Dooper MIB - Super Hero Table
             'super_hero_index'  => 'SuperHeroIfIndex',
             'super_hero_name'   => 'SuperHeroIfName',
             'super_hero_powers' => 'SuperHeroIfPowers'
            );


 %MUNGE   = (%SNMP::Info::Layer2::MUNGE,
             'super_hero_powers' => \&munge_powers
            );

 # OverRide uptime() method from %SNMP::Info::GLOBALS
 sub uptime {
     my $sample = shift;

     my $name   = $sample->name();

     # this is silly but you get the idea
     return '600' if defined $name ; 
 }

 # Create our own munge function
 sub munge_powers {
     my $power = shift;

     # Take the returned obscure value and return something useful.
     return 'Fire' if $power =~ /reallyhot/i;
     return 'Ice'  if $power =~ /reallycold/i;

     # Else 
     return $power;
 }

 # Copious Documentation here!!!
 =head1 NAME
 =head1 AUTHOR
 =head1 SYNOPSIS
 =head1 DESCRIPTION
 =head2 Inherited Classes
 =head2 Required MIBs
 =head1 GLOBALS
 =head2 Overrides
 =head1 TABLE METHODS
 =head2 Overrides
 =cut

----------------------- snip --------------------------------

Be sure and send the debugged version to snmp@warped.org to be 
included in the next version of SNMP::Info.

=head1 SNMP::INFO INTERNALS

=head2 Object Namespace

Internal data is stored with bareword keys. For example $info->{debug}

SNMP Data is stored or marked cached with keys starting with an underscore. 
For example $info->{_name} is the cache for $info->name().

Cached Table data is stored in $info->store() and marked cached per above.

=head2 Package Globals

These set the default value for an object upon creation.

=over

=item $DEBUG

Default 0.  Sends copious debug info to stdout.  This global sets the object's debug status
in new() unless 'Debug' argument passed in new().  Change objects' debug status with
$info->debug().

=cut
$DEBUG = 0;

=item $BIGINT

Default 0.   Set to true to have 64 bit counters return Math::BigInt objects instead of scalar
string values.  See note under Interface Statistics about 64 bit values.

=cut
$BIGINT = 0; 

=item $NOSUCH

Default 1.  Set to false to disable RetryNoSuch option for SNMP::Session.  Or see method in new()
to do it on an object scope.

=cut
$NOSUCH = 1;

=back

=head2 Data Munging Callback Subroutines

=over

=item munge_speed()

Makes human friendly speed ratings using %SPEED_MAP

 %SPEED_MAP = (
                '64000'      => '64 kbps',
                '1500000'    => '1.5 Mbps',
                '1544000'    => 'T1',
                '2000000'    => '2.0 Mbps',
                '2048000'    => '2.048 Mbps',
                '4000000'    => '4.0 Mbps',
                '10000000'   => '10 Mbps',
                '11000000'   => '11 Mbps',
                '20000000'   => '20 Mbps',
                '16000000'   => '16 Mbps',
                '45000000'   => 'DS3',
                '45045000'   => 'DS3',
                '64000000'   => '64 Mbps',
                '100000000'  => '100 Mbps',
                '149760000'  => 'OC-1'
                '155000000'  => 'OC-1'
                '400000000'  => '400 Mbps',
                '622000000'  => 'OC-12',
                '599040000'  => 'OC-12', 
                '1000000000' => '1.0 Gbps',
             );

=cut
%SPEED_MAP = (
                '64000'      => '64 kbps',
                '1500000'    => '1.5 Mbps',
                '1544000'    => 'T1',
                '2000000'    => '2.0 Mbps',
                '2048000'    => '2.048 Mbps',
                '4000000'    => '4.0 Mbps',
                '10000000'   => '10 Mbps',
                '11000000'   => '11 Mbps',
                '20000000'   => '20 Mbps',
                '16000000'   => '16 Mbps',
                '45000000'   => '45 Mbps',
                '45045000'   => 'DS3',
                '64000000'   => '64 Mbps',
                '100000000'  => '100 Mbps',
                '149760000'  => 'OC-1',
                '155000000'  => 'OC-1',
                '400000000'  => '400 Mbps',
                '622000000'  => 'OC-12',
                '599040000'  => 'OC-12', 
                '1000000000' => '1.0 Gbps',
             );

sub munge_speed {
    my $speed = shift;
    return defined $SPEED_MAP{$speed} ? $SPEED_MAP{$speed} : $speed;
}

=item munge_ip() 

Takes a binary IP and makes it dotted ASCII

=cut
sub munge_ip {
    my $ip = shift;
    return join('.',unpack('C4',$ip));
}

=item munge_mac()

Takes an octet stream (HEX-STRING) and returns a colon separated ASCII hex string.

=cut
sub munge_mac {
    my $mac = shift;
    return undef unless defined $mac;
    return undef unless length $mac;
    return join(':',map { sprintf "%02x",$_ } unpack('C*',$mac));
}

=item munge_octet2hex()

Takes a binary octet stream and returns an ASCII hex string

=cut
sub munge_octet2hex {
    my $oct = shift;
    return join('',map {sprintf "%x",$_} unpack('C*',$oct));
}

=item munge_dec2bin()

Takes a binary char and returns its ASCII binary representation

=cut
sub munge_dec2bin {
    my $num = shift;
    return undef unless defined $num;
    #return undef unless length($num);
    $num = unpack("B32",pack("N",$num));

    # return last 8 characters only
    $num =~ s/.*(.{8})$/$1/;
    return $num
}

=item munge_bits

Takes a SNMP2 'BITS' field and returns the ASCII bit string

=cut
sub munge_bits {
    my $bits = shift;
    return undef unless defined $bits;

    return unpack("b*",$bits);
}


=item munge_counter64

If $BIGINT is set to true, then a Math::BigInt object is returned.
See Math::BigInt for details.

=cut
sub munge_counter64 {
    my $counter = shift;
    return unless defined $counter;
    return $counter unless $BIGINT;
    my $bigint = Math::BigInt->new($counter);
    return $bigint;
}

=back

=head2 Internaly Used Functions

=over

=item $info->init()

Used internally.  Loads all entries in %MIBS.

=cut
sub init {
    my $self = shift;

    &SNMP::initMib;
    
    my $version = $SNMP::VERSION;
    my ($major,$minor,$rev) = split('\.',$version);

    if ($major < 5){
        # Seems to work under 4.2.0
    } elsif ($major == 5 and $minor == 0 and $rev < 2){
        carp("SNMP 5.0.1 seems to be rather buggy. Upgrade.\n");
        # This is a bug in net-snmp 5.0.1 perl module
        # see http://groups.google.com/groups?th=47aed6bf7be6a0f5
        &SNMP::init_snmp("perl");
    }
    
    my $mibs = $self->mibs();
    
    foreach my $mib (keys %$mibs){
        &SNMP::loadModules("$mib");

        unless (defined $SNMP::MIB{$mibs->{$mib}}){
            croak "The $mib did not load. See README for $self->{class}\n";
        }    
    }
}

=item $info->args()

Returns a reference to the argument hash supplied to SNMP::Session

=cut
sub args {
    my $self = shift;
    return $self->{args};
}

=item $info->class()

Returns the class name of the object.

=cut
sub class {
    my $self=shift;
    return $self->{class};
}


=item $info->error_throw(error message)

Stores the error message for use by $info->error()

If $info->debug() is true, then the error message is carped too.

=cut
sub error_throw {
    my $self = shift;
    my $error = shift;

    return undef unless defined $error;
    $self->{error} = $error;

    if ($self->debug()){
        $error .= "\n" unless $error =~ /\n$/;
        carp($error);
    }
}

=item $info->funcs()

Returns a reference to the %FUNCS hash.

=cut
sub funcs {
    my $self=shift;
    return $self->{funcs};
}

=item $info->globals()

Returns a reference to the %GLOBALS hash.

=cut
sub globals {
    my $self=shift;
    return $self->{globals};
}

=item $info->mibs()

Returns a reference to the %MIBS hash.

=cut
sub mibs {
    my $self=shift;
    return $self->{mibs};
}

=item $info->munge()

Returns a reference ot the %MUNGE hash.

=cut
sub munge {
    my $self=shift;
    return $self->{munge};
}

=item $info->nosuch()

Returns NoSuch value set or not in new()

=cut
sub nosuch {
    my $self = shift;
    return $self->{nosuch};
}

=item $info->session()

Gets or Sets the SNMP::Session object.

=cut
sub session {
    my $self = shift;
    $self->{sess} = $_[0] if @_;
    return $self->{sess};
}

=item $info->store()

Returns hash store for Table functions.

$info->store = { attribute => { iid => value , iid2 => value2, ... } };

=cut
sub store {
    my $self = shift;
    return $self->{store};
}


=item $info->_global()

Used internally by AUTOLOAD to load dynmaic methods from %GLOBALS. 

Example: $info->name() calls autoload which calls $info->_global('name').

=cut
sub _global{
    my $self = shift;
    my $attr = shift;
    my $sess = $self->session();
    return undef unless defined $sess;

    my $globals = $self->globals(); 

    my $oid = $globals->{$attr};

    # Tag on .0 unless the leaf ends in .number
    unless ($oid =~ /\.\d+$/) {
        $oid .= ".0";
    }

    print "SNMP::Info::_global $attr : $oid\n" if $self->debug();
    my $val = $sess->get($oid); 

    if ($sess->{ErrorStr} ){
        $self->error_throw("SNMP::Info::_global($attr) $sess->{ErrorStr}");
        return undef;
    }

    if (defined $val and $val eq 'NOSUCHOBJECT'){
        $self->error_throw("SNMP::Info::_global($attr) NOSUCHOBJECT");
        return undef;
    }

    if (defined $val and $val eq 'NOSUCHINSTANCE'){
        $self->error_throw("SNMP::Info::_global($attr) NOSUCHINSTANCE");
        return undef;
    }
    # Get the callback hash for data munging
    my $munge = $self->munge();

    # Data Munging
    if (defined $munge->{$attr}){
        my $subref = $munge->{$attr};
        $val = &$subref($val);
    } 

    # Save Cached Value
    $self->{"_$attr"} = $val;

    return $val;
}

=item $info->_set(attr,val,iid)

Used internally by AUTOLOAD to run an SNMP set command for dynamic methods listed in 
either %GLOBALS or %FUNCS.

Example:  $info->set_name('dog',3) uses autoload to resolve to $info->_set('name','dog',3);

=cut
sub _set {
    my ($self,$attr,$val,$iid) = @_;

    $iid = defined $iid ? $iid : '.0';
    # prepend dot if necessary to $iid
    $iid = ".$iid" unless $iid =~ /^\./;

    my $sess = $self->session();
    return undef unless defined $sess;

    my $funcs = $self->funcs();
    my $globals = $self->globals(); 

    my $oid = undef;
    # Lookup oid
    $oid = $globals->{$attr} if defined $globals->{$attr};
    $oid = $funcs->{$attr} if defined $funcs->{$attr};

    unless (defined $oid) { 
        $self->error_throw("SNMP::Info::_set($attr,$val) - Failed to find $attr in \%GLOBALS or \%FUNCS");
        return undef;
    }

    $oid .= $iid;
    
    $self->debug() and print "SNMP::Info::_set $attr$iid ($oid) = $val\n";

    my $rv = $sess->set($oid,$val);

    if ($sess->{ErrorStr}){
        $self->error_throw("SNMP::Info::_set $attr$iid $sess->{ErrorStr}");
        return undef;
    }

    return $rv;
}

=item $info->load_all()

Debugging routine.  This does not include any overriden method or method implemented 
by subroutine.

Runs $info->load_METHOD() for each entry in $info->funcs();

Returns $info->store() -- See store() entry.

Note return value has changed since version 0.3

=cut
sub load_all {
    my $self = shift;
    my $sess = $self->session();
    return undef unless defined $sess;

    my $funcs = $self->funcs();
    
    foreach my $attrib (keys %$funcs) {
      $attrib = "load_$attrib";
      $self->$attrib(); 
    }

    $self->{_all}++;

    return $self->store() if defined wantarray;
}

=item $info->all()

Runs $info->load_all() once then returns $info->store();

Use $info->load_all() to reload the data.

Note return value has changed since version 0.3

=cut
sub all {
    my $self = shift;
    my $sess = $self->session();
    return undef unless defined $sess;

    $self->load_all() unless defined $self->{_all};

    return $self->store();    
}


=item $info->_load_attr()

Used internally by AUTOLOAD to fetch data called from methods listed in %FUNCS.

Called from $info->load_METHOD();

=cut
sub _load_attr {
    my $self = shift;
    my ($attr,$leaf) = @_;

    my $ver    = $self->snmp_ver();
    my $nosuch = $self->nosuch();
    my $sess   = $self->session();
    my $store  = $self->store();
    return undef unless defined $sess;

    # Get the callback hash for data munging
    my $munge = $self->munge();

    $self->debug() and print "SNMP::Info::_load_attr $attr : $leaf\n";

    my $var = new SNMP::Varbind([$leaf]);

    # So devices speaking SNMP v.1 are not supposed to give out 
    # data from SNMP2, but most do.  Net-SNMP, being very precise 
    # will tell you that the SNMP OID doesn't exist for the device.
    # They have a flag RetryNoSuch that is used for get() operations,
    # but not for getnext().  We set this flag normally, and if we're
    # using V1, let's try and fetch the data even if we get one of those.
    my $errornum = $sess->{ErrorNum};
    if ($ver == 1 and $nosuch and $errornum and $sess->{ErrorStr} =~ /nosuch/i){
        $errornum = 0; 
    }
    while (! $errornum ){
        $sess->getnext($var);
        $errornum = $sess->{ErrorNum};
        last if $var->[0] ne $leaf;

        my $iid = $var->[1];
        my $val = $var->[2];

        unless (defined $iid){
            $self->error_throw("SNMP::Info::_load_attr: $attr not here");
            next;
        }
        if ($val eq 'NOSUCHOBJECT'){
            $self->error_throw("SNMP::Info::_load_atr: $attr :  NOSUCHOBJECT");
            next;
        }
        if ($val eq 'NOSUCHINSTANCE'){
            $self->error_throw("SNMP::Info::_load_atr: $attr :  NOSUCHINSTANCE");
            next;
        }

        # Data Munging
        #   Checks for an entry in %munge and runs the subroutine
        if (defined $munge->{$attr}){
            my $subref = $munge->{$attr};
            $val = &$subref($val);
        } 

        $store->{$attr}->{$iid}=$val;
    } 

    # mark data as loaded
    $self->{"_${attr}"}++;

    return $store->{$attr};
}

=item $info->_show_attr()

Used internaly by AUTOLOAD to return data called by methods listed in %FUNCS.

Called like $info->METHOD().

The first time ran, it will call $info->load_METHOD().  
Every time after it will return cached data.

=cut
sub _show_attr {
    my $self = shift;
    my $attr = shift;

    my $store = $self->store();
    
    return $store->{$attr};
}

=back

=head2 AUTOLOAD

Each entry in either %FUNCS or %GLOBALS is used by AUTOLOAD() to create dynamic methods.

Note that this AUTOLOAD is going to be run for all the classes listed in the @ISA array 
in a subclass, so will be called with a variety of package names.  We check the %FUNCS and
%GLOBALS of the package that is doing the calling at this given instant.

=over 

=item 1. Returns unless method is listed in %FUNCS or %GLOBALS for given class

=item 2. If the method exists in %GLOBALS it runs $info->_global(method) unless already cached.

=item 3. Method is in %FUNCS

=item 4. Run $info->_load_attr(method) if not cached

=item 5. Return $info->_show_attr(method).

=back

Override any dynamic method listed in one of these hashes by creating a subroutine with 
the same name.

For example to override $info->name() create `` sub name {...}'' in your subclass.

=cut
sub AUTOLOAD {
    my $self = shift;
    my $sub_name = $AUTOLOAD;

    return if $sub_name =~ /DESTROY$/;

    # package is the first part
    (my $package = $sub_name) =~ s/[^:]*$//;
    # Sub name is the last part
    $sub_name =~ s/.*://;   

    my $attr = $sub_name;
    $attr =~ s/^(load|set)_//;
    
    # Let's use the %GLOBALS and %FUNCS from the class that 
    #   inherited us.
    my (%funcs,%globals);
    {
        no strict 'refs';
        %funcs = %{$package.'FUNCS'};
        %globals = %{$package.'GLOBALS'};
    }

    unless( defined $funcs{$attr} or
            defined $globals{$attr} ) {
        $self->error_throw("SNMP::Info::AUTOLOAD($attr) Attribute not found in this device class.");
        return;
    }
    
    # Check for load_ ing.
    if ($sub_name =~ /^load_/){
        return $self->_load_attr( $attr,$funcs{$attr} );
    } 

    # Check for set_ ing.
    if ($sub_name =~ /^set_/){
        return $self->_set( $attr, @_);
    }

    # Next check for entry in %GLOBALS
    if (defined $globals{$attr} ){
        # Return Cached Value if exists
        return $self->{"_${attr}"} if defined $self->{"_${attr}"};
        # Fetch New Value
        return $self->_global( $attr );
    }

    # Otherwise we must be listed in %FUNCS 

    # Load data if not already cached
    $self->_load_attr( $attr, $funcs{$attr} )
        unless defined $self->{"_${attr}"};

    return $self->_show_attr($attr);
}
1;

=head1 COPYRIGHT AND LICENCE

Copyright (c) 2002-3, Regents of the University of California
All rights reserved.

Redistribution and use in source and binary forms, with or without 
modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright notice,
      this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright notice,
      this list of conditions and the following disclaimer in the documentation
      and/or other materials provided with the distribution.
    * Neither the name of the University of California, Santa Cruz nor the 
      names of its contributors may be used to endorse or promote products 
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE 
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; 
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT 
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS 
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=cut