#!/usr/bin/perl

use strict;
use CGI;
use Template;
use Filesys::Df qw/df/;

use Encode;
use DBI;
use utf8;

BEGIN {
    require "lib/site_config.pl";
}
my $q = CGI->new;
my $page = decode('utf8', $q->param("p"));
my $query = decode('utf8', $q->param("q"));

binmode(STDOUT, ":utf8");

# redirects should have a full URL: http://ernstchan.com/b/
# but this can be tricky if running behind some proxy
if ($page eq "") {
#        exit print $q->redirect("https://02ch.in/".DEFAULT_BOARD."/");
        exit print $q->redirect("/main");
}

# print $q->header(-charset => 'utf-8');

my $tt = Template->new({
        INCLUDE_PATH => 'tpl/',
        ERROR => 'error.tt2',
        PRE_PROCESS  => 'header.tt2',
        POST_PROCESS => 'footer.tt2',
        ENCODING => 'utf8'
});

my $ttfile = "content/" . $page . ".tt2";

if ($page eq 'err403') {
    tpl_make_error({
        'http' => '403 Forbidden',
        'type' => "HTTP-Error 403: Access Denied",
        'info' => "Access to this resource is not allowed.",
        'image' => "/img/403.png"
    });
}
elsif ($page eq 'err404') {
    tpl_make_error({
        'http' => '404 Not found',
        'type' => "HTTP-Error 404: Not Found",
        'info' => "The requested file doesn't exist or has been deleted.",
        'image' => "/img/404.png"
    });
}
elsif (-e 'tpl/' . $ttfile) {
    my $output;
    $tt->process($ttfile, {
        'tracking_code' => TRACKING_CODE,
        'uptime' => uptime(),
        'ismain' => ($page eq "main"),
        'diskinfo' => disk_info()
        }, \$output)
      or tpl_make_error({
        'http' => '500 Boom',
        'type' => "Fehler bei Scriptausf&uuml;hrung",
        'info' => $tt->error
      });
    print $q->header(-charset => 'utf-8');
    print $output;

}
else {
    tpl_make_error({
        'http' => '404 Not found',
        'type' => "HTTP-Error 404: Not Found",
        'info' => "The requested file doesn't exist or has been deleted.",
        'image' => "/img/404.png"
    });
}

#
# Subroutines
#

sub disk_info {
    my $disk_info = df("/home/");
    my @dicks = ($$disk_info{blocks}, $$disk_info{used}, $$disk_info{bfree});
    $_ = nya1k_to_gb($_) for (@dicks);
    return \@dicks;
}

sub nya1k_to_gb {
    my $blocks = shift;
    int ( ($blocks * 1024)/2 ** 30 );
}

sub sec2human {
    my $secs = shift;
    if    ($secs >= 365*24*60*60) { return sprintf '%.1fy', $secs/(365 *24*60*60) }
    elsif ($secs >=     24*60*60) { return sprintf '%.1fd', $secs/(24*60*60) }
    elsif ($secs >=        60*60) { return sprintf '%.1fh', $secs/(60*60) }
    elsif ($secs >=           60) { return sprintf '%.1fm', $secs/(60) }
    else                          { return sprintf '%.1fs', $secs }
}

sub tpl_make_error($) {
    my ($error) = @_;
    print $q->header(-status=>$$error{http}, -charset => 'utf-8');
    $tt->process("error.tt2", {
        'tracking_code' => TRACKING_CODE,
        'error' => $error
    });
}

sub uptime {
    open(FILE, '/proc/uptime') || return 0;
    my $line = <FILE>;
    my($uptime, $idle) = split /\s+/, $line;
    close FILE;
    return [ sec2human($uptime), sec2human($idle) ];
}

1;
