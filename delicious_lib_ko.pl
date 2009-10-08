#!/usr/bin/env perl
use strict;
use warnings;
use AnyEvent;
use AnyEvent::Handle;
use WebService::Aladdin;
use Mac::AppleScript qw(RunAppleScript);
use Encode qw/encode/;

$| = 1;

my $file = $ENV{HOME} . "/Library/Application Support/Delicious Library 2/Scanned UPCs Log.txt";

open my $fh, '<', $file or die "Do you rellay have Delicious Library 2?";
my $cv = AE::cv;

my $handle = create_handle();
my $flag = 0;
my $cache = {};

sub create_handle {
    new AnyEvent::Handle
        fh => $fh,
        on_error => sub {
            my ($handle, $fatal, $message) = @_;
            $handle->destroy;
            undef $handle;
            $cv->send("$fatal: $message");
    	},
    	on_eof => sub {
			$handle->destroy;
			undef $handle;
        	$flag = 1;
			$handle = create_handle();
    	},
    	on_read => sub {
			my $handle = shift;
			$handle->push_read(line => sub {
	    		my ($handle, $code) = @_;
  	    		if ($flag && !$cache->{$code}) {
					my $aladdin = WebService::Aladdin->new;
					my $res = $aladdin->search($code);
					my $result = $res->{items}->[0];
					warn $code;
					return undef unless $result;
					my $param = {
						book_name => $result->{title},
						authors   => $result->{author},
						genres    => $result->{categoryName},
						image     => $result->{cover},
						publisher => $result->{publisher},
						isbn      => $result->{isbn},
						features  => $result->{description},
						notes     => $result->{content},
					};
					__run_apple_script($param);
					$cache->{$code} = 1;
            	}
       		})
    	};
}

$cv->recv;

sub __run_apple_script {
	my ($param) = @_;

	my $script = <<SCRIPT;
tell first document of application "Delicious Library 2"
set selected media to make new book with properties {name:"$param->{book_name}", creators:"$param->{authors}", genres:{"$param->{genres}"}, cover URL:"$param->{image}", isbn:"$param->{isbn}"}
end tell
SCRIPT

	return RunAppleScript($script);
}
