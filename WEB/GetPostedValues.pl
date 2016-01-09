use DBI;
use Data::Dumper;
use JSON;
use HTTP::Request::Common qw(POST);
use LWP::UserAgent;

### Database connection ###
$dbh = DBI->connect('DBI:mysql:LAVIATEMP', 'valvoja', 'valvoja') || die "Could not connect to database: $DBI::errstr";

# Debug prints
my $Debug = 1; # 1 / 0
my $Simulate = 0; # 1 / 0
my %postHash;

print "DATABASE CONNECTED\n";

# EXIT IF TRANSFER IS ONGOING
my $sth = $dbh->prepare("SELECT id from system WHERE id=100");
$sth->execute;
my @retriewRunning = $sth->fetchrow_array;
$sth->finish;
print "WHAT: @retriewRunning\n";
if(!defined @retriewRunning)
{
 $dbh->do("insert into system (id, last_retriew) VALUES(100, NOW())");
 print "Start transfer\n";
}
else
{
 print "Exit, transfer is runing\n";
 exit 0;
}

# Store number of temp rows
my $tempRows = 0;
# Store number of relay rows
my $relayRows = 0;
#Global SUM
my $sum = 0;
# define number after we plit this to multiple post
my $splitValue = 50;
# status of splitted
my $splitted=0;

### LAST retriewed value
# Get all enabled sensor
my $sth = $dbh->prepare("select devid, name from sensor where state = 'ENABLED'");
$sth->execute;
$hash_ref = $sth->fetchall_hashref('devid');
$sth->finish;

# Foreach enabled sensors get last_retriew
foreach my $id (keys %$hash_ref)
{
	# Clear post hash for each sesor
	undef %postHash; 
	print "Handling sensor: ". $$hash_ref{$id}{'name'} ."\n";
	my $sth = $dbh->prepare("SELECT last_retriew,NOW() as timeNow from system WHERE id=".$id);
	$sth->execute;
	my @retriew = $sth->fetchrow_array;
	$sth->finish;
	$$hash_ref{$id}{'last'}=$retriew[0];
	
	print "Last retriewed timestamp: $retriew[0]\n";
	my $timeStampNow = $retriew[1];
	print "My timestamp: $timeStampNow\n";	
	
	# GET temp VALUES after last_retriew
	# TEMMPERATURES
 	$sthTemp = $dbh->prepare("select s.name, SUBSTR(t.date,1,16) AS timestamp,  t.temp_c AS value from temperatures t JOIN sensor s ON (s.address = t.sensor_serial) where t.date > ? AND s.devid=? ORDER by t.date");
 	#$sthTemp->execute( $retriew[0]);
 	$sthTemp->execute( $$hash_ref{$id}{'last'}, $id);
 	$$hash_ref{$id}{'rows'} = $sthTemp->rows;
	print "TempRows: $$hash_ref{$id}{'rows'}\n";
	$tempRows =+ $$hash_ref{$id}{'rows'};
	print "TempRows Total: $tempRows\n";
	$$hash_ref{$id}{'data'} = $sthTemp->fetchall_arrayref;
	if($$hash_ref{$id}{'rows'} > 0)
	{
		print "Call Create post Array\n";
		CreateArray($id);
		# define last_retrieve value timestamp
		$$hash_ref{$id}{'newlast'} = $$hash_ref{$id}{'data'}->[$$hash_ref{$id}{'rows'}-1][1];
		print "This sensor new last newlast: ". $$hash_ref{$id}{'newlast'} . "\n";
		## PostValues
		#Call PostValues
		my $status = PostHashValues();
		# Check if transfer is ok
		if ($status == 1)
		{
			# update new last value for sensor
			UpdateLastRetrieve($id, $hash_ref);	
		}
		else
		{
			print "Transfer error, we got status: $status\n";
		}

	}
}

print "Temp Sensor hash: \n" if ($Debug==1);
print Dumper $hash_ref if ($Debug==1);

# Get all enabled relays
my $sth = $dbh->prepare("select devid, name from relays where state = 'ENABLED'");
$sth->execute;
$relay_ref = $sth->fetchall_hashref('devid');
$sth->finish;

# Foreach enabled sensors get last_retriew
foreach my $id (keys %$relay_ref)
{
	# Clear post hash for each sesor
	undef %postHash; 
	# RELAYS
	# Relays IDs in system table is
	my $system_tableid=$id+3000;
	print "Handling Relay: ". $$relay_ref{$id}{'name'} ."\n";
	print "\nSensor SQL: SELECT last_retriew,NOW() as timeNow from system WHERE id=".$system_tableid. "\n";
	my $sth = $dbh->prepare("SELECT last_retriew,NOW() as timeNow from system WHERE id=".$system_tableid);
	$sth->execute;
	my @retriew = $sth->fetchrow_array;
	$sth->finish;
	$$relay_ref{$id}{'last'}=$retriew[0];
	
	$sthRelay = $dbh->prepare("select r.name, SUBSTR(s.timestamp,1,16) AS timestamp,  s.state AS value from status s JOIN relays r ON (r.devid = s.devid) where s.timestamp > ? ORDER by s.timestamp");
	$sthRelay->execute( $retriew[0]);
	my $relayRows = $sthRelay->rows;
	$$relay_ref{$id}{'rows'} = $sthRelay->rows;
	print "RelayRows: $$relay_ref{$id}{'rows'}\n";
	$relayRows =+ $$relay_ref{$id}{'rows'};
	print "RelayRows Total: $relayRows\n";
	$$relay_ref{$id}{'data'} = $sthRelay->fetchall_arrayref;
	print Dumper $$hash_ref{$id}{'data'} if ($Debug==1);
	if($$relay_ref{$id}{'rows'} > 0)
	{
		print "Call Create post Array\n";
		CreateArrayRelays($id);
		# define last_retrieve value
		$$relay_ref{$id}{'newlast'} = $$relay_ref{$id}{'data'}->[$$relay_ref{$id}{'rows'}-1][1];
		print "This relay newlast: ". $$relay_ref{$id}{'newlast'} . "\n"; 
		## PostValues
		#Call PostValues
		my $status = PostHashValues();
		# Check if transfer is ok
		if ($status == 1)
		{
			# update new last value for sensor
			UpdateLastRetrieve($system_tableid, $relay_ref);	
		}
		else
		{
			print "Transfer error, we got status: $status\n";
		}
	}
	
}

print "Relay Sensor hash: \n" if ($Debug==1);
print Dumper $relay_ref if ($Debug==1);

my $test = 0;
my $corrupted = 0;
my $transferOK;

# greate array that will full will this:
# (php)  array('temperature' => array('alusta' => array('123' => '20', '456' => '21'), 'pakari' => array('123' => '17', '456' => '18'))

sub CreateArray()
{
	my $id = shift;
	$sum = 0;
	print "IN CreateArrya() tempRows: ". $tempRows."\n";
	if($tempRows < $splitValue)
	{
 		print "Get all values\n";
 		foreach my $row (@{$$hash_ref{$id}{'data'}})
 		{
 			#print "Add postHash value from: \n";
 			#print Dumper $row;
   			$postHash{'temperature'}{$$row[0]}{$$row[1]} =  $$row[2];
   			$sum += $$row[2];
 		}
 		
	}
	else
	{
 		$splitted=1;
 		# TEMMPERATURES
 		my $i=0;
 		my $split=0;
 		print "Get values to split hash\n";
 		foreach my $row (@{$$hash_ref{$id}{'data'}})
 		{
  			$i++;
  			if($i == $splitValue)
  			{
   				$split++;
   				$i=1;
  			}
  			#$postHash{$split}{$$row[0]}{'temperature'}{$$row[1]} =  $$row[2];
  			$postHash{$split}{'temperature'}{$$row[0]}{$$row[1]} =  $$row[2];
  			#$postHash{$split}{$$row[0]}{'temperature'}{countter} += $$row[2];
  			$postHash{$split}{'temperature'}{countter} += $$row[2];
 		}
	}	
} # sub CreateArray END

sub CreateArrayRelays()
{
	my $id = shift;
	$sum = 0;
	if ($relayRows < $splitValue)
	{
		foreach my $row (@{$$relay_ref{$id}{'data'}})
	 	{
	  		$postHash{'state'}{$$row[0]}{$$row[1]} =  $$row[2];
	  		$sum += $$row[2];
	 	}
	}
	else
	{
		# RELAYS
 		my $i=0;
 		my $split=0;
 		foreach my $row (@{$$relay_ref{$id}{'data'}})
 		{
  			$i++;
 			if($i == $splitValue)
  			{
   				$split++;
   				$i=1;
  			}
  			#$postHash{$split}{$$row[0]}{'state'}{$$row[1]} =  $$row[2];
  			$postHash{$split}{'state'}{$$row[0]}{$$row[1]} =  $$row[2];
  			#$postHash{$split}{$$row[0]}{'state'}{countter} += $$row[2];
  			$postHash{$split}{'state'}{countter} += $$row[2];
 		}
	}
}



sub PostHashValues()
{	
	my $transfer = 0;
	my $checkStatus;
	print "Are we splitting: $splitted\n";
	print Dumper \%postHash if ($Debug==1);
	
	if ($splitted == 0)
	{
		print "Send all as one post\n";
		# encode to json
		my $data_json = encode_json \%postHash;
		#post values
		my $ua = LWP::UserAgent->new;
		print "Start request\n"; 
		print "Data to send: $data_json\n"; 
		## IN Simulatedon't post anything;
		if($Simulate == 1)
		{
			print "IN SIMULATION MODE. NO real post done\n";
			$checkStatus = 0;
		}
		else
		{
			my $req = POST 'http://rajamaki.fi/LaviaLampo/import.php',
		    	             [ import => $data_json];
			print "POST done\n";
			print "TOTAL SUM $sum\n";
			$reply = $ua->request($req)->as_string;
			print "VASTAUS: $reply\n";
			$checkStatus = CheckPost($reply, $sum);
		}
		
		if($checkStatus == 0)
 		{
  			$transferOK =1; 
 		}
	}
	else
	{
		print "In encode splitted\n";
		# Set transferOK for first
		$transferOK=1;
 		#print "KEYS: ", keys %postHash ,"\n";
 		foreach my $split (sort {$a<=>$b} keys %postHash) 
 		{
  			print "Send in peases:  $split\n";
  			my $totalCount =0;
  			foreach my $unit (keys %{$postHash{$split}})
  			{
			   print "UNIT to encode: $unit\n";
			   print "Count : $postHash{$split}{$unit}{countter}\n";
			   $totalCount += $postHash{$split}{$unit}{countter};
			   delete $postHash{$split}{$unit}{countter};
  			}
			print "Encode\n";
			#print Dumper $postHash{$split};
			my $data_json = encode_json \%{$postHash{$split}};
			#print "Data to send: $data_json\n";
			#post values
			my $ua = LWP::UserAgent->new;
			print "Start request\n"; 
			my $req = POST 'http://rajamaki.fi/LaviaLampo/import.php',
			                  [ import => $data_json];
			print "POST done\n";
			print "TOTAL SUM: $totalCount\n";
			#print $ua->request($req)->as_string;
			$reply = $ua->request($req)->as_string;
			my $checkStatus = CheckPost($reply, $totalCount);
			print "Send splits, checkStatus: $checkStatus\n";
			if($checkStatus == 0 && $transferOK != 0)
			{
				print "Transfer OK\n";
				$transferOK =1; 
			}
			else
			{
				print "Transfer NOT OK\n";
			  	$transferOK=0;
			}
			sleep 5;
 		}
 		return $transferOK;
	}
} #POSTHASHValues end


print "STATUS VALUES, CORRUPTED: $corrupted, TRANSFER: $transferOK\n";

sub UpdateLastRetrieve()
{
	my $id = shift;
	my $ref = shift;
	my $timestamp;
 	# update lastretriew time
 	print "IN updating lastretriew values\n";
	if ($id > 3000)
	{
		# We have relay IDs (+3000)
 		$timeStamp = $$ref{$id-3000}{'newlast'}; 
	}
	else
	{
 		$timeStamp = $$ref{$id}{'newlast'}; 
	}
	print "Update SQL: UPDATE system SET last_retriew=\'$timeStamp\' WHERE id=$id\n";
 	$dbh->do("UPDATE system SET last_retriew='$timeStamp' WHERE id=$id");	
}
 
 #DISABLE TRANSFER STATUS
 $dbh->do("delete from system WHERE id=100");


sub CheckPost()
{
  my $reply = shift;
  my $totalCount = shift;
  print "Reply content: $reply" if ($Debug==1);

  my ($sum) = $reply =~ /.*SUM:\s(\d+(:?\.\d+)?)/g;
  print "TOTAL SUM in reply: $sum\n";
  print "TOTAL SUM count: $totalCount\n";
 
  if($sum ne $totalCount)
  {
   $corrupted = 1;
   return 1;
  }
 return 0;
}

END {
 #DISABLE TRANSFER STATUS
 $dbh->do("delete from system WHERE id=100");
 ### DISCONNECT DATBASE ###
 $dbh->disconnect();
}
