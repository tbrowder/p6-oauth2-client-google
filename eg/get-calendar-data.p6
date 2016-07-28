#!/usr/bin/env perl6

use lib 'lib';

use OAuth2::Client::Google;
use JSON::Fast;
use HTTP::UserAgent;

my $browser = %*ENV<BROWSER> || qx{which xdg-open} || qx{which x-www-browser} || qx{which open};
$browser .= chomp;

'client_id.json'.IO.e or die "No client_id.json";
my $config = from-json('client_id.json'.IO.slurp);

my $uri = $config<web><redirect_uris>.first({ /localhost/ }) or
  die "no localhost in redirect_uris: add one and updated client_id.json";
$uri ~~ / 'http://localhost:' $<port>=(<[0..9]>+)? $<path>=('/' \N+)? $ / or die "couldn't parse $uri";
my $port = $<port> // 80;
my $path = $<path> // '/';
say "using $uri from config file";

my $oauth = OAuth2::Client::Google.new(
    config => $config,
    redirect-uri => $uri,
    scope => "https://www.googleapis.com/auth/calendar.readonly",
);

my $auth-uri = $oauth.auth-uri;

say "starting web server at localhost:$port";
say "opening browser to $auth-uri";

my $proc = run($browser,$auth-uri);

my $response = q:to/HERE/.encode("UTF-8");
HTTP/1.1 200 OK
Content-Length: 7
Connection: close
Content-Type:text/plain

all set!
HERE
my $in;
my $done;
my $sock = IO::Socket::Async.listen('localhost', $port);
$sock.tap( -> $connection {
    $connection.Supply.tap( -> $str {
        $in ~= $str;
        if $str ~~ /\r\n\r\n/ {
            $connection.write($response);
            $connection.close;
            $done = True;
        }
      });
});
loop { last if $done; };
$in ~~ / 'GET' .* 'code=' $<code>=(<-[&]>+) /;
my $code = $<code> or die "did not get code in query params";
say "Got code $code";

my $access = $oauth.code-to-token(:$code);
my $token = $access<access_token> or die "could not get access token";
say "Got access token $token";

my $base = "https://www.googleapis.com/calendar/v3";
my $ua = HTTP::UserAgent.new;
my $got = $ua.get(
    "$base/users/me/calendarList?maxResults=20",
    Authorization => "Bearer $token" );
say $got.decoded-content;

