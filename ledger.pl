use strict;
use warnings;

my $file = shift @ARGV;
my $type = shift @ARGV;
$type = defined($type) ? $type : "";

if(not defined($file))
{
	print "usage: \n";
	print "\tperl ledger.pl [ledger file] balance  [max depth]\n";
	print "\tperl ledger.pl [ledger file] register [account name]\n\n";
	exit;
}

print "\n\n";

if( lc(substr($type, 0, 1)) =~ /r/)
{
	$type = "register";
}
else
{
	$type = "balance";
}

my $param = shift @ARGV;

if((not defined($param)) && $type eq "balance")
{
	$param =1 ;
}

my $readEntries = [];

my $floatComp = 10000;

open IN, "<$file";
while(my $line = <IN>)
{
	chomp $line;
	if ($line =~/^[0-9]{4}\// )
	{
		my @splitLine = split(/[\t ]+/, $line);
		my $date = shift @splitLine;
		my $desc = join(" ", @splitLine);
	
		my $line1 = <IN>;
		my $line2 = <IN>;

		my $accLines = [ $line1, $line2];
		my $applyName = "";
		my $otherName = "";
		my $amount = 0;
		for $a (@$accLines)
		{
			chomp $a;
			$a =~ s/^[\t ]//g;
			my @splitAcc = split(/[\t ]+/, $a);
			my $found = 0;
			if(defined($splitAcc[1]))
			{
				if($splitAcc[1] =~ /[0-9]/)
				{
					$found = 1;
					$applyName = $splitAcc[0];
					$amount = $splitAcc[1];
					$amount =~ s/\$//g;
					$amount =~ s/,//g;
					$amount = int($amount*$floatComp);
				}
			}
			if($found == 0)
			{
				$otherName = $splitAcc[0];
			}
		}
		push(@$readEntries, [$date, $desc, $applyName, $otherName, $amount]);
	}
}
close IN;


my $accounts = {};
my @sortedEntries = sort { $a->[0] cmp $b->[0] } @$readEntries;
foreach my $entry (@sortedEntries)
{
	my $date = $entry->[0];
	my $desc = $entry->[1];
	my $acc1 = $entry->[2];
	my $acc2 = $entry->[3];
	my  $amt = $entry->[4];

	my @acc1Parts = split(/:/, $acc1);
	my @acc2Parts = split(/:/, $acc2);


	foreach my $up ([ \@acc1Parts, $amt], [ \@acc2Parts, -1*$amt])
	{
		my $accParts = $up->[0];
		my $adjAmt = $up->[1];
		my $accHash = $accounts;

		while(scalar(@$accParts) > 0)
		{
			my $nextPart = shift @$accParts;
			if(not defined($accHash->{$nextPart}))
			{
				$accHash->{$nextPart} = {};
			}
			$accHash = $accHash->{$nextPart};
			
			my $leafEntries = defined($accHash->{"LEAF_NODE_ENTRIES"}) ? $accHash->{"LEAF_NODE_ENTRIES"} : [];
			my $prevTotal = defined($leafEntries->[0]) ? $leafEntries->[ scalar(@$leafEntries)-1 ]->[4] : 0;
			my $nextEntry = [$date, $desc, $acc1, $adjAmt, $adjAmt+$prevTotal];
			push(@$leafEntries, $nextEntry); 
			$accHash->{"LEAF_NODE_ENTRIES"} = $leafEntries;
		}
	}
}

if($type eq "balance")
{
	printBalances($accounts, $param);
}
else
{
	printRegister($accounts, $param);
}

exit;


sub printRegister
{
	my $accounts = shift @_;
	my $name = shift @_;

	my @splitName = split(/:/, $name);
	while(scalar(@splitName) > 0 && defined($accounts))
	{
		$accounts = $accounts->{ shift @splitName };
	}
	if(defined($accounts))
	{
		if(defined($accounts->{"LEAF_NODE_ENTRIES"}))
		{
			my $allEntries = $accounts->{"LEAF_NODE_ENTRIES"};
			foreach my $ent (@$allEntries)
			{
				printf("%10s %30s    %-25s %20.2f %20.2f\n", $ent->[0], substr($ent->[1],0,30), $ent->[2], $ent->[3]/$floatComp, $ent->[4]/$floatComp)
			}
		}
	}
}


sub printBalances
{
	my $accounts = shift @_;
	my $maxLevel = shift @_;
	my $name = shift @_;
	my $level = shift @_;

	if(not defined($maxLevel))
	{
		$maxLevel = -1;
	}	
	if(not defined($level))
	{
		$name = "";
		$level = 0;
	}
	if($maxLevel > 0 && $level > $maxLevel)
	{
		return;
	}

	if(defined($accounts->{"LEAF_NODE_ENTRIES"}))
	{
		my $allEntries = $accounts->{"LEAF_NODE_ENTRIES"};
		my $total = ($allEntries->[ scalar(@$allEntries)-1 ])->[4];
		
		$total = int($total)/$floatComp;
		
		my $levSpacer = "";
		foreach my $lev (1..$level)
		{
			$levSpacer = $levSpacer . "  ";
		}
		printf("%20.2lf%s%-20s\n", "$total", $levSpacer, $name);
	}
	foreach my $acc (keys %$accounts)
	{
		if( $acc ne "LEAF_NODE_ENTRIES" )
		{
			my $nextName = $name eq "" ? $acc : "$name:$acc";
			printBalances($accounts->{$acc}, $maxLevel, $nextName, $level+1);
		}
	}
}
