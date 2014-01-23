#!/usr/bin/perl
use AnyEvent::Socket;
use AnyEvent::Handle;
use Data::Dumper;
my $cv = AnyEvent->condvar;
#tcp block is like following
#|--------------------------
#|size(2 bytes)|data  |
#|--------------------------
#for req
#   size>0,put msg
#   size=0,get msg
#for rsp
#   size>0,
my $jobs = [];
my $reqs = {};
my $wq = [];

sub get_msg
{
    my ($hdl,$msg) = @_;
#    print STDERR "msg = $msg \n";
    if ( scalar(@{$wq}) == 0 ) {
        push(@{$jobs},$msg);
        #       printf STDERR "%d\r",scalar(@{$jobs});
    } else {
        my $client = shift @{$wq};
        $client->push_write($msg);
    }
    $hdl->push_read(chunk => 2,\& get_size);
}

sub get_size
{
    my ($hdl,$size) = @_;
    $size = unpack("v",$size);
    #   print STDERR "size = $size\n";
    if ( $size>0) { $hdl->push_read(chunk => $size,\& get_msg) }
    else {
        if ( scalar(@{$jobs}) == 0 ) {
            push(@{$wq},$hdl);
        } else {
            my $msg = shift @{$jobs};
            my $rsp=sprintf("%s%s",pack('v',length($msg)),$msg);
            $hdl->push_write($rsp);
            $hdl->push_read(chunk =>2,\& get_size);
        }
    }
}

sub destroy_hdl
{
    my $hdl = shift;
    delete $reqs->{$fh->fileno};
    $hdl->destroy;
}

tcp_server undef, 7070, sub {
    my ($fh, $host, $port) = @_;
    print "client is from:$host:$port,handle is:",$fh->fileno,"\n";
    my $hdl =  new AnyEvent::Handle
        fh => $fh,
        no_delay => 1,
        on_error => \& destroy_hdl,
        timeout => 5,
        on_eof => \& destroy_hdl;
    $hdl->push_read(chunk => 2,\& get_size);
    $reqs->{$fh->fileno} = $hdl;
};
$cv->recv;

