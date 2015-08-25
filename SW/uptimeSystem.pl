#!/usr/bin/perl
use English;
use DBI;
use Data::Dumper;

# This script will update server ip address adn other info to system table


my $debug = 0;
$debug = 1 if $ARGV[0] eq "--debug";
my $dbh = DBI->connect('DBI:mysql:LAVIATEMP:localhost', 'valvoja', 'valvoja') or die "Cant connect to database: $!";
print "Database connected\n" if $debug == 1;
my $HOME = $ENV{HOME};
print "HOME $HOME\n";

print "Read whatismyip output\n";
my $statusStr = `$HOME/workspace/LaviaLampo/SW/whatismyip.sh`;
chomp $statusStr;

print "Whe have string to parse: $statusStr\n";
my ($ipstr) = $statusStr =~ /.*?(?:((?:\d+\.){3}\d+))/;
print "IP-address: $ipstr\n";

# here the uptime
print "Read uptime output\n";
my $statusStrUptime = `uptime`;
chomp $statusStrUptime;
print "We have string to parse: $statusStrUptime\n";
# 11:26:44 up  1:12,  2 users,  load average: 0.30, 0.25, 0.19
# 12:49:25 up 9 days, 33 min,  3 users,  load average: 0.51, 0.33, 0.22
#raspberry
#  19:55:32 up 3 days, 12:28,  1 user,  load average: 0,14, 0,10, 0,13
# 18:43:09 up 10 min,  2 users,  load average: 0,05, 0,12, 0,12
my $upstr;
if ($statusStrUptime =~ m/days/)
{
	print "Its been days\n" if ($debug ==1);
	($upstr) = $statusStrUptime =~ /.*?(up\s+\d+\sdays,.*?),/;
}
else
{
	($upstr) = $statusStrUptime =~ /.*?(up\s+\d+(?::\d+)?(?:\smin)?),/;
}
print "uptime: $upstr\n";

### DB ###

$dbh->do("update system set ip='$ipstr', uptime = '$upstr', health = 'N/A' WHERE id=1");

